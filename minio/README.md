# MinIO Deployment with Helmfile

**Version**: 1.0
**Date**: 2025-07-13
**Author**: Community Contributors
**Status**: Active

## Overview

MinIO is managed separately from Flux using Helmfile due to its complex multi-component architecture (operator + tenant CRDs) that requires careful dependency ordering. This approach provides reliable deployment while maintaining GitOps principles.

## Prerequisites

Install Helmfile:
```bash
# macOS
brew install helmfile

# Linux
curl -L https://github.com/helmfile/helmfile/releases/latest/download/helmfile_linux_amd64.tar.gz | tar xz
sudo mv helmfile /usr/local/bin/
```

## Deployment

```bash
# Deploy MinIO (operator + tenant)
cd minio/
helmfile apply

# Check status
helmfile status
```

## Configuration

- **Operator**: Single replica for homelab efficiency
- **Tenant**: 1 server, 300Gi Longhorn storage
- **Certificates**: Auto-generated self-signed for HTTPS console
- **Credentials**: minio / minio123

## Access

After deployment, MinIO will be available at:
- **S3 API**: `http://10.0.0.242:80` (or port assigned by MetalLB)
- **Console**: `https://10.0.0.243:9090` (HTTPS with self-signed cert)

## Updates

To update MinIO:
```bash
cd minio/
helmfile apply
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
