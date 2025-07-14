# Homelab Foundations - Quick Reference

**Version**: 1.1
**Date**: 2025-07-14
**Author**: Community Contributors
**Status**: Active

## Overview

Quick reference guide for common operations and access information for the homelab Kubernetes cluster.

## Essential Commands

### Cluster Access
```bash
export KUBECONFIG=~/.kube/homelab
kubectl cluster-info
```

### Service URLs
- **HAProxy Ingress**: http://10.0.0.244 (HTTP/HTTPS ingress controller)
- **Grafana**: http://10.0.0.245:3000 (admin/grafana123)
- **MinIO Console**: https://10.0.0.242:9443 (minio/minio123)
- **MinIO S3 API**: https://10.0.0.241:443
- **Longhorn UI**: http://10.0.0.243 (via LoadBalancer)
- **Traefik (K3s)**: http://10.0.0.240 (default K3s ingress)

### Hybrid GitOps Workflow

**Flux-managed components** (MetalLB, HAProxy, cert-manager, Monitoring):
```bash
# Make changes, then:
git add .
git commit -m "description"
git push origin main

# Force sync if needed:
flux reconcile source git flux-system
```

**MinIO** (Helmfile-managed):
```bash
# Edit files in minio/ directory, then:
cd minio/
helmfile apply
```

### Check System Status
```bash
# Flux status
flux get all

# All pods
kubectl get pods -A

# Services with external IPs
kubectl get svc -A | grep LoadBalancer

# Storage health
kubectl get volumes -n longhorn-system

# MinIO status
cd minio && helmfile status
kubectl get tenant -n minio-tenant

# Monitoring status
kubectl get pods -n monitoring
kubectl get svc -n monitoring

# cert-manager status
kubectl get pods -n cert-manager
kubectl get clusterissuers

# HAProxy ingress status
kubectl get pods -n haproxy-controller
kubectl get svc -n haproxy-controller
```

## Common Fixes

### Volume Degraded (Single Node)
```bash
kubectl patch volume <volume-name> -n longhorn-system \
  --type='merge' -p='{"spec":{"numberOfReplicas":1}}'
```

### Force Flux Sync
```bash
flux reconcile source git flux-system
flux reconcile kustomization flux-system
```

### MinIO Issues
```bash
# Redeploy MinIO
cd minio && helmfile apply

# Check operator logs
kubectl logs -n minio-operator deployment/minio-operator

# Check tenant logs
kubectl logs -n minio-tenant minio-tenant-pool-0-0 -c minio
```

### Check Logs
```bash
# Flux logs
flux logs --follow

# Pod logs
kubectl logs <pod-name> -n <namespace>

# Previous pod logs
kubectl logs <pod-name> -n <namespace> --previous
```

## Monitoring

### Resource Usage
```bash
kubectl top nodes
kubectl top pods -A
```

### Storage Status
```bash
# Longhorn volumes
kubectl get volumes -n longhorn-system

# PVCs across all namespaces
kubectl get pvc -A

# Storage classes
kubectl get storageclass
```

### Network Status
```bash
# MetalLB status
kubectl get pods -n metallb-system

# IP address pools
kubectl get ipaddresspool -n metallb-system

# LoadBalancer services
kubectl get svc -A --field-selector spec.type=LoadBalancer
```

## Emergency Commands

### Restart Flux
```bash
kubectl rollout restart deployment -n flux-system
```

### Restart Longhorn
```bash
kubectl rollout restart deployment longhorn-ui -n longhorn-system
kubectl rollout restart daemonset longhorn-manager -n longhorn-system
```

### Restart MinIO
```bash
# Restart operator
kubectl rollout restart deployment minio-operator -n minio-operator

# Restart tenant
kubectl delete pod minio-tenant-pool-0-0 -n minio-tenant
```

### Redeploy MinIO
```bash
cd minio/
helmfile apply
```

## File Locations

### Local Files
- **Kubeconfig**: `~/.kube/homelab`
- **SSH Key**: `~/.ssh/github_stylograph`
- **Repository**: `/Users/bran/PycharmProjects/homelab-foundations`

### Important Configs
- **Flux System**: `clusters/um890/flux-system/`
- **MetalLB**: `clusters/um890/metallb/`
- **HAProxy Ingress**: `clusters/um890/haproxy-ingress/`
- **cert-manager**: `clusters/um890/cert-manager/`
- **Monitoring**: `clusters/um890/monitoring/`
- **Longhorn**: `longhorn/` (Helmfile-managed)
- **MinIO**: `minio/` (Helmfile-managed)

## When Things Break

1. **Check Flux first**: `flux get all`
2. **Check pod status**: `kubectl get pods -A`
3. **Check MinIO**: `cd minio && helmfile status`
4. **Check recent changes**: `git log --oneline -10`
5. **Check logs**: `flux logs --follow`
6. **Rollback if needed**: `git revert <commit>`

## Resources

- **Documentation**: `docs/` directory in repository
- **Architecture**: `docs/ARCHITECTURE.md`
- **Setup Guide**: `docs/SETUP.md`
- **Full Runbook**: `docs/OPERATIONAL_RUNBOOK.md`
