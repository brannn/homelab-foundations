# Temporal Workflow System Guide

**Version**: 1.0  
**Date**: 2025-07-17  
**Author**: Community Contributors  
**Status**: Active

## Overview

Temporal is a workflow orchestration platform that provides durable execution for complex business logic. This deployment uses a minimal PostgreSQL backend via CloudNativePG (CNPG) operator, optimized for homelab resource constraints while maintaining production-ready capabilities.

## Architecture

### Components
- **Temporal Server**: v1.28.0 with homelab-optimized resource allocation
- **PostgreSQL**: Single instance via CNPG operator (512Mi memory, 10Gi storage)
- **Web UI**: Temporal Web interface for workflow monitoring and debugging
- **Backup**: Automated PostgreSQL backup to MinIO S3 storage

### Resource Allocation (Homelab-Optimized)
- **Total Memory**: ~2.3Gi when running, 0Gi when scaled to zero
- **Total CPU**: ~900m when running, 0m when scaled to zero
- **Storage**: 10Gi PostgreSQL data
- **Actual Usage**: ~551Mi memory (75% below allocated limits)

## Network Access

### LoadBalancer Services (MetalLB)
- **Temporal Frontend (gRPC)**: `grpc://10.0.0.250:7233`
- **Temporal Web UI (HTTP)**: `http://10.0.0.250:8080`

### Ingress Access (HAProxy)
- **Web UI**: `http://temporal.homelab.local`

## Database Configuration

### PostgreSQL Cluster (CNPG)
- **Cluster Name**: `temporal-postgres`
- **Databases**: `temporal` (main) and `temporal_visibility`
- **User**: `temporal`
- **Memory**: 512Mi (384Mi requests, 512Mi limits)
- **Storage**: 10Gi Longhorn persistent volume
- **Backup**: Automated to MinIO with 14-day retention

### Backup Features
- **Continuous WAL Archiving**: Real-time transaction log backup
- **Point-in-Time Recovery**: Restore to any point within retention period
- **MinIO Integration**: Uses existing homelab MinIO infrastructure
- **Retention**: 14 days (homelab-optimized)

## Operational Procedures

### Scaling to Zero (Resource Conservation)
```bash
# Scale down Temporal services (saves ~1.8Gi memory)
kubectl scale deployment -n temporal-system --replicas=0 \
  temporal-frontend temporal-history temporal-matching temporal-worker temporal-web

# Scale down PostgreSQL (saves ~512Mi memory)
kubectl patch cluster temporal-postgres -n temporal-system \
  --type='merge' -p='{"spec":{"instances":0}}'

# Total memory savings: ~2.3Gi when fully scaled to zero
```

### Scaling Up
```bash
# Scale up PostgreSQL first
kubectl patch cluster temporal-postgres -n temporal-system \
  --type='merge' -p='{"spec":{"instances":1}}'

# Wait for PostgreSQL to be ready, then scale up Temporal
kubectl scale deployment -n temporal-system --replicas=1 \
  temporal-frontend temporal-history temporal-matching temporal-worker temporal-web
```

### Status Monitoring
```bash
# Check Temporal services
kubectl get pods -n temporal-system

# Check PostgreSQL cluster status
kubectl get clusters.postgresql.cnpg.io -n temporal-system

# Check LoadBalancer services
kubectl get svc -n temporal-system

# Check ingress status
kubectl get ingress -n temporal-system
```

### Database Operations
```bash
# Connect to PostgreSQL
kubectl exec -it temporal-postgres-1 -n temporal-system -- psql -U temporal -d temporal

# Create manual backup
kubectl apply -f - <<EOF
apiVersion: postgresql.cnpg.io/v1
kind: Backup
metadata:
  name: manual-backup-$(date +%Y%m%d-%H%M%S)
  namespace: temporal-system
spec:
  cluster:
    name: temporal-postgres
EOF

# Check backup status
kubectl get backups -n temporal-system
```

## Security Configuration

### Credentials Management
- **PostgreSQL**: Managed via Kubernetes secrets (temporal-postgres-credentials)
- **MinIO Backup**: Uses minio-backup-credentials secret
- **Web UI**: No authentication required (homelab configuration)

### Network Security
- **Internal Access**: Services communicate via cluster DNS
- **External Access**: LoadBalancer and ingress only
- **Database**: Not exposed externally, cluster-internal only

## Monitoring Integration

### Prometheus Metrics
- **ServiceMonitor**: Configured for Prometheus scraping
- **Metrics Endpoint**: Available on metrics port
- **Integration**: Works with existing monitoring stack

### Available Metrics
- Temporal server performance
- Database connection pools
- Workflow execution metrics
- System resource utilization

## Development Usage

