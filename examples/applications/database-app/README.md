# Database Application Example

## Overview

This example shows deployment of a stateful database application (PostgreSQL) with persistent storage using Longhorn CSI, secret management, and backup considerations.

## Components

- **StatefulSet**: PostgreSQL database with persistent storage
- **Service**: Internal service for database access
- **PersistentVolumeClaim**: Longhorn-backed storage for data persistence
- **Secret**: Database credentials and configuration
- **ConfigMap**: Database initialization scripts
- **ServiceMonitor**: Prometheus monitoring integration

## Features

- Persistent data storage via Longhorn CSI
- Secure credential management with Kubernetes secrets
- Database initialization with custom scripts
- Health checks and monitoring
- Backup-ready configuration
- Resource limits and security contexts

## Prerequisites

- Longhorn CSI deployed and healthy
- Sufficient storage capacity available
- Monitoring stack (optional, for metrics)

## Configuration

### 1. Database Credentials
The example uses a Kubernetes secret for database credentials. In production, consider using external secret management.

### 2. Storage Size
Edit `statefulset.yaml` to adjust storage requirements:
```yaml
volumeClaimTemplates:
- metadata:
    name: postgres-data
  spec:
    resources:
      requests:
        storage: 20Gi  # Adjust as needed
```

### 3. Resource Limits
Adjust CPU and memory based on your workload:
```yaml
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
