# Homelab Foundations

**Version**: 1.1
**Date**: 2025-07-14
**Author**: Community Contributors
**Status**: Active

## Overview
It's easier than ever to acquire very powerful mini computer systems at affordable prices, such as the Minisforum UM890 Pro - a Ryzen 9 with 64GB of DDR5 RAM, two M.2. NVMe slots with low heat dissipation and power draw. This makes it possible to effectively replicate an enterprise-class development environment at home in a single node Kubernetes cluster such as with K3s.

Homelab Foundations provides a complete GitOps foundation for single-node Kubernetes homelab clusters on this class of hardware. The infrastructure uses a hybrid approach with Flux CD for core components and Helmfile for complex multi-component applications, providing a robust and maintainable homelab setup.

## Infrastructure Components

### Foundation Components (Managed Outside Flux)
- **Storage CSI**: Longhorn for persistent volumes - *Chart version >=1.5.0* - **Helmfile managed**
- **Object Storage**: MinIO for S3-compatible storage - *Operator/Tenant v7.1.1* - **Helmfile managed**

### GitOps Managed Components (Flux CD)
- **Kubernetes**: Single-node cluster (assumes K3s) - *Tested on v1.32.6+k3s1*
- **GitOps**: Flux CD for continuous deployment
- **Load Balancer**: MetalLB with configurable IP ranges - *Uses v1beta1 API*
- **Certificates**: cert-manager for TLS certificate management - *Chart version >=1.13.0*
- **Ingress**: HAProxy Ingress Controller for HTTP/HTTPS routing - *Chart version >=1.44.0*
- **PostgreSQL Operator**: CloudNativePG (CNPG) for PostgreSQL database management - *Chart version >=0.22.0*
- **Monitoring**: Prometheus + Grafana stack with pre-configured dashboards - *kube-prometheus-stack v61.3.2, Grafana v8.4.2*
- **Analytics Engine**: Trino distributed SQL query engine - *Chart version 1.39.1, Trino v476*
- **Data Lake**: Apache Iceberg REST Catalog for ACID transactions and schema evolution - *Tabular REST Catalog v0.1.0*
- **Messaging System**: NATS with JetStream for high-performance IoT data ingestion - *Chart version 1.1.12, NATS v2.10.11*
- **Analytics Database**: ClickHouse columnar database for real-time analytics - *Altinity Operator v0.25.0, ClickHouse v25.6.3*
- **Workflow Engine**: Temporal workflow orchestration platform with optimized PostgreSQL backend - *Chart version >=0.64.0, Temporal v1.28.0*

## Architecture Decisions

### Storage Foundation Strategy

**Core storage components (Longhorn CSI and MinIO object storage) are intentionally managed outside of Flux using Helmfile for high availability reasons:**

**Why Storage is Foundation-First:**
- **Bootstrap Independence**: Storage must be available before GitOps can function reliably
- **Circular Dependency Prevention**: Flux may need persistent storage for its own operations
- **Recovery Resilience**: If Flux fails, storage remains operational for manual recovery
- **Stability**: Core storage should not be subject to GitOps experimentation or configuration drift

**What's Managed Where:**
- **Foundation (Helmfile)**: Longhorn CSI, MinIO (storage that everything depends on)
- **GitOps (Flux)**: MetalLB, cert-manager, HAProxy, monitoring (services that can recover from removal)

**Benefits:**
- **High Availability**: Storage foundation remains stable during GitOps operations
- **Faster Recovery**: Manual storage deployment when GitOps is compromised
- **Clear Separation**: Infrastructure foundation vs. application services
- **Operational Safety**: Critical storage protected from accidental GitOps changes

### Resource Conservation Strategy

**Application services can be scaled to zero when not in use to conserve homelab resources:**

**Scalable Services (with memory savings):**
- **ClickHouse**: ~2Gi memory savings when scaled down
- **Trino**: ~10Gi memory savings (coordinator + worker)
- **NATS**: ~512Mi memory savings
- **Monitoring**: ~2.5Gi memory savings (Prometheus + Grafana)
- **Temporal**: ~2.6Gi memory savings when scaled down (performance-optimized)

**Foundation Services (keep running):**
- **Longhorn CSI**: Required for all persistent storage
- **MinIO**: Required for object storage and data lake
- **MetalLB**: Required for LoadBalancer services
- **HAProxy**: Required for ingress access

