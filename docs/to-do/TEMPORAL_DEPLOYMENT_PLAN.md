# Temporal Deployment Plan

**Version**: 1.1
**Date**: 2025-07-17
**Author**: Brandon Huey (with Augment Agent)
**Status**: Draft

## Overview

This document outlines the deployment plan for Temporal workflow system in the homelab-foundations cluster using CloudNativePG (CNPG) operator for PostgreSQL backend and GitOps management via Flux. This plan follows the established homelab-foundations pattern of co-locating PostgreSQL instances with their applications.

## Architecture

### Components
- **Temporal Server**: v1.28.0 (latest stable)
- **Temporal Helm Chart**: v0.64.0 (latest)
- **Database**: PostgreSQL via CNPG operator
- **Visibility Store**: Elasticsearch (existing monitoring stack)
- **Storage**: Longhorn persistent volumes
- **Networking**: MetalLB LoadBalancer + HAProxy Ingress

### Resource Allocation
- **Temporal Frontend**: 1 replica, 1Gi memory, 500m CPU
- **Temporal History**: 1 replica, 2Gi memory, 1000m CPU
- **Temporal Matching**: 1 replica, 1Gi memory, 500m CPU
- **Temporal Worker**: 1 replica, 1Gi memory, 500m CPU
- **Temporal Web UI**: 1 replica, 512Mi memory, 250m CPU
- **PostgreSQL (CNPG)**: 1 replica, 500Mi memory, 250m CPU
- **Total Memory**: ~6Gi (scalable to zero when not in use)

## Database Configuration

### PostgreSQL Cluster (CNPG) - Co-located with Temporal

**Architecture Decision**: Following the homelab-foundations pattern, the PostgreSQL cluster is co-located with Temporal in `clusters/um890/temporal/postgres-cluster.yaml` rather than centrally managed.

```yaml
# clusters/um890/temporal/postgres-cluster.yaml
# PostgreSQL cluster for Temporal (co-located with application)
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: temporal-postgres
  namespace: temporal-system
spec:
  instances: 1  # Single instance for homelab

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

  bootstrap:
    initdb:
      database: temporal
      owner: temporal
      secret:
        name: temporal-postgres-credentials

  storage:
    size: 20Gi
    storageClass: longhorn

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
      destinationPath: "s3://postgres-backups/temporal"
      s3Credentials:
        accessKeyId:
          name: minio-backup-credentials
          key: ACCESS_KEY_ID
        secretAccessKey:
          name: minio-backup-credentials
          key: SECRET_ACCESS_KEY
      endpointURL: "http://minio-tenant-hl.minio-tenant.svc.cluster.local:9000"
```

### Database Schema Setup
Two databases required:
1. **temporal**: Core workflow execution data
2. **temporal_visibility**: Search and query data

## Network Configuration

### Service Endpoints
- **Temporal Frontend (gRPC)**: `10.0.0.241:7233`
- **Temporal Web UI (HTTP)**: `http://10.0.0.241:8080`
- **Temporal Web UI (Ingress)**: `http://temporal.homelab.local`

### MetalLB IP Allocation
- **temporal-frontend-lb**: `10.0.0.241`
- **temporal-web-lb**: `10.0.0.241` (shared with frontend, different ports)

## Directory Structure

**Co-located Architecture**: All Temporal components including PostgreSQL are managed together in the temporal directory.

```
clusters/um890/temporal/
├── kustomization.yaml           # Main kustomization
├── postgres-cluster.yaml       # CNPG PostgreSQL cluster (co-located)
├── postgres-secret.yaml        # Database credentials secret
├── postgres-init-job.yaml      # Temporal schema initialization
├── helmrelease.yaml            # Temporal Helm release
├── services.yaml               # MetalLB LoadBalancer services
├── ingress.yaml                # HAProxy ingress configuration
├── servicemonitor.yaml         # ServiceMonitor for Prometheus
└── README.md                   # Component documentation
```

**Benefits of Co-location**:
- **Single Source of Truth**: All Temporal-related configs in one place
- **Atomic Deployments**: Database and application deploy together
- **Easier Troubleshooting**: All related resources in one location
- **Simplified Rollbacks**: Rollback application and database together
- **Clear Ownership**: Temporal team owns their database configuration

## Deployment Phases

### Phase 1: Prerequisites (CNPG Foundation)
**Note**: CNPG operator must be deployed first as infrastructure foundation.
1. **CNPG Operator**: Deploy CloudNativePG operator (separate implementation)
2. **Backup Configuration**: Ensure MinIO backup credentials are configured
3. **Templates**: Verify PostgreSQL cluster templates are available

### Phase 2: Temporal Infrastructure Setup
1. **Helm Repository**: Add Temporal Helm repository to infrastructure
2. **Namespace**: Add temporal-system namespace to cluster namespaces
3. **Directory Structure**: Create clusters/um890/temporal/ directory

### Phase 3: Database Setup (Co-located)
1. **PostgreSQL Cluster**: Deploy CNPG PostgreSQL cluster in temporal directory
2. **Database Credentials**: Configure database access secrets
3. **Schema Initialization**: Create initialization job for Temporal schemas
4. **Backup Verification**: Verify backup configuration works

