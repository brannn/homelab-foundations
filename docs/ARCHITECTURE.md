# Homelab Architecture Overview

**Version**: 1.0
**Date**: 2025-07-13
**Author**: Community Contributors
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

5. **MinIO Object Storage** (Helmfile-managed)
   - **Management**: Helmfile (separate from Flux)
   - **Operator**: Manages MinIO deployments (configurable replicas)
   - **Tenant**: Actual MinIO instance (configurable servers and storage)
   - **Certificates**: Auto-generated self-signed for HTTPS
   - **Services**: S3 API and Console via MetalLB LoadBalancer
   - **Credentials**: Configurable (see minio/tenant-values.yaml)

6. **Monitoring Stack** (Flux-managed)
   - **Prometheus**: Metrics collection and storage (30-day retention)
   - **Grafana**: Dashboards and visualization via LoadBalancer
   - **Alertmanager**: Alert management and routing
   - **Node Exporter**: Host-level metrics collection
   - **Kube State Metrics**: Kubernetes object metrics
   - **Storage**: Longhorn-backed persistent volumes
   - **Dashboards**: Pre-configured for Kubernetes, nodes, and Longhorn

### Hybrid GitOps Workflow

**Flux-managed components** (MetalLB, Longhorn):
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
│   ├── longhorn/             # Storage CSI config
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
| Grafana | LoadBalancer | 3000 (HTTP) | External | Flux |
| MinIO S3 API | LoadBalancer | 443 (HTTPS) | External | Helmfile |
| MinIO Console | LoadBalancer | 9443 (HTTPS) | External | Helmfile |
| Prometheus | ClusterIP | 9090 | Internal/Grafana | Flux |
| Alertmanager | ClusterIP | 9093 | Internal | Flux |
| Longhorn UI | ClusterIP | 80 | Port-forward | Flux |
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
- **Flux**: Built-in reconciliation monitoring
- **Longhorn**: Web UI for storage monitoring
- **MinIO**: Built-in metrics endpoint

### Recommended Additions
- **Prometheus**: Metrics collection
- **Grafana**: Visualization
- **Loki**: Log aggregation
- **AlertManager**: Alerting

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

This architecture provides a robust foundation for homelab operations with a hybrid GitOps approach that balances automation with operational flexibility. The combination of Flux for infrastructure management and Helmfile for complex applications ensures reliable deployments while maintaining the benefits of GitOps practices.

The single-node design is appropriate for homelab use cases while providing a foundation for future expansion to multi-node configurations as requirements grow.
- **Network**: Router/switch updates
- **Major Upgrades**: Kubernetes version jumps
