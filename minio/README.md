# MinIO Deployment with Helm

**Version**: 2.0
**Date**: 2025-07-17
**Author**: Community Contributors
**Status**: Active

## Overview

MinIO is managed separately from Flux using direct Helm commands for reliable deployment. The deployment uses HTTP-only configuration for homelab simplicity, avoiding SSL certificate complexity while maintaining full functionality.

## Prerequisites

Ensure MinIO Helm repository is added:
```bash
helm repo add minio https://operator.min.io
helm repo update
```

## Deployment

```bash
# Deploy MinIO tenant (operator must be installed separately)
cd minio/
helm upgrade --install minio-tenant minio/tenant -n minio-tenant --create-namespace -f tenant-values.yaml

# Check status
kubectl get tenant -n minio-tenant
kubectl get svc -n minio-tenant
```

## Configuration

- **Operator**: Single replica for homelab efficiency
- **Tenant**: 1 server, 300Gi Longhorn storage
- **Protocol**: HTTP-only (requestAutoCert: false)
- **Credentials**: Configurable in tenant-values.yaml

## Access

After deployment, MinIO will be available at:
- **S3 API**: `http://10.0.0.241:80` (HTTP-only)
- **Console**: `http://10.0.0.242:9090` (HTTP-only)
- **Ingress Access**:
  - S3 API: `http://minio.homelab.local`
  - Console: `http://minio-console.homelab.local`

## Updates

To update MinIO:
```bash
cd minio/
helm upgrade --install minio-tenant minio/tenant -n minio-tenant -f tenant-values.yaml
```

## Troubleshooting

```bash
# Check operator logs
kubectl logs -n minio-operator deployment/minio-operator

# Check tenant status
kubectl get tenant -n minio-tenant

# Check services
kubectl get svc -n minio-tenant
```
