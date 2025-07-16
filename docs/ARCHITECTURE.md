# Homelab Architecture Overview

**Version**: 1.2
**Date**: 2025-07-15
**Author**: Community Contributors (with Augment Agent)
**Status**: Active

## Overview

This document describes the architecture for single-node Kubernetes homelab clusters using GitOps principles. The system uses a hybrid approach combining Flux CD for core infrastructure management and Helmfile for complex multi-component applications.

## Infrastructure Summary

**Target Hardware**: Single-node systems (4+ cores, 8+ GB RAM recommended)
**OS**: Any Kubernetes-compatible Linux distribution
**Network**: Configurable private network ranges
**Kubernetes**: Single-node cluster with optional expansion to multi-node
**GitOps**: Hybrid - Flux CD + Helmfile

## Network Architecture

```
Internet
    |
    v
Home Router (10.0.0.1)
    |
    v
Homelab Node (10.0.0.79)
    |
    v
Kubernetes Cluster
    |
    v
MetalLB LoadBalancer Pool
(10.0.0.240 - 10.0.0.250)
```

## Component Architecture

### Core Infrastructure

1. **Kubernetes Cluster**
   - Single-node deployment
   - Managed via kubeconfig at ~/.kube/homelab

2. **MetalLB Load Balancer**
   - IP Pool: 10.0.0.240-10.0.0.250 (configurable for your network)
   - L2 Advertisement mode
   - Provides LoadBalancer services for applications

3. **Longhorn Storage**
   - Distributed storage for single-node
   - Default storage class: `longhorn`
   - Data path: `/var/lib/longhorn/`
   - Replica count: 1 (single node)

4. **cert-manager**
   - Automated TLS certificate management
   - Let's Encrypt integration with ClusterIssuer
   - Ready for ingress and service TLS termination

5. **HAProxy Ingress Controller**
   - High-performance ingress controller for HTTP/HTTPS traffic
   - LoadBalancer service via MetalLB for external access
   - Alternative to default Traefik for production workloads
   - Supports advanced routing, SSL termination, and load balancing

6. **MinIO Object Storage** (Helmfile-managed)
   - **Management**: Helmfile (separate from Flux)
   - **Operator**: Manages MinIO deployments (configurable replicas)
   - **Tenant**: Actual MinIO instance (configurable servers and storage)
   - **Certificates**: Auto-generated self-signed for HTTPS
   - **Services**: S3 API and Console via MetalLB LoadBalancer
   - **Credentials**: Configurable (see minio/tenant-values.yaml)

7. **Monitoring Stack** (Flux-managed)
   - **Prometheus**: Metrics collection and storage (30-day retention)
   - **Grafana**: Dashboards and visualization via LoadBalancer
   - **Alertmanager**: Alert management and routing
   - **Node Exporter**: Host-level metrics collection
   - **Kube State Metrics**: Kubernetes object metrics
   - **Storage**: Longhorn-backed persistent volumes
   - **Dashboards**: Pre-configured for Kubernetes, nodes, and Longhorn

8. **Analytics Engine** (Flux-managed)
   - **Trino**: Distributed SQL query engine (1 coordinator + 1 worker)
   - **Memory Allocation**: 10Gi total (4Gi coordinator, 6Gi worker)
   - **Catalogs**: Iceberg, Memory, TPC-H, TPC-DS
   - **Web UI**: LoadBalancer access on port 8080 (no authentication)
   - **Integration**: Direct connection to MinIO S3 via Iceberg REST catalog

9. **Data Lake** (Flux-managed)
   - **Iceberg REST Catalog**: ACID transactions and schema evolution
   - **Memory**: 512Mi allocation
   - **Storage Backend**: MinIO S3 (iceberg bucket)
   - **Features**: Table metadata management, time travel queries
   - **API**: LoadBalancer access on port 8181

10. **Messaging System** (Flux-managed)
    - **NATS**: High-performance messaging server
    - **JetStream**: Persistent message streaming (1Gi memory + 10Gi file storage)
    - **Storage**: Longhorn-backed persistent volume
    - **Use Case**: IoT sensor data ingestion and stream processing
    - **Monitoring**: Prometheus metrics integration

11. **Analytics Database** (Flux-managed)
    - **ClickHouse**: Columnar database for real-time analytics
    - **Memory**: 2Gi allocation (1Gi requests, 2Gi limits)
    - **Storage**: Longhorn-backed persistent volume (20Gi)
    - **Operator**: Altinity ClickHouse Operator v0.25.0
    - **Use Case**: Real-time IoT data analytics and time-series processing
    - **Monitoring**: Prometheus metrics integration

### Hybrid GitOps Workflow