### Phase 4: Temporal Application Deployment
1. **Temporal Server**: Deploy via Helm with PostgreSQL configuration
2. **Services**: Configure MetalLB LoadBalancer services
3. **Ingress**: Setup HAProxy ingress for Web UI
4. **Monitoring**: Configure Prometheus ServiceMonitor

### Phase 5: Integration and Testing
1. **GitOps**: Add temporal to main cluster kustomization
2. **Documentation**: Update README and guides
3. **Testing**: Verify deployment, connectivity, and workflow execution
4. **Scaling**: Test scale-to-zero and scale-up procedures

## Configuration Details

### Temporal Helm Values
```yaml
server:
  replicaCount: 1
  config:
    persistence:
      default:
        driver: "sql"
        sql:
          driver: "postgres"
          host: "temporal-postgres-rw.temporal-system.svc.cluster.local"
          port: 5432
          database: "temporal"
          user: "temporal"
          password: "${POSTGRES_PASSWORD}"
          maxConns: 20
          maxConnLifetime: "1h"
      visibility:
        driver: "sql"
        sql:
          driver: "postgres"
          host: "temporal-postgres-rw.temporal-system.svc.cluster.local"
          port: 5432
          database: "temporal_visibility"
          user: "temporal"
          password: "${POSTGRES_PASSWORD}"
          maxConns: 10
          maxConnLifetime: "1h"

web:
  enabled: true
  replicaCount: 1
  
cassandra:
  enabled: false  # Disable bundled Cassandra

elasticsearch:
  enabled: false  # Use existing Elasticsearch from monitoring
```

## Monitoring Integration

### Prometheus Metrics
- **Temporal Server**: JMX metrics on port 9090
- **PostgreSQL**: CNPG operator metrics
- **Web UI**: Application metrics

### Grafana Dashboards
- Temporal Server performance
- Database connection pools
- Workflow execution metrics
- System resource utilization

## Operational Procedures

### Scaling to Zero
```bash
# Scale down Temporal (saves ~5.5Gi memory)
kubectl scale deployment -n temporal-system --replicas=0 \
  temporal-frontend temporal-history temporal-matching temporal-worker temporal-web

# Scale down PostgreSQL (saves ~500Mi memory)
kubectl patch cluster temporal-postgres -n temporal-system \
  --type='merge' -p='{"spec":{"instances":0}}'
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

### Database Backup
CNPG provides automated backup capabilities (configured in co-located postgres-cluster.yaml):
```yaml
# In clusters/um890/temporal/postgres-cluster.yaml
backup:
  retentionPolicy: "30d"
  barmanObjectStore:
    destinationPath: "s3://postgres-backups/temporal"
    s3Credentials:
      accessKeyId:
        name: minio-backup-credentials
        key: ACCESS_KEY_ID
      secretAccessKey:
        name: minio-backup-credentials
        key: SECRET_ACCESS_KEY
    endpointURL: "http://minio-tenant-hl.minio-tenant.svc.cluster.local:9000"
```

## Dependencies

### Required Before Deployment
1. **CNPG Operator**: CloudNativePG operator installed
2. **Longhorn**: Storage CSI available
3. **MetalLB**: LoadBalancer services configured
4. **HAProxy Ingress**: Ingress controller operational
5. **Monitoring Stack**: Elasticsearch and Prometheus available

### Integration Points
- **MinIO**: Optional backup storage for PostgreSQL
- **Elasticsearch**: Visibility store (existing monitoring stack)
- **Prometheus**: Metrics collection
- **Grafana**: Dashboard visualization

## Implementation Dependencies

### Prerequisites (Must be completed first)
1. **CNPG Operator Deployment**: CloudNativePG operator must be installed and operational
2. **CNPG Templates**: PostgreSQL cluster templates must be available
3. **Backup Infrastructure**: MinIO backup credentials must be configured
4. **Monitoring Stack**: Prometheus must be operational for metrics collection

### Implementation Order
1. **CNPG Foundation**: Complete CNPG operator deployment (separate task)
2. **Temporal Implementation**: Follow this plan once CNPG is ready

## Next Steps

**Immediate (CNPG Foundation)**:
1. **Deploy CNPG Operator**: Complete CNPG operator installation first
2. **Verify CNPG**: Ensure operator is functional and backup is configured

**Future (Temporal Implementation)**:
1. **Create Temporal Configuration**: Implement the co-located directory structure
2. **Database Schema Setup**: Initialize Temporal databases using CNPG
3. **Temporal Deployment**: Deploy via GitOps with co-located PostgreSQL
4. **Documentation Updates**: Update README and guides
5. **Testing**: Verify workflow execution capabilities and scaling procedures

## Benefits

### Resource Efficiency
- **PostgreSQL**: More efficient than Cassandra for single-node
- **Scalable**: Can scale to zero when not in use
- **Shared Infrastructure**: Leverages existing monitoring and storage

### Operational Excellence
- **GitOps Managed**: Consistent with cluster management approach
- **Backup Integration**: CNPG provides robust backup capabilities
- **Monitoring Ready**: Full observability out of the box
- **Cloud Native**: Modern PostgreSQL management with CNPG

### Development Ready
- **Standard APIs**: gRPC and HTTP interfaces
- **SDK Support**: All major programming languages
- **Workflow Patterns**: Supports complex business logic orchestration
- **Integration**: Works with existing analytics stack (Trino, ClickHouse)
