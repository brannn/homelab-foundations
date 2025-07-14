# Longhorn Storage Foundation

**Version**: 1.0  
**Date**: 2025-07-14  
**Author**: Community Contributors  
**Status**: Active

## Overview

Longhorn provides persistent storage for the homelab cluster and is managed independently of Flux to ensure storage is always available as a foundation component.

## Architecture Decision

Longhorn is managed via **Helmfile** (not Flux) because:
- **Storage First**: Storage must be available before GitOps can function
- **Bootstrap Independence**: Avoids chicken-and-egg problems with Flux
- **Foundation Component**: Core infrastructure that other services depend on
- **Stability**: Reduces complexity in the GitOps dependency chain

## Configuration

### Storage Path
- **Data Path**: `/mnt/data/longhorn/` (dedicated NVMe storage)
- **Replica Count**: 1 (single-node cluster)
- **Storage Class**: `longhorn` (default)

### Access
- **UI**: LoadBalancer service via MetalLB
- **API**: Internal cluster access for CSI operations

## Deployment

### Prerequisites
1. Kubernetes cluster running
2. MetalLB configured and operational
3. Dedicated storage mounted at `/mnt/data`

### Install
```bash
cd longhorn/
helmfile apply
```

### Verify
```bash
kubectl get pods -n longhorn-system
kubectl get storageclass
kubectl get pv
```

### Access UI
```bash
kubectl get svc -n longhorn-system longhorn-frontend
# Access via LoadBalancer IP
```

## Maintenance

### Upgrade
```bash
cd longhorn/
helmfile diff  # Review changes
helmfile apply
```

### Backup Configuration
The Helmfile and values are stored in Git, providing configuration backup and version control.

### Troubleshooting
```bash
# Check Longhorn status
kubectl get pods -n longhorn-system
kubectl logs -n longhorn-system deployment/longhorn-manager

# Check storage
kubectl get pv
kubectl get pvc -A

# Check nodes
kubectl get nodes -o wide
```

## Integration

### With Flux
- Longhorn provides storage that Flux applications can use
- Flux does NOT manage Longhorn (intentional separation)
- Applications deployed by Flux can use `storageClassName: longhorn`

### With Applications
```yaml
# Example PVC using Longhorn
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-storage
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn
  resources:
    requests:
      storage: 10Gi
```

This foundation approach ensures reliable, persistent storage for all cluster workloads.
