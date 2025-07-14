# Homelab Setup Guide

**Version**: 1.0
**Date**: 2025-07-13
**Author**: Community Contributors
**Status**: Active

## Overview

This guide covers the initial setup of the homelab Kubernetes cluster and hybrid GitOps implementation using Flux for infrastructure and Helmfile for complex applications.

### 1. Cluster Access

Ensure you can access your cluster:

```bash
# Set kubeconfig
export KUBECONFIG=~/.kube/homelab

# Test connectivity
kubectl cluster-info
kubectl get nodes
```

### 2. Install Flux CLI

```bash
# Install Flux CLI
curl -s https://fluxcd.io/install.sh | sudo bash

# Verify installation
flux --version
```

### 3. GitHub Repository Setup

This repository should be private and accessible via your GitHub account.

### 4. Bootstrap Flux

**Important**: Run this only once during initial setup!

```bash
# Bootstrap Flux to your cluster
flux bootstrap github \
  --owner=brannn \
  --repository=homelab-foundations \
  --branch=main \
  --path=./clusters/um890 \
  --personal \
  --private=true
```

This command will:
- Install Flux components in your cluster
- Create a deploy key for the repository
- Set up GitOps synchronization
- Generate `gotk-components.yaml` and `gotk-sync.yaml` in the flux-system directory

### 5. Verify Installation

```bash
# Check Flux system pods
kubectl get pods -n flux-system

# Check Flux status
flux get all

# Monitor reconciliation
flux logs --follow
```

### 6. Component Verification

After Flux is running, verify each component:

```bash
# Check namespaces
kubectl get namespaces

# Check MetalLB
kubectl get pods -n metallb-system
kubectl get ipaddresspool -n metallb-system

# Check Longhorn
kubectl get pods -n longhorn-system
kubectl get storageclass

# Check MinIO Operator
kubectl get pods -n minio-operator

# Check MinIO Tenant
kubectl get tenant -n minio-tenant
kubectl get pods -n minio-tenant
```

## Accessing Services

### MinIO Console

1. Get the LoadBalancer IP:
   ```bash
   kubectl get svc -n minio-tenant
   ```

2. Access the console at `https://<LOADBALANCER-IP>:9443`

3. Default credentials (change these!):
   - Username: `minio`
   - Password: `minio123`

### Longhorn UI

1. Port-forward to access:
   ```bash
   kubectl port-forward -n longhorn-system svc/longhorn-frontend 8080:80
   ```

2. Access at `http://localhost:8080`

## Security Hardening

### 1. Change MinIO Credentials

Update the MinIO tenant values to use proper secrets:

```yaml
# In clusters/um890/minio-tenant/minio-tenant-values.yaml
configSecret:
  name: minio-tenant-env-configuration
  accessKey: your-secure-username
  secretKey: your-secure-password
```

### 2. Enable TLS

Consider enabling TLS for all services in production.

### 3. Network Policies

Implement Kubernetes Network Policies to restrict inter-pod communication.

## Troubleshooting

### Flux Issues

```bash
# Check Flux logs
flux logs --follow

# Force reconciliation
flux reconcile source git flux-system
flux reconcile kustomization flux-system
```

### Component Issues

```bash
# Check specific HelmRelease
kubectl describe helmrelease <name> -n <namespace>

# Check Helm release status
helm list -A

# Check pod logs
kubectl logs -n <namespace> <pod-name>
```

### Storage Issues

```bash
# Check Longhorn status
kubectl get volumes -n longhorn-system
kubectl get engines -n longhorn-system

# Check PVC status
kubectl get pvc -A
```

## Maintenance

### Updating Components

1. Update version constraints in HelmRelease manifests
2. Commit changes to Git
3. Flux will automatically apply updates

### Backup Strategy

1. **Longhorn**: Configure automated backups to external storage
2. **MinIO**: Set up bucket replication or backup policies
3. **Cluster State**: Regular etcd backups (if using K3s, snapshots are automatic)

### Monitoring

Consider adding:
- Prometheus + Grafana for metrics
- Loki for log aggregation
- AlertManager for notifications
