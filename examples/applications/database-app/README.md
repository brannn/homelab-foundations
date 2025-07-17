# Database Application Example

**Version**: 1.1
**Date**: 2025-07-17
**Author**: Community Contributors
**Status**: Active

## Overview

This example demonstrates how to deploy an application with a PostgreSQL database using the CloudNativePG (CNPG) operator in homelab-foundations. It follows the co-located architecture pattern where the PostgreSQL instance is managed alongside the application.

## Components

- **CNPG Cluster**: PostgreSQL database managed by CloudNativePG operator
- **Application Deployment**: Example application that connects to PostgreSQL
- **Service**: Internal service for application access
- **Secret**: Database credentials and configuration
- **ServiceMonitor**: Prometheus monitoring integration
- **Ingress**: External access configuration (optional)

## Features

- **Modern PostgreSQL Management**: Uses CloudNativePG operator for advanced features
- **Automated Backups**: Built-in backup to MinIO S3-compatible storage
- **High Availability**: Operator-managed failover and recovery
- **Monitoring Integration**: Full Prometheus metrics and Grafana dashboards
- **Co-located Architecture**: Database and application managed together
- **GitOps Ready**: Fully declarative configuration

## Prerequisites

- **CNPG Operator**: CloudNativePG operator deployed and operational
- **MinIO Backup Credentials**: Configured in cnpg-system namespace
- **Longhorn CSI**: Deployed and healthy for persistent storage
- **Monitoring Stack**: Prometheus operational for metrics collection

## Architecture

### Co-located Pattern
```
clusters/um890/my-app/
├── kustomization.yaml           # Main kustomization
├── postgres-cluster.yaml       # PostgreSQL cluster (co-located)
├── postgres-secret.yaml        # Database credentials
├── postgres-init-job.yaml      # Optional schema initialization
├── deployment.yaml             # Application deployment
├── service.yaml                # Application service
├── ingress.yaml                # Application ingress
└── servicemonitor.yaml         # Monitoring configuration
```

### Benefits
- **Single Source of Truth**: All app-related configs in one place
- **Atomic Deployments**: Database and application deploy together
- **Easier Troubleshooting**: All related resources in one location
- **Clear Ownership**: Application team owns database configuration

## Configuration

### 1. PostgreSQL Cluster Setup
Copy and customize the PostgreSQL cluster template:
```bash
cp docs/templates/postgres-cluster-template.yaml clusters/um890/my-app/postgres-cluster.yaml
```

Edit the cluster configuration:
```yaml
metadata:
  name: my-app-postgres
  namespace: my-app-namespace

bootstrap:
  initdb:
    database: myapp_db
    owner: myapp_user
    secret:
      name: my-app-postgres-credentials

storage:
  size: 20Gi  # Adjust as needed
  storageClass: longhorn

resources:
  requests:
    memory: 500Mi  # Adjust based on workload
    cpu: 250m
  limits:
    memory: 500Mi
    cpu: 500m
```

### 2. Database Credentials
Create secure credentials (never commit to Git):
```bash
USERNAME="myapp_user"
PASSWORD="$(openssl rand -base64 32)"

# Create base64 encoded values
USERNAME_B64=$(echo -n "$USERNAME" | base64)
PASSWORD_B64=$(echo -n "$PASSWORD" | base64)
```

### 3. Application Connection
Configure your application to connect to PostgreSQL:
resources:
  limits:
    cpu: 1000m
    memory: 2Gi
  requests:
    cpu: 500m
    memory: 1Gi
```

## Deployment

1. Copy this directory to your cluster configuration:
   ```bash
   cp -r examples/applications/database-app/ clusters/um890/postgres/
   ```

2. Review and customize the configuration files

3. Add to your main kustomization:
   ```bash
   echo "  - postgres" >> clusters/um890/kustomization.yaml
   ```

4. Commit and push:
   ```bash
   git add clusters/um890/postgres/
   git commit -m "Add PostgreSQL database application"
   git push origin main
   ```

5. Verify deployment:
   ```bash
   kubectl get pods -n postgres
   kubectl get pvc -n postgres
   kubectl get svc -n postgres
   ```

## Accessing the Database

### From within the cluster
```bash
kubectl exec -it postgres-0 -n postgres -- psql -U postgres -d myapp
```

### Port forwarding for external access
```bash
kubectl port-forward -n postgres svc/postgres 5432:5432
```

Then connect with:
```bash
psql -h localhost -U postgres -d myapp
```

### Connection string for applications
```
postgresql://postgres:your-password@postgres.postgres.svc.cluster.local:5432/myapp
```

## Database Management

### Create additional databases
```sql
CREATE DATABASE newapp;
CREATE USER newuser WITH PASSWORD 'newpassword';
GRANT ALL PRIVILEGES ON DATABASE newapp TO newuser;
```

### Check database status
```bash
kubectl exec -it postgres-0 -n postgres -- psql -U postgres -c "\l"
kubectl exec -it postgres-0 -n postgres -- psql -U postgres -c "\du"
```

### Monitor storage usage
```bash
kubectl exec -it postgres-0 -n postgres -- df -h /var/lib/postgresql/data
```

## Backup Strategy

### Manual backup
```bash
kubectl exec -it postgres-0 -n postgres -- pg_dump -U postgres myapp > backup.sql
```

### Automated backup (example CronJob)
See `backup-cronjob.yaml` for an automated backup solution.

### Volume snapshots
Use Longhorn's snapshot feature for point-in-time recovery:
```bash
kubectl get volumesnapshot -n postgres
```

## Monitoring

This example includes Prometheus monitoring via ServiceMonitor:
- Connection metrics
- Query performance
- Storage usage
- Replication status (if configured)

View metrics in Grafana or query Prometheus directly.

## Security Considerations

- Database runs as non-root user
- Secrets are used for sensitive configuration
- Network policies can restrict database access
- Consider encryption at rest for sensitive data

## Scaling Considerations

### Vertical scaling
Adjust resource limits in the StatefulSet:
```yaml
resources:
  limits:
    cpu: 2000m
    memory: 4Gi
```

### Storage expansion
Longhorn supports volume expansion:
```bash
kubectl patch pvc postgres-data-postgres-0 -n postgres -p '{"spec":{"resources":{"requests":{"storage":"50Gi"}}}}'
```

### Read replicas
For read scaling, consider PostgreSQL streaming replication or read-only replicas.

## Troubleshooting

### Pod not starting
```bash
kubectl describe pod postgres-0 -n postgres
kubectl logs postgres-0 -n postgres
```

### Storage issues
```bash
kubectl get pvc -n postgres
kubectl describe pvc postgres-data-postgres-0 -n postgres
kubectl get volumes -n longhorn-system
```

### Connection issues
```bash
kubectl exec -it postgres-0 -n postgres -- pg_isready
kubectl get svc -n postgres
kubectl describe svc postgres -n postgres
```

### Performance issues
```bash
kubectl exec -it postgres-0 -n postgres -- psql -U postgres -c "SELECT * FROM pg_stat_activity;"
```

## Maintenance

### Update PostgreSQL version
Update the image tag in `statefulset.yaml` and apply:
```yaml
image: postgres:15-alpine  # Update version
```

### Configuration changes
Edit the ConfigMap and restart the StatefulSet:
```bash
kubectl rollout restart statefulset postgres -n postgres
```

### Storage maintenance
Monitor Longhorn volumes and perform maintenance as needed:
```bash
kubectl get volumes -n longhorn-system
```
