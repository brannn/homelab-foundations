# Homelab Foundations

**Version**: 1.0
**Date**: 2025-07-13
**Author**: Community Contributors
**Status**: Active

## Overview

This repository provides a complete GitOps foundation for single-node Kubernetes homelab clusters. The infrastructure uses a hybrid approach with Flux CD for core components and Helmfile for complex multi-component applications, providing a robust and maintainable homelab setup.

## Infrastructure Components

- **Kubernetes**: Single-node cluster (assumes K3s)
- **GitOps**: Flux CD for continuous deployment
- **Load Balancer**: MetalLB with configurable IP ranges
- **Storage**: Longhorn CSI for persistent volumes
- **Object Storage**: MinIO managed via Helmfile
- **Monitoring**: Prometheus + Grafana stack with pre-configured dashboards

## Repository Structure

```
homelab-foundations/
├── clusters/
│   └── um890/                    # Cluster-specific configurations
│       ├── flux-system/          # Flux bootstrap manifests
│       ├── namespaces.yaml       # Namespace definitions
│       ├── metallb/              # MetalLB configuration
│       ├── longhorn/             # Longhorn Helm release
│       ├── monitoring/           # Prometheus + Grafana stack
│       └── kustomization.yaml    # Main cluster kustomization
├── infrastructure/
│   └── helm-repositories/        # Helm repository definitions
├── minio/                        # MinIO managed via Helmfile
│   ├── helmfile.yaml            # MinIO operator + tenant deployment
│   ├── tenant-values.yaml       # MinIO tenant configuration
│   └── README.md                 # MinIO-specific documentation
├── docs/                         # Documentation
└── README.md                     # This file
```

## Getting Started

**New to this project?** Start with the **[Quick Start Guide](QUICKSTART.md)** for a complete walkthrough from zero to running homelab in 30 minutes.

### Quick Overview

1. **Fork this repository** to your GitHub account
2. **Customize** network ranges and credentials for your environment
3. **Bootstrap Flux** to enable GitOps management
4. **Deploy MinIO** using Helmfile for object storage
5. **Enjoy** your fully automated homelab infrastructure!

### Key Files to Customize

- `clusters/um890/metallb/metallb.yaml` - Update IP ranges for your network
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

### MinIO (Helmfile-managed)
- **Management**: Helmfile (not Flux)
- **Operator Namespace**: minio-operator
- **Tenant Namespace**: minio-tenant
- **Tenant Name**: minio-tenant
- **Storage**: Configurable size (default: 300Gi per pool)
- **Certificates**: Auto-generated self-signed for HTTPS
- **Access**: S3 API and Console via MetalLB LoadBalancer
- **Credentials**: Configurable (see minio/tenant-values.yaml)

### Monitoring (Flux-managed)
- **Namespace**: monitoring
- **Prometheus**: Metrics collection and storage (30-day retention)
- **Grafana**: Dashboards and visualization (admin/grafana123)
- **Node Exporter**: Host-level metrics
- **Kube State Metrics**: Kubernetes object metrics
- **Storage**: Longhorn-backed persistent volumes
- **Dashboards**: Pre-configured for Kubernetes, nodes, and Longhorn
- **Note**: Dashboard compatibility varies by Kubernetes distribution; customization may be required

## Management

### Updating Configurations

**Flux-managed components** (MetalLB, Longhorn):
1. Edit manifests in this repository
2. Commit and push changes to main branch
3. Flux automatically syncs changes to the cluster (default: 1 minute interval)

**MinIO** (Helmfile-managed):
1. Edit configuration in minio/ directory
2. Apply changes: `cd minio && helmfile apply`

### Manual Sync
```bash
# Flux components
flux reconcile source git flux-system
flux reconcile kustomization flux-system

# MinIO
cd minio && helmfile apply
```

### Monitoring
```bash
# Watch Flux reconciliation
flux get all

# Check MinIO status
helmfile status
kubectl get tenant -n minio-tenant
```

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
- **[Monitoring Guide](docs/MONITORING.md)** - Prometheus + Grafana stack details
- **[Troubleshooting Guide](docs/TROUBLESHOOTING_GUIDE.md)** - Problem diagnosis and fixes

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
- **Object Storage**: MinIO with HTTPS auto-certificates
- **Monitoring**: Prometheus + Grafana with pre-configured dashboards
- **Scalability**: Designed for single-node but expandable to multi-node
