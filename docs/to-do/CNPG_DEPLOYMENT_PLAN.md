# CloudNativePG (CNPG) Deployment Plan

**Version**: 1.0  
**Date**: 2025-07-16  
**Author**: Brandon Huey (with Augment Agent)  
**Status**: Draft

## Overview

This document outlines the deployment plan for CloudNativePG (CNPG) operator in the homelab-foundations cluster using GitOps management via Flux. CNPG will serve as the PostgreSQL management foundation for multiple applications including Temporal and future database needs.

## Architecture

### Components
- **CNPG Operator**: Latest stable version (v1.24.x)
- **Management**: GitOps via Flux CD
- **Namespace**: `cnpg-system` (CNPG default)
- **Monitoring**: Prometheus integration enabled by default
- **Storage**: Longhorn persistent volumes for all PostgreSQL instances
- **Backup**: MinIO S3-compatible storage integration

### Resource Allocation
- **CNPG Operator**: 1 replica, 256Mi memory, 100m CPU
- **Webhook**: 1 replica, 128Mi memory, 50m CPU
- **Total Memory**: ~384Mi for operator infrastructure

## Directory Structure

```
clusters/um890/cnpg/
├── kustomization.yaml           # Main kustomization
├── namespace.yaml              # cnpg-system namespace
├── helmrelease.yaml            # CNPG Helm release
├── monitoring.yaml             # ServiceMonitor for Prometheus
├── backup-config.yaml          # Default backup configuration
└── README.md                   # Component documentation
```

## CNPG Operator Configuration

### Helm Repository
```yaml
# infrastructure/helm-repositories/cnpg.yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: cnpg
  namespace: flux-system
spec:
  interval: 1h
  url: https://cloudnative-pg.github.io/charts
```

### Helm Release
```yaml
# clusters/um890/cnpg/helmrelease.yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: cloudnative-pg
  namespace: cnpg-system
spec:
  interval: 10m
  chart:
    spec:
      chart: cloudnative-pg
      version: '>=0.22.0'
      sourceRef:
        kind: HelmRepository
        name: cnpg
        namespace: flux-system
  values:
    # Operator configuration
    replicaCount: 1
    
    # Resource allocation
    resources:
      requests:
        cpu: 100m
        memory: 256Mi
      limits:
        cpu: 200m
        memory: 256Mi
    
    # Monitoring configuration
    monitoring:
      enabled: true
      createGrafanaDashboard: true
      grafanaDashboard:
        namespace: monitoring
        labels:
          grafana_dashboard: "1"
    
    # Webhook configuration
    webhook:
      replicaCount: 1
      resources:
        requests:
          cpu: 50m
          memory: 128Mi
        limits:
          cpu: 100m
          memory: 128Mi
    
    # Security context
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop:
          - ALL
      readOnlyRootFilesystem: true
      runAsNonRoot: true
      runAsUser: 10001
      seccompProfile:
        type: RuntimeDefault
    
    # Additional configuration
    config:
      # Enable monitoring for all clusters by default
      MONITORING_ENABLED: "true"
      # Default backup retention
      BACKUP_RETENTION_POLICY: "30d"
      # Log level
      LOG_LEVEL: "info"
```

## Default Cluster Configuration

### Monitoring Integration
```yaml
# clusters/um890/cnpg/monitoring.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: cnpg-operator
  namespace: cnpg-system
  labels:
    prometheus: kube-prometheus
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: cloudnative-pg
  endpoints:
    - port: metrics
      interval: 30s
      path: /metrics
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: cnpg-clusters
  namespace: cnpg-system
  labels:
    prometheus: kube-prometheus
spec:
  selector:
    matchLabels:
      cnpg.io/cluster: ""
  endpoints:
    - port: metrics
      interval: 30s
      path: /metrics
  namespaceSelector:
    any: true
```