**Flux-managed components** (MetalLB, HAProxy, cert-manager, Monitoring):
```
Developer
    |
    v (git push)
GitHub Repository
    |
    v (webhook/polling)
Flux CD
    |
    v (kubectl apply)
Kubernetes Cluster
```

**Helmfile-managed components** (MinIO):
```
Developer
    |
    v (git push + manual apply)
GitHub Repository
    |
    v (helmfile apply)
Helmfile
    |
    v (helm install/upgrade)
Kubernetes Cluster
```

## Directory Structure Mapping

```
homelab-foundations/
├── clusters/um890/           # Flux-managed cluster configs
│   ├── flux-system/          # Flux bootstrap files
│   ├── namespaces.yaml       # Namespace definitions
│   ├── metallb/              # Load balancer config
│   ├── cert-manager/         # TLS certificate management
│   ├── haproxy-ingress/      # HAProxy ingress controller
│   ├── dns/                  # Pi-hole DNS server for .homelab.local resolution
│   ├── monitoring/           # Prometheus, Grafana, Alertmanager
│   ├── trino/                # Trino analytics engine + Iceberg REST catalog
│   ├── nats/                 # NATS messaging system with JetStream
│   ├── clickhouse/           # ClickHouse analytics database
│   └── kustomization.yaml    # Main orchestration
├── infrastructure/
│   └── helm-repositories/    # Helm repo definitions
├── minio/                    # Helmfile-managed MinIO
│   ├── helmfile.yaml         # MinIO deployment definition
│   ├── tenant-values.yaml    # MinIO configuration
│   └── README.md             # MinIO documentation
└── docs/                     # Documentation
```

## Service Endpoints

| Service | Type | Port | Access | Management |
|---------|------|------|--------|------------|
| HAProxy Ingress | LoadBalancer | 80/443 (HTTP/HTTPS) | External | Flux |
| Grafana | LoadBalancer | 3000 (HTTP) | External | Flux |
| MinIO S3 API | LoadBalancer | 443 (HTTPS) | External | Helmfile |
| MinIO Console | LoadBalancer | 9443 (HTTPS) | External | Helmfile |
| Longhorn UI | LoadBalancer | 80 (HTTP) | External | K3s ServiceLB |
| Traefik (K3s) | LoadBalancer | 80/443 (HTTP/HTTPS) | External | K3s Default |
| Trino Web UI | LoadBalancer | 8080 (HTTP) | External | Flux |
| Iceberg REST API | LoadBalancer | 8181 (HTTP) | External | Flux |
| NATS Server | ClusterIP | 4222 (NATS) | Internal | Flux |
| NATS Monitoring | ClusterIP | 8222 (HTTP) | Internal/Prometheus | Flux |
| ClickHouse HTTP | LoadBalancer | 8123 (HTTP) | External | Flux |
| ClickHouse Ingress | Ingress | 80/443 (HTTP/HTTPS) | External | Flux |
| ClickHouse Web UI | LoadBalancer/Ingress | /play, /dashboard | External | Flux |
| ClickHouse Native | LoadBalancer | 9000 (TCP) | External | Flux |
| ClickHouse Metrics | LoadBalancer | 9363 (HTTP) | External/Prometheus | Flux |
| Prometheus | ClusterIP | 9090 | Internal/Grafana | Flux |
| Alertmanager | ClusterIP | 9093 | Internal | Flux |
| Kubernetes API | - | 6443 | kubectl | - |

## Data Flow

### Storage
```
Application Pod
    |
    v (PVC)
Longhorn CSI
    |
    v (Local Storage)
UM890Pro Disk
```

### Object Storage
```
Application
    |
    v (S3 API)
MinIO Tenant
    |
    v (PVC)
Longhorn Storage
    |
    v (Local Disk)
UM890Pro
```

### Analytics Pipeline
```
IoT Sensors
    |
    v (NATS Protocol)
NATS + JetStream
    |
    +-- v (Real-time Stream) --> ClickHouse (Real-time Analytics)
    |
    v (Stream Processing)
Analytics Application
    |
    v (SQL Queries)
Trino Coordinator
    |
    v (Iceberg REST API)
Iceberg REST Catalog
    |
    v (S3 API)
MinIO Storage
```

### Data Lake Architecture
```
Raw Data (NATS Streams)
    |
    +-- v (Real-time) --> ClickHouse --> Grafana (Real-time Dashboards)
    |
    v (ETL Process)
Iceberg Tables (MinIO S3)
    |
    v (SQL Analytics)
Trino Query Engine
    |
    v (Visualization)
Grafana Dashboards (Historical Analysis)
```

