# CloudNativePG (CNPG) Operator

**Version**: 1.0  
**Date**: 2025-07-17  
**Author**: Community Contributors  
**Status**: Active

## Overview

CloudNativePG (CNPG) provides PostgreSQL management for Kubernetes clusters. This deployment serves as the PostgreSQL foundation for homelab-foundations, enabling easy deployment of PostgreSQL instances for applications like Temporal.

## Architecture

### Components
- **CNPG Operator**: Latest stable version (v1.24.x)
- **Management**: GitOps via Flux CD
- **Namespace**: cnpg-system
- **Monitoring**: Prometheus integration enabled
- **Storage**: Longhorn persistent volumes for PostgreSQL instances
- **Backup**: MinIO S3-compatible storage integration

### Resource Allocation
- **CNPG Operator**: 1 replica, 256Mi memory, 100m CPU
- **Webhook**: 1 replica, 128Mi memory, 50m CPU
- **Total Memory**: ~384Mi for operator infrastructure

## PostgreSQL Instance Management

### Co-located Architecture
PostgreSQL instances are deployed co-located with their applications following the homelab-foundations pattern:

```
clusters/um890/cnpg/              # CNPG operator (infrastructure)
├── kustomization.yaml
├── helmrelease.yaml
├── monitoring.yaml
└── backup-config.yaml

clusters/um890/temporal/          # Application with PostgreSQL
├── postgres-cluster.yaml         # Temporal's PostgreSQL instance
└── ...

clusters/um890/future-app/        # Another application
├── postgres-cluster.yaml         # Another PostgreSQL instance
└── ...
```

### Benefits
- **Single Source of Truth**: All application-related configs in one place
- **Atomic Deployments**: Database and application deploy together
- **Easier Troubleshooting**: All related resources in one location
- **Clear Ownership**: Each application owns their database configuration

## Backup Configuration

### MinIO Integration
CNPG uses MinIO for PostgreSQL backups:
- **Bucket**: postgres-backups
- **Path Structure**: /application-name/
- **Retention**: 30 days default
- **Credentials**: Shared MinIO credentials

### Setup Required
Before deploying PostgreSQL clusters, create the backup credentials secret:

```bash
# Create MinIO backup credentials secret
kubectl create secret generic minio-backup-credentials \
  --from-literal=ACCESS_KEY_ID="YOUR_MINIO_ACCESS_KEY" \
  --from-literal=SECRET_ACCESS_KEY="YOUR_MINIO_SECRET_KEY" \
  --namespace=cnpg-system

# Create postgres-backups bucket in MinIO
# Access MinIO console at http://minio-console.homelab.local
# Or use MinIO client (mc) to create the bucket
```

## Monitoring

### Prometheus Integration
- **Operator Metrics**: CNPG operator performance and health
- **Cluster Metrics**: PostgreSQL instance metrics (when deployed)
- **Backup Metrics**: Backup success/failure rates
- **Connection Metrics**: Database connection pools

### Grafana Dashboards
- **CNPG Operator**: Operator health and performance
- **PostgreSQL Overview**: Database performance metrics (when clusters exist)
- **Backup Status**: Backup success rates and timing

## Operational Procedures

### Check Operator Status
```bash
# Check CNPG operator pods
kubectl get pods -n cnpg-system

# Check operator logs
kubectl logs -n cnpg-system deployment/cnpg-controller-manager

# Check webhook status
kubectl get validatingwebhookconfiguration
kubectl get mutatingwebhookconfiguration
```

### Monitor PostgreSQL Clusters
```bash
# List all PostgreSQL clusters
kubectl get clusters -A

# Check specific cluster status
kubectl describe cluster <cluster-name> -n <namespace>

# Check backup status
kubectl get backups -A
```

### Troubleshooting
```bash
# Check operator events
kubectl get events -n cnpg-system --sort-by='.lastTimestamp'

# Check cluster events
kubectl get events -n <app-namespace> --sort-by='.lastTimestamp'

# Check operator configuration
kubectl get configmap -n cnpg-system
```

## Next Steps

1. **Verify Deployment**: Ensure CNPG operator is running
2. **Create Backup Credentials**: Setup MinIO backup secret
3. **Deploy PostgreSQL Clusters**: Use templates for applications
4. **Monitor and Maintain**: Use operational procedures for ongoing management

## Templates and Documentation

PostgreSQL cluster templates and comprehensive usage guide:
- **Usage Guide**: `docs/CNPG_USAGE_GUIDE.md` - Complete deployment and operational guide
- **Templates**: `docs/templates/postgres-cluster-template.yaml` - PostgreSQL cluster template
- **Examples**: `examples/applications/database-app/` - Working example application
- **Verification**: `scripts/verify-cnpg.sh` - Deployment verification script

## Integration

CNPG integrates with existing homelab-foundations components:
- **Longhorn**: Persistent storage for PostgreSQL data
- **MinIO**: S3-compatible backup storage
- **Prometheus**: Metrics collection and monitoring
- **Grafana**: Dashboard visualization
- **Flux**: GitOps deployment and management