### Default Backup Configuration
```yaml
# clusters/um890/cnpg/backup-config.yaml
apiVersion: v1
kind: Secret
metadata:
  name: minio-backup-credentials
  namespace: cnpg-system
type: Opaque
data:
  ACCESS_KEY_ID: # Base64 encoded MinIO access key
  SECRET_ACCESS_KEY: # Base64 encoded MinIO secret key
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: cnpg-backup-config
  namespace: cnpg-system
data:
  backup-config.yaml: |
    # Default backup configuration for CNPG clusters
    backup:
      retentionPolicy: "30d"
      barmanObjectStore:
        destinationPath: "s3://postgres-backups"
        s3Credentials:
          accessKeyId:
            name: minio-backup-credentials
            key: ACCESS_KEY_ID
          secretAccessKey:
            name: minio-backup-credentials
            key: SECRET_ACCESS_KEY
        endpointURL: "http://minio-tenant-hl.minio-tenant.svc.cluster.local:9000"
        wal:
          retention: "7d"
        data:
          retention: "30d"
```

## PostgreSQL Instance Management Strategy

### Architecture Decision: Co-located PostgreSQL Instances

**PostgreSQL instances are deployed co-located with their applications** following the established homelab-foundations pattern (consistent with Trino/Iceberg co-location).

**Structure:**
```
clusters/um890/cnpg/              # CNPG operator (infrastructure)
├── kustomization.yaml
├── helmrelease.yaml
├── monitoring.yaml
└── backup-config.yaml

clusters/um890/temporal/          # Application with PostgreSQL
├── kustomization.yaml
├── helmrelease.yaml              # Temporal server
├── postgres-cluster.yaml         # Temporal's PostgreSQL instance
├── postgres-secret.yaml          # Temporal's DB credentials
└── servicemonitor.yaml

clusters/um890/future-app/        # Another application
├── postgres-cluster.yaml         # Another PostgreSQL instance
└── ...
```

### PostgreSQL Cluster Template

**Template Location**: `docs/templates/postgres-cluster-template.yaml`

```yaml
# Template for homelab PostgreSQL clusters
# Copy to application directory and customize
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: APP_NAME-postgres
  namespace: APP_NAMESPACE
spec:
  instances: 1  # Single instance for homelab

  # PostgreSQL configuration
  postgresql:
    parameters:
      # Performance tuning for homelab
      max_connections: "100"
      shared_buffers: "128MB"
      effective_cache_size: "256MB"
      work_mem: "2MB"
      maintenance_work_mem: "64MB"

      # Logging
      log_statement: "none"
      log_min_duration_statement: "1000"

      # Monitoring
      shared_preload_libraries: "pg_stat_statements"

  # Bootstrap configuration
  bootstrap:
    initdb:
      database: APP_DATABASE
      owner: APP_USER
      secret:
        name: APP_NAME-postgres-credentials

  # Storage configuration
  storage:
    size: 20Gi
    storageClass: longhorn

  # Resource allocation (adjust per application)
  resources:
    requests:
      memory: 500Mi
      cpu: 250m
    limits:
      memory: 500Mi
      cpu: 500m

  # Monitoring
  monitoring:
    enabled: true

  # Backup configuration
  backup:
    retentionPolicy: "30d"
    barmanObjectStore:
      destinationPath: "s3://postgres-backups/APP_NAME"
      s3Credentials:
        accessKeyId:
          name: minio-backup-credentials
          key: ACCESS_KEY_ID
        secretAccessKey:
          name: minio-backup-credentials
          key: SECRET_ACCESS_KEY
      endpointURL: "http://minio-tenant-hl.minio-tenant.svc.cluster.local:9000"
```

## Deployment Phases

### Phase 1: Infrastructure Setup
1. **Helm Repository**: Add CNPG Helm repository
2. **Namespace**: Create cnpg-system namespace
3. **Backup Credentials**: Configure MinIO credentials for backups

### Phase 2: Operator Deployment
1. **CNPG Operator**: Deploy via Helm with monitoring enabled
2. **Monitoring**: Configure ServiceMonitors for Prometheus
3. **Backup Config**: Setup default backup configuration

### Phase 3: Integration and Documentation
1. **GitOps**: Add to main cluster kustomization
2. **Documentation**: Update README and guides
3. **Templates**: Create PostgreSQL cluster templates for applications
4. **Testing**: Verify operator functionality

### Phase 4: Application Integration (Deferred to Temporal Implementation)
**Note**: PostgreSQL instances will be deployed co-located with applications following the established homelab-foundations pattern. The first PostgreSQL cluster will be deployed as part of the Temporal implementation phase.