### Hybrid GitOps
**Flux-managed components**:
```
Git Commit
    |
    v (Flux Sync)
Kustomization
    |
    v (Helm/Kubectl)
Kubernetes Resources
```

**Helmfile-managed components**:
```
Git Commit
    |
    v (Manual Apply)
Helmfile
    |
    v (Helm Install/Upgrade)
Kubernetes Resources
```

## Security Model

### Network Security
- **Cluster**: Internal network only (10.0.0.0/24)
- **LoadBalancer**: Exposes services on local network
- **SSH Access**: Key-based authentication

### Kubernetes Security
- **RBAC**: Flux operates with cluster-admin (review needed)
- **Pod Security**: Security contexts defined for MinIO
- **Secrets**: Kubernetes secrets for credentials

### GitOps Security
- **Repository**: Private GitHub repository
- **Deploy Key**: Read-only access for Flux
- **Credentials**: Stored as Kubernetes secrets

## Scalability Considerations

### Current Limitations
- **Single Node**: No high availability
- **Storage**: Limited by single disk
- **Network**: Single point of failure

### Future Expansion
- **Multi-node**: Add worker nodes
- **Storage**: External storage backends
- **Networking**: Ingress controllers, external DNS

## Monitoring & Observability

### Current State
- **Prometheus**: Metrics collection and storage (30-day retention)
- **Grafana**: Dashboards and visualization (accessible via LoadBalancer)
- **Alertmanager**: Alert management and routing
- **Node Exporter**: Host-level metrics collection
- **Kube State Metrics**: Kubernetes object metrics
- **Flux**: Built-in reconciliation monitoring
- **Longhorn**: Web UI for storage monitoring
- **MinIO**: Built-in metrics endpoint
- **Trino**: JMX metrics exported to Prometheus
- **NATS**: Built-in metrics endpoint and Prometheus exporter
- **ClickHouse**: Built-in metrics endpoint and Prometheus integration
- **Iceberg REST Catalog**: Application metrics and health checks

### Recommended Additions
- **Loki**: Log aggregation
- **Jaeger**: Distributed tracing
- **Blackbox Exporter**: Endpoint monitoring

## Backup Strategy

### Current
- **Longhorn**: Snapshot capabilities
- **MinIO**: Object versioning
- **Git**: Configuration backup

### Recommended
- **Longhorn**: External backup targets
- **MinIO**: Cross-region replication
- **Cluster**: etcd snapshots
- **Application**: Database backups

## Disaster Recovery

### Recovery Scenarios
1. **Pod Failure**: Kubernetes auto-restart
2. **Node Failure**: Manual intervention required
3. **Storage Failure**: Longhorn recovery procedures
4. **Complete Loss**: Rebuild from Git + backups

### Recovery Procedures
1. **Restore Hardware**: Reinstall OS and Kubernetes
2. **Bootstrap Flux**: Re-run flux bootstrap
3. **Restore Data**: From Longhorn/MinIO backups
4. **Verify Services**: Test all components

## Performance Characteristics

### Expected Performance
- **Storage**: Limited by single disk IOPS
- **Network**: Gigabit Ethernet
- **Compute**: Ryzen 9 performance
- **Memory**: 64GB available

### Bottlenecks
- **Disk I/O**: Single storage device
- **Network**: Single NIC
- **CPU**: Shared across all workloads

## Maintenance Windows

### Regular Maintenance
- **OS Updates**: SuSE Tumbleweed rolling
- **Kubernetes**: Version upgrades
- **Applications**: Helm chart updates

### Planned Downtime
- **Hardware**: Physical maintenance
- **OS**: Major version upgrades
- **Kubernetes**: Cluster upgrades

## Conclusion

This architecture provides a comprehensive data engineering platform for homelab operations, combining traditional infrastructure management with modern analytics capabilities. The hybrid GitOps approach balances automation with operational flexibility, while the integrated analytics stack enables end-to-end data processing from IoT ingestion to visualization.

**Key Capabilities:**
- **Foundation**: Robust storage (Longhorn) and object storage (MinIO) with GitOps management
- **Networking**: MetalLB LoadBalancer services with HAProxy ingress for external access
- **Analytics**: Complete data lake architecture with Trino SQL engine and Iceberg ACID tables
- **Messaging**: High-performance NATS + JetStream for IoT data streams and event processing
- **Observability**: Comprehensive monitoring with Prometheus, Grafana, and integrated metrics

The single-node design is appropriate for homelab use cases while providing enterprise-grade patterns that can scale to multi-node configurations as requirements grow. The architecture supports modern data engineering workflows including stream processing, data lake analytics, and real-time monitoring.
- **Network**: Router/switch updates
- **Major Upgrades**: Kubernetes version jumps