**Total Potential Savings**: ~17.3Gi memory when all application services are scaled down

See [Resource Management Guide](docs/RESOURCE_MANAGEMENT.md) for detailed scaling procedures and automation scripts.

## Repository Structure

```
homelab-foundations/
├── clusters/
│   └── um890/                    # Cluster-specific configurations (Flux managed)
│       ├── flux-system/          # Flux bootstrap manifests
│       ├── namespaces.yaml       # Namespace definitions
│       ├── metallb/              # MetalLB configuration
│       ├── cert-manager/         # Certificate management
│       ├── haproxy-ingress/      # HAProxy Ingress Controller
│       ├── cnpg/                # CloudNativePG PostgreSQL operator
│       ├── dns/                 # Pi-hole DNS server for .homelab.local
│       ├── monitoring/           # Prometheus + Grafana stack
│       │   ├── prometheus/       # Prometheus monitoring
│       │   ├── grafana/          # Grafana dashboards
│       │   ├── node-exporter/    # Node metrics collection
│       │   └── kube-state-metrics/ # Kubernetes metrics
│       ├── trino/                # Trino analytics engine + Iceberg REST catalog
│       ├── nats/                 # NATS messaging system with JetStream
│       ├── clickhouse/           # ClickHouse analytics database
│       └── kustomization.yaml    # Main cluster kustomization
├── infrastructure/
│   └── helm-repositories/        # Helm repository definitions
├── longhorn/                     # Longhorn CSI (Foundation - Helmfile managed)
├── minio/                        # MinIO Object Storage (Foundation - Helmfile managed)
├── docs/                         # Documentation
└── README.md                     # This file
```

## Getting Started

**New to this project?** Start with the **[Quick Start Guide](QUICKSTART.md)** for a complete walkthrough from zero to running homelab in 30 minutes.

### Quick Overview

1. **Fork this repository** to your GitHub account
2. **Customize** network ranges and credentials for your environment
3. **Deploy Foundation Storage** using Helmfile (Longhorn CSI + MinIO)
4. **Bootstrap Flux** to enable GitOps management
5. **Enjoy** your fully automated homelab infrastructure!

### Key Files to Customize

- `clusters/um890/metallb/metallb.yaml` - Update IP ranges for your network
- `longhorn/longhorn-values.yaml` - Configure storage paths and resource limits
- `minio/tenant-values.yaml` - Change MinIO credentials and resource limits
- `clusters/um890/` - Rename directory to match your cluster name

### Documentation

- **[Quick Start Guide](QUICKSTART.md)** - Complete setup walkthrough
- **[Configuration Guide](CONFIGURATION.md)** - Detailed customization options
- **[Quick Reference](docs/QUICK_REFERENCE.md)** - Essential commands and URLs
- **[Architecture](docs/ARCHITECTURE.md)** - System design and components

## Configuration Details

### MetalLB
- **IP Pool**: 10.0.0.240-10.0.0.250
- **Mode**: L2 Advertisement
- **Namespace**: metallb-system

### Longhorn
- **Storage Class**: longhorn (default)
- **Data Path**: /var/lib/longhorn/
- **Replica Count**: 1 (single node)
- **Namespace**: longhorn-system

### MinIO (Helm-managed)
- **Management**: Direct Helm (not Flux)
- **Operator Namespace**: minio-operator
- **Tenant Namespace**: minio-tenant
- **Tenant Name**: minio-tenant
- **Storage**: Configurable size (default: 300Gi per pool)
- **Protocol**: HTTP-only (no SSL/TLS for homelab simplicity)
- **Access**: S3 API and Console via MetalLB LoadBalancer
- **Credentials**: Configurable (see minio/tenant-values.yaml)
- **Status**: ✅ Fully functional with Trino integration

### cert-manager (Flux-managed)
- **Namespace**: cert-manager
- **Purpose**: Automated TLS certificate management
- **ClusterIssuer**: Pre-configured for Let's Encrypt (staging and production)
- **Integration**: Ready for use with ingress controllers and services
- **Note**: Currently available but not integrated with existing services