## Operational Procedures

### Creating New PostgreSQL Clusters
```bash
# Copy template and customize
cp docs/templates/postgres-cluster-template.yaml clusters/um890/app-name/postgres-cluster.yaml

# Edit configuration for specific application
# - Replace APP_NAME with actual application name
# - Replace APP_NAMESPACE with target namespace
# - Replace APP_DATABASE and APP_USER with database details
# - Adjust resource allocation as needed
# - Customize backup path

# Apply via GitOps
git add clusters/um890/app-name/
git commit -m "Add PostgreSQL cluster for app-name"
git push
```

### Monitoring PostgreSQL Clusters
```bash
# Check cluster status
kubectl get clusters -A

# View cluster details
kubectl describe cluster cluster-name -n namespace

# Check backup status
kubectl get backups -n namespace

# View logs
kubectl logs -n cnpg-system deployment/cnpg-controller-manager
```

### Backup and Recovery
```bash
# Manual backup
kubectl create backup manual-backup --cluster=cluster-name -n namespace

# List backups
kubectl get backups -n namespace

# Recovery (create new cluster from backup)
kubectl apply -f recovery-cluster.yaml
```

## Integration Points

### MinIO Backup Storage
- **Bucket**: `postgres-backups`
- **Path Structure**: `/cluster-name/`
- **Retention**: 30 days default
- **Credentials**: Shared MinIO credentials

### Prometheus Monitoring
- **Operator Metrics**: CNPG operator performance
- **Cluster Metrics**: PostgreSQL instance metrics
- **Backup Metrics**: Backup success/failure rates
- **Connection Metrics**: Database connection pools

### Grafana Dashboards
- **CNPG Operator**: Operator health and performance
- **PostgreSQL Overview**: Database performance metrics
- **Backup Status**: Backup success rates and timing

## Security Considerations

### RBAC
- **Operator**: Cluster-wide permissions for PostgreSQL management
- **Clusters**: Namespace-scoped permissions
- **Backup**: MinIO credentials stored as secrets

### Network Policies
- **Database Access**: Restrict to application namespaces
- **Backup Traffic**: Allow access to MinIO
- **Monitoring**: Allow Prometheus scraping

## Benefits

### Operational Excellence
- **GitOps Managed**: Consistent with cluster management
- **Automated Backups**: Built-in backup to MinIO
- **Monitoring Ready**: Full Prometheus integration
- **Scalable**: Easy to deploy multiple PostgreSQL instances

### Resource Efficiency
- **Single Instances**: No HA overhead for homelab
- **Right-Sized**: Conservative resource allocation
- **Backup Deduplication**: Efficient storage usage

### Developer Experience
- **Template-Based**: Consistent PostgreSQL deployments
- **Self-Service**: Easy to create new databases
- **Monitoring**: Full observability out of the box

## Template Structure

### Templates to Create
```
docs/templates/
├── postgres-cluster-template.yaml      # PostgreSQL cluster definition
├── postgres-secret-template.yaml       # Database credentials template
└── postgres-init-job-template.yaml     # Schema initialization template

examples/applications/database-app/
├── README.md                           # How to use PostgreSQL in applications
├── postgres-cluster.yaml               # Example PostgreSQL configuration
├── postgres-secret.yaml                # Example credentials
└── kustomization.yaml                  # Example kustomization
```

## Next Steps

1. **Deploy CNPG Operator**: Implement GitOps configuration (Phases 1-3)
2. **Setup Backup Storage**: Create MinIO bucket and credentials
3. **Configure Monitoring**: Verify Prometheus integration
4. **Create Templates**: Develop PostgreSQL cluster templates
5. **Documentation**: Update README and operational guides
6. **Testing**: Validate operator functionality and backup configuration

**Deferred to Temporal Implementation:**
- First PostgreSQL cluster deployment
- Schema initialization procedures
- End-to-end application integration testing

This plan establishes CNPG as the PostgreSQL foundation for your homelab, enabling easy deployment of multiple PostgreSQL instances with consistent monitoring, backup, and operational procedures. The first real PostgreSQL instance will be deployed as part of the Temporal implementation following the co-located architecture pattern.