### Client Connection
```bash
# gRPC endpoint for Temporal clients
TEMPORAL_ADDRESS=10.0.0.250:7233

# Web UI for monitoring
TEMPORAL_WEB_UI=http://10.0.0.250:8080
# or via ingress: http://temporal.homelab.local
```

### SDK Integration
Temporal supports SDKs for multiple languages:
- **Go**: `go.temporal.io/sdk`
- **Java**: `io.temporal:temporal-sdk`
- **Python**: `temporalio`
- **TypeScript**: `@temporalio/client`

### Example Workflow (Go)
```go
package main

import (
    "context"
    "log"
    "time"

    "go.temporal.io/sdk/client"
    "go.temporal.io/sdk/worker"
    "go.temporal.io/sdk/workflow"
)

func SampleWorkflow(ctx workflow.Context, name string) (string, error) {
    ao := workflow.ActivityOptions{
        StartToCloseTimeout: 10 * time.Second,
    }
    ctx = workflow.WithActivityOptions(ctx, ao)

    var result string
    err := workflow.ExecuteActivity(ctx, SampleActivity, name).Get(ctx, &result)
    if err != nil {
        return "", err
    }
    return result, nil
}

func SampleActivity(ctx context.Context, name string) (string, error) {
    return "Hello " + name + "!", nil
}

func main() {
    // Create the client object just once per process
    c, err := client.Dial(client.Options{
        HostPort: "10.0.0.250:7233",
    })
    if err != nil {
        log.Fatalln("unable to create Temporal client", err)
    }
    defer c.Close()

    // This worker hosts both Workflow and Activity functions
    w := worker.New(c, "sample", worker.Options{})
    w.RegisterWorkflow(SampleWorkflow)
    w.RegisterActivity(SampleActivity)

    // Start listening to the Task Queue
    err = w.Run(worker.InterruptCh())
    if err != nil {
        log.Fatalln("unable to start Worker", err)
    }
}
```

## Troubleshooting

### Common Issues

1. **PostgreSQL not ready**:
   ```bash
   kubectl describe cluster temporal-postgres -n temporal-system
   kubectl logs -n temporal-system temporal-postgres-1
   ```

2. **Temporal services failing**:
   ```bash
   kubectl describe pods -n temporal-system
   kubectl logs -n temporal-system -l app.kubernetes.io/name=temporal
   ```

3. **Database connection issues**:
   ```bash
   # Check database connectivity
   kubectl exec -it temporal-postgres-1 -n temporal-system -- pg_isready
   
   # Check credentials secret
   kubectl get secret temporal-postgres-credentials -n temporal-system -o yaml
   ```

4. **LoadBalancer not accessible**:
   ```bash
   # Check MetalLB status
   kubectl get svc -n temporal-system
   kubectl describe svc temporal-web-lb -n temporal-system
   ```

5. **Schema initialization issues**:
   ```bash
   # Manually initialize schema if needed
   kubectl exec -it temporal-admintools-xxx -n temporal-system -- \
     env SQL_PLUGIN=postgres12 \
     SQL_HOST=temporal-postgres-rw.temporal-system.svc.cluster.local \
     SQL_PORT=5432 SQL_USER=temporal SQL_PASSWORD=xxx \
     temporal-sql-tool --database temporal setup-schema -v 0.0
   ```

### Performance Tuning

For production workloads, consider adjusting:
- **Connection Pool Sizes**: Increase maxConns in Helm values
- **Resource Limits**: Scale up memory/CPU based on workflow complexity
- **PostgreSQL Configuration**: Tune shared_buffers and work_mem
- **Replica Counts**: Add replicas for high availability

## Files Structure

```
clusters/um890/temporal/
├── kustomization.yaml           # Main kustomization
├── postgres-cluster.yaml       # CNPG PostgreSQL cluster
├── postgres-secret.yaml        # Database credentials secret (not in Git)
├── minio-backup-secret.yaml    # MinIO backup credentials (not in Git)
├── helmrelease.yaml            # Temporal Helm release
├── services.yaml               # MetalLB LoadBalancer services
├── ingress.yaml                # HAProxy ingress configuration
├── servicemonitor.yaml         # ServiceMonitor for Prometheus
├── generate-credentials.sh     # Helper script for secure credentials
└── README.md                   # Component documentation
```

## Related Documentation

- **[CloudNativePG Guide](CNPG_GUIDE.md)** - PostgreSQL operator usage
- **[MinIO Guide](MINIO_GUIDE.md)** - Object storage and backup configuration
- **[Resource Management Guide](RESOURCE_MANAGEMENT.md)** - Scaling procedures
- **[Monitoring Guide](MONITORING.md)** - Prometheus integration
- **[HAProxy Ingress Guide](HAPROXY_INGRESS.md)** - Ingress configuration