### CloudNativePG (Flux-managed)
- **Namespace**: cnpg-system
- **Purpose**: PostgreSQL database management and automation
- **Version**: v1.24+ (PostgreSQL 17.5)
- **Architecture**: Co-located PostgreSQL instances with applications
- **Backup**: Automated backup to MinIO S3-compatible storage with continuous WAL archiving
- **Monitoring**: Full Prometheus metrics and Grafana dashboards
- **Resource Usage**: ~384Mi memory for operator infrastructure
- **Features**: High availability, automated failover, point-in-time recovery, automated schema management
- **Templates**: Available in `docs/templates/` for easy PostgreSQL deployment
- **Status**: ✅ Production ready, tested and validated
- **Usage**: See [PostgreSQL Deployment Guide](#postgresql-deployment-with-cnpg) below

### Monitoring (Flux-managed)
- **Namespace**: monitoring
- **Prometheus**: Metrics collection and storage (30-day retention)
- **Grafana**: Dashboards and visualization (admin/grafana123)
- **Node Exporter**: Host-level metrics
- **Kube State Metrics**: Kubernetes object metrics
- **Storage**: Longhorn-backed persistent volumes
- **Dashboards**: Pre-configured for Kubernetes, nodes, and Longhorn
- **Note**: Dashboard compatibility varies by Kubernetes distribution; customization may be required

### Trino Analytics Engine (Flux-managed)
- **Namespace**: iceberg-system
- **Architecture**: 1 coordinator (4Gi RAM) + 1 worker (6Gi RAM)
- **Total Memory**: 10Gi cluster memory allocation
- **Catalogs**: Iceberg (REST), Memory, TPC-H, TPC-DS
- **Web UI**: http://10.0.0.246:8080 (no authentication required)
- **Authentication**: None (open access for homelab environment)
- **Monitoring**: JMX metrics exported to Prometheus
- **Storage Integration**: MinIO S3-compatible backend via Iceberg REST catalog

### Iceberg REST Catalog (Flux-managed)
- **Namespace**: iceberg-system
- **Purpose**: ACID transactions, schema evolution, time travel queries
- **Memory**: 512Mi allocation
- **API Endpoint**: http://10.0.0.247:8181
- **Metadata Backend**: PostgreSQL via CNPG (iceberg-postgres cluster)
- **Storage Backend**: MinIO S3 (iceberg bucket)
- **Concurrency**: Supports multiple simultaneous write operations
- **Features**: Table metadata management, schema versioning, partition evolution
- **Status**: ✅ Production ready with PostgreSQL backend for high concurrency

### NATS Messaging System (Flux-managed)
- **Namespace**: nats
- **Architecture**: Single-node deployment with JetStream persistence
- **Memory**: 512Mi allocation (1Gi JetStream memory + 10Gi file storage)
- **Storage**: Longhorn-backed persistent volume for JetStream file storage
- **Client Port**: 4222 (NATS protocol)
- **Monitoring**: Prometheus metrics on port 8222
- **Features**: High-performance messaging, stream persistence, message replay
- **Use Case**: IoT sensor data ingestion and stream processing

### ClickHouse Analytics Database (Flux-managed)
- **Namespace**: clickhouse
- **Architecture**: Single-node deployment with Altinity operator
- **Memory**: 2Gi allocation (1Gi requests, 2Gi limits)
- **Storage**: Longhorn-backed persistent volume (20Gi)
- **HTTP Interface**: https://clickhouse.homelab.local (HAProxy ingress) or http://10.0.0.248:8123 (LoadBalancer)
- **Web UI**: /play (SQL editor), /dashboard (monitoring) - No authentication required
- **Native Protocol**: 10.0.0.248:9000 (LoadBalancer)
- **Monitoring**: Prometheus metrics on port 9363
- **Features**: Columnar storage, real-time analytics, high-performance OLAP
- **Use Case**: Real-time IoT data analytics and time-series processing

## Management

### Updating Configurations

**Flux-managed components** (MetalLB, HAProxy, cert-manager, Monitoring):
1. Edit manifests in this repository
2. Commit and push changes to main branch
3. Flux automatically syncs changes to the cluster (default: 1 minute interval)

**MinIO** (Helm-managed):
1. Edit configuration in minio/ directory
2. Apply changes: `cd minio && helm upgrade --install minio-tenant minio/tenant -n minio-tenant -f tenant-values.yaml`

### Manual Sync
```bash
# Flux components
flux reconcile source git flux-system
flux reconcile kustomization flux-system

# MinIO
cd minio && helm upgrade --install minio-tenant minio/tenant -n minio-tenant -f tenant-values.yaml
```

### Monitoring
```bash
# Watch Flux reconciliation
flux get all

# Check MinIO status
kubectl get tenant -n minio-tenant
kubectl get svc -n minio-tenant
```

## PostgreSQL Deployment with CNPG

### Overview
CloudNativePG (CNPG) provides enterprise-grade PostgreSQL management with automated backup, monitoring, and high availability. PostgreSQL instances are deployed co-located with applications following the homelab-foundations pattern.

### Architecture Pattern
```
clusters/um890/your-app/
├── kustomization.yaml           # Main kustomization
├── postgres-cluster.yaml       # PostgreSQL cluster (co-located)
├── postgres-secret.yaml        # Database credentials
├── deployment.yaml             # Application deployment
├── service.yaml                # Application service
└── servicemonitor.yaml         # Monitoring configuration
```

### Quick PostgreSQL Deployment

1. **Copy Templates**:
   ```bash
   # Create application directory
   mkdir -p clusters/um890/your-app

   # Copy PostgreSQL templates
   cp docs/templates/postgres-cluster-template.yaml clusters/um890/your-app/postgres-cluster.yaml
   cp docs/templates/postgres-secret-template.yaml clusters/um890/your-app/postgres-secret.yaml
   ```

2. **Customize Configuration**:
   ```bash
   # Edit postgres-cluster.yaml - replace placeholders:
   # APP_NAME → your-app
   # APP_NAMESPACE → your-app-namespace
   # APP_DATABASE → your_database
   # APP_USER → your_user
   ```

3. **Create Secure Credentials**:
   ```bash
   # Generate secure credentials (never commit to Git!)
   USERNAME="your_user"
   PASSWORD="$(openssl rand -base64 32)"

   # Create base64 encoded values
   USERNAME_B64=$(echo -n "$USERNAME" | base64)
   PASSWORD_B64=$(echo -n "$PASSWORD" | base64)

   # Update postgres-secret.yaml with base64 values
   ```

4. **Create Backup Credentials**:
   ```bash
   # Create MinIO backup credentials in your application namespace
   kubectl create secret generic minio-backup-credentials \
     --from-literal=ACCESS_KEY_ID="minio" \
     --from-literal=SECRET_ACCESS_KEY="minio123" \
     --namespace=your-app-namespace
   ```

5. **Deploy via GitOps**:
   ```bash
   # Add to main cluster kustomization
   echo "  - your-app" >> clusters/um890/kustomization.yaml

   # Commit and deploy
   git add clusters/um890/your-app/
   git commit -m "Add PostgreSQL cluster for your-app"
   git push
   ```

### Application Integration
Configure your application to connect to PostgreSQL:
```yaml
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

### Features Available
- **Automated Backups**: Continuous WAL archiving to MinIO
- **Point-in-Time Recovery**: Restore to any point in time
- **Monitoring**: Prometheus metrics and Grafana dashboards
- **High Availability**: Automated failover and recovery
- **Resource Scaling**: Adjustable CPU/memory allocation
- **Security**: TLS encryption and credential management

### Operational Commands
```bash
# Check PostgreSQL cluster status
kubectl get clusters.postgresql.cnpg.io -n your-app-namespace

# Create manual backup
kubectl apply -f - <<EOF
apiVersion: postgresql.cnpg.io/v1
kind: Backup
metadata:
  name: manual-backup
  namespace: your-app-namespace
spec:
  cluster:
    name: your-app-postgres
EOF

# Connect to database
kubectl exec -it your-app-postgres-1 -n your-app-namespace -- psql -U your_user -d your_database

# Scale to zero (saves ~500Mi memory)
kubectl patch cluster your-app-postgres -n your-app-namespace \
  --type='merge' -p='{"spec":{"instances":0}}'
```

For detailed examples, see `examples/applications/database-app/` and `clusters/um890/cnpg/README.md`.

## Security Considerations

- **Secrets**: Sensitive values should be managed via Kubernetes secrets or external secret management
- **RBAC**: Flux operates with cluster-admin privileges (review and restrict as needed)
- **Network**: Cluster is accessible only within the local network (10.0.0.0/24)
- **MinIO**: Uses self-signed certificates for HTTPS (appropriate for homelab environment)

## Troubleshooting

### Common Issues

1. **Flux not syncing**:
   ```bash
   flux logs --follow
   ```

2. **Helm release failures**:
   ```bash
   kubectl describe helmrelease <name> -n <namespace>
   ```

3. **MinIO issues**:
   ```bash
   # Check operator logs
   kubectl logs -n minio-operator deployment/minio-operator

   # Check tenant status
   kubectl describe tenant minio-tenant -n minio-tenant

   # Check Helmfile status
   cd minio && helmfile status
   ```

## Documentation

### Operational Guides
- **[Operational Runbook](docs/OPERATIONAL_RUNBOOK.md)** - Complete operations manual
- **[Quick Reference](docs/QUICK_REFERENCE.md)** - Essential commands and URLs
- **[HAProxy Ingress Guide](docs/HAPROXY_INGRESS.md)** - HAProxy ingress controller usage
- **[Pi-hole DNS Guide](docs/PIHOLE_DNS_GUIDE.md)** - Local DNS resolution for .homelab.local domains
- **[Monitoring Guide](docs/MONITORING.md)** - Prometheus + Grafana stack details
- **[Trino Guide](docs/TRINO_GUIDE.md)** - Analytics engine and Iceberg data lake usage
- **[NATS Guide](docs/NATS_GUIDE.md)** - Messaging system and JetStream for IoT data streams
- **[ClickHouse Guide](docs/CLICKHOUSE_GUIDE.md)** - Real-time analytics database for IoT data processing
- **[Temporal Guide](docs/TEMPORAL_GUIDE.md)** - Workflow orchestration platform with performance-optimized PostgreSQL backend
- **[Resource Management Guide](docs/RESOURCE_MANAGEMENT.md)** - Scaling services to zero for resource conservation
- **[Troubleshooting Guide](docs/TROUBLESHOOTING_GUIDE.md)** - Problem diagnosis and fixes

### Application Examples
- **[Application Examples](examples/README.md)** - Boilerplate for common deployment patterns
- **[Deployment Guide](examples/DEPLOYMENT_GUIDE.md)** - Step-by-step application deployment

### Setup Guides
- **[Quick Start Guide](QUICKSTART.md)** - Complete setup walkthrough
- **[Configuration Guide](CONFIGURATION.md)** - Detailed customization options
- **[Setup Guide](docs/SETUP.md)** - Advanced setup procedures
- **[Architecture](docs/ARCHITECTURE.md)** - System design and components

### External Resources
- [Flux Documentation](https://fluxcd.io/docs/)
- [MinIO Operator Documentation](https://min.io/docs/minio/kubernetes/upstream/)
- [Helmfile Documentation](https://helmfile.readthedocs.io/)
- [Longhorn Documentation](https://longhorn.io/docs/)
- [MetalLB Documentation](https://metallb.universe.tf/)
- [Trino Documentation](https://trino.io/docs/current/)
- [Apache Iceberg Documentation](https://iceberg.apache.org/docs/latest/)
- [NATS Documentation](https://docs.nats.io/)
- [JetStream Documentation](https://docs.nats.io/nats-concepts/jetstream)

## Contributing

1. Create feature branch from main
2. Make changes and test locally
3. Submit pull request for review
4. Merge to main triggers automatic deployment for Flux-managed components
5. For MinIO changes, apply manually with Helmfile

## Architecture Summary

- **Target**: Single-node Kubernetes homelab clusters
- **GitOps**: Hybrid approach - Flux for infrastructure, Helmfile for complex applications
- **Storage**: Longhorn CSI with configurable replica count
- **Networking**: MetalLB LoadBalancer with configurable IP pools
- **Ingress**: HAProxy Ingress Controller for HTTP/HTTPS routing
- **Certificates**: cert-manager for automated TLS certificate management
- **Object Storage**: MinIO with HTTPS auto-certificates
- **Monitoring**: Prometheus + Grafana with pre-configured dashboards
- **Scalability**: Designed for single-node but expandable to multi-node
