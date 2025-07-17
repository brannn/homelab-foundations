# CloudNativePG (CNPG) Usage Guide

**Version**: 1.0  
**Date**: 2025-07-17  
**Author**: Community Contributors  
**Status**: Active

## Overview

CloudNativePG (CNPG) provides enterprise-grade PostgreSQL management for Kubernetes clusters. This guide covers how to deploy and manage PostgreSQL databases in the homelab-foundations environment using the co-located architecture pattern.

## Architecture

### Co-located Pattern
PostgreSQL instances are deployed alongside their applications, providing:
- **Single Source of Truth**: All application resources in one location
- **Atomic Deployments**: Database and application deploy together
- **Easier Operations**: Simplified troubleshooting and management
- **Clear Ownership**: Each application team owns their database

### Directory Structure
```
clusters/um890/your-app/
├── kustomization.yaml           # Main kustomization
├── postgres-cluster.yaml       # PostgreSQL cluster definition
├── postgres-secret.yaml        # Database credentials
├── postgres-init-job.yaml      # Optional schema initialization
├── deployment.yaml             # Application deployment
├── service.yaml                # Application service
├── ingress.yaml                # Application ingress
└── servicemonitor.yaml         # Monitoring configuration
```

## Quick Start

### 1. Prepare Application Directory
```bash
# Create application directory
mkdir -p clusters/um890/your-app

# Copy PostgreSQL templates
cp docs/templates/postgres-cluster-template.yaml clusters/um890/your-app/postgres-cluster.yaml
cp docs/templates/postgres-secret-template.yaml clusters/um890/your-app/postgres-secret.yaml
```

### 2. Configure PostgreSQL Cluster
Edit `clusters/um890/your-app/postgres-cluster.yaml`:

```yaml
metadata:
  name: your-app-postgres
  namespace: your-app-namespace

bootstrap:
  initdb:
    database: your_database
    owner: your_user
    secret:
      name: your-app-postgres-credentials

storage:
  size: 20Gi  # Adjust based on needs
  storageClass: longhorn

resources:
  requests:
    memory: 500Mi  # Adjust based on workload
    cpu: 250m
  limits:
    memory: 500Mi
    cpu: 500m

backup:
  barmanObjectStore:
    destinationPath: "s3://postgres-backups/your-app"
```

### 3. Create Database Credentials
```bash
# Generate secure credentials
USERNAME="your_user"
PASSWORD="$(openssl rand -base64 32)"

# Create base64 encoded values
USERNAME_B64=$(echo -n "$USERNAME" | base64)
PASSWORD_B64=$(echo -n "$PASSWORD" | base64)

# Update postgres-secret.yaml with these values
# NEVER commit actual credentials to Git!
```

### 4. Create Backup Credentials
```bash
# Create MinIO backup credentials in your application namespace
kubectl create secret generic minio-backup-credentials \
  --from-literal=ACCESS_KEY_ID="minio" \
  --from-literal=SECRET_ACCESS_KEY="minio123" \
  --namespace=your-app-namespace
```

### 5. Deploy via GitOps
```bash
# Create kustomization.yaml
cat > clusters/um890/your-app/kustomization.yaml <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: your-app-namespace

resources:
  - postgres-cluster.yaml
  - postgres-secret.yaml
  - deployment.yaml
  - service.yaml
EOF

# Add to main cluster kustomization
echo "  - your-app" >> clusters/um890/kustomization.yaml

# Commit and deploy
git add clusters/um890/your-app/
git commit -m "Add PostgreSQL cluster for your-app"
git push
```

## Application Integration

### Database Connection
Configure your application to connect to PostgreSQL:

```yaml
# In your deployment.yaml
env:
- name: DATABASE_URL
  value: "postgresql://$(DB_USER):$(DB_PASSWORD)@your-app-postgres-rw.your-app-namespace.svc.cluster.local:5432/your_database"
- name: DB_USER
  valueFrom:
    secretKeyRef:
      name: your-app-postgres-credentials
      key: username
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: your-app-postgres-credentials
      key: password
```

### Service Discovery
CNPG automatically creates services:
- **Read-Write**: `your-app-postgres-rw` (primary instance)
- **Read-Only**: `your-app-postgres-ro` (read replicas, if configured)
- **Read**: `your-app-postgres-r` (any instance)

### Health Checks
```yaml
# In your deployment.yaml
livenessProbe:
  exec:
    command:
    - /bin/sh
    - -c
    - pg_isready -h your-app-postgres-rw -p 5432 -U your_user
  initialDelaySeconds: 30
  periodSeconds: 10
```

## Operational Procedures

### Monitoring
```bash
# Check PostgreSQL cluster status
kubectl get clusters.postgresql.cnpg.io -n your-app-namespace

# Check cluster details
kubectl describe cluster your-app-postgres -n your-app-namespace

# Check pods
kubectl get pods -n your-app-namespace -l cnpg.io/cluster=your-app-postgres

# Check logs
kubectl logs your-app-postgres-1 -n your-app-namespace -c postgres
```

### Backup Management
```bash
# Create manual backup
kubectl apply -f - <<EOF
apiVersion: postgresql.cnpg.io/v1
kind: Backup
metadata:
  name: manual-backup-$(date +%Y%m%d-%H%M%S)
  namespace: your-app-namespace
spec:
  cluster:
    name: your-app-postgres
EOF

# List backups
kubectl get backups -n your-app-namespace

# Check backup status
kubectl describe backup <backup-name> -n your-app-namespace
```

### Database Operations
```bash
# Connect to database
kubectl exec -it your-app-postgres-1 -n your-app-namespace -- psql -U your_user -d your_database

# Run SQL commands
kubectl exec -it your-app-postgres-1 -n your-app-namespace -- psql -U your_user -d your_database -c "SELECT version();"

# Create database dump
kubectl exec your-app-postgres-1 -n your-app-namespace -- pg_dump -U your_user your_database > backup.sql
```

### Scaling Operations
```bash
# Scale to zero (saves ~500Mi memory)
kubectl patch cluster your-app-postgres -n your-app-namespace \
  --type='merge' -p='{"spec":{"instances":0}}'

# Scale back up
kubectl patch cluster your-app-postgres -n your-app-namespace \
  --type='merge' -p='{"spec":{"instances":1}}'

# Adjust resources
kubectl patch cluster your-app-postgres -n your-app-namespace \
  --type='merge' -p='{"spec":{"resources":{"requests":{"memory":"1Gi"},"limits":{"memory":"1Gi"}}}}'
```

## Advanced Configuration

### Custom PostgreSQL Parameters
```yaml
# In postgres-cluster.yaml
postgresql:
  parameters:
    max_connections: "200"
    shared_buffers: "256MB"
    effective_cache_size: "512MB"
    work_mem: "4MB"
    maintenance_work_mem: "128MB"
    log_min_duration_statement: "1000"
```

### Scheduled Backups
```yaml
apiVersion: postgresql.cnpg.io/v1
kind: ScheduledBackup
metadata:
  name: daily-backup
  namespace: your-app-namespace
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  backupOwnerReference: self
  cluster:
    name: your-app-postgres
```

### High Availability (Multiple Instances)
```yaml
# In postgres-cluster.yaml
spec:
  instances: 3  # Primary + 2 replicas
  
  # Anti-affinity to spread across nodes
  affinity:
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchLabels:
              cnpg.io/cluster: your-app-postgres
          topologyKey: kubernetes.io/hostname
```

## Troubleshooting

### Common Issues

1. **Cluster not starting**:
   ```bash
   kubectl describe cluster your-app-postgres -n your-app-namespace
   kubectl get events -n your-app-namespace --sort-by='.lastTimestamp'
   ```

2. **Backup failures**:
   ```bash
   kubectl get backups -n your-app-namespace
   kubectl describe backup <backup-name> -n your-app-namespace
   kubectl logs -n cnpg-system deployment/cnpg-controller-manager
   ```

3. **Connection issues**:
   ```bash
   # Test connectivity from application pod
   kubectl exec -it <app-pod> -n your-app-namespace -- nc -zv your-app-postgres-rw 5432
   
   # Check service endpoints
   kubectl get endpoints your-app-postgres-rw -n your-app-namespace
   ```

4. **Performance issues**:
   ```bash
   # Check resource usage
   kubectl top pods -n your-app-namespace
   
   # Check PostgreSQL metrics in Grafana
   # Access Grafana at http://grafana.homelab.local
   ```

### Recovery Procedures

1. **Point-in-Time Recovery**:
   ```yaml
   # Create new cluster from backup
   apiVersion: postgresql.cnpg.io/v1
   kind: Cluster
   metadata:
     name: your-app-postgres-recovery
   spec:
     instances: 1
     bootstrap:
       recovery:
         backup:
           name: <backup-name>
         recoveryTarget:
           targetTime: "2025-07-17 10:00:00"
   ```

2. **Disaster Recovery**:
   ```bash
   # List available backups
   kubectl get backups -n your-app-namespace
   
   # Create recovery cluster
   kubectl apply -f recovery-cluster.yaml
   
   # Verify recovery
   kubectl exec -it your-app-postgres-recovery-1 -n your-app-namespace -- psql -U your_user -d your_database -c "SELECT NOW();"
   ```

## Best Practices

### Security
- Use strong, unique passwords for each database
- Never commit credentials to Git repositories
- Rotate credentials regularly
- Use network policies to restrict database access
- Enable connection logging for audit trails

### Performance
- Start with conservative resource allocation and monitor
- Adjust PostgreSQL parameters based on workload
- Use connection pooling in applications
- Monitor query performance and optimize as needed
- Consider read replicas for read-heavy workloads

### Backup Strategy
- Test backup and recovery procedures regularly
- Monitor backup success rates via Prometheus alerts
- Maintain appropriate retention policies
- Document recovery procedures for your team
- Verify backup integrity periodically

### Monitoring
- Set up alerts for cluster health and backup failures
- Monitor resource usage and performance metrics
- Use Grafana dashboards for visualization
- Track connection counts and query performance
- Monitor storage usage and plan for growth

## Integration Examples

For complete examples of applications using CNPG PostgreSQL, see:
- `examples/applications/database-app/` - Basic database application
- `clusters/um890/temporal/` - Temporal workflow system (when implemented)
- `docs/to-do/TEMPORAL_DEPLOYMENT_PLAN.md` - Temporal integration plan

## Support and Resources

- **CNPG Documentation**: https://cloudnative-pg.io/documentation/
- **PostgreSQL Documentation**: https://www.postgresql.org/docs/
- **Homelab-Foundations Issues**: GitHub repository issues
- **CNPG Operator Logs**: `kubectl logs -n cnpg-system deployment/cnpg-controller-manager`
- **Verification Script**: `./scripts/verify-cnpg.sh`
