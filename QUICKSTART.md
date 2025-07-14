# Homelab Foundations - Quick Start Guide

**Version**: 1.0  
**Date**: 2025-07-13  
**Author**: Community Contributors  
**Status**: Active

## Overview

This guide will get you from zero to a fully functional GitOps-managed homelab in under 30 minutes. You'll have Kubernetes with Flux, MetalLB load balancing, Longhorn storage, MinIO object storage, and comprehensive monitoring with Prometheus + Grafana all running and managed via GitOps.

## Prerequisites

### Hardware Requirements
- **Minimum**: 2 CPU cores, 4GB RAM, 50GB storage
- **Recommended**: 4+ CPU cores, 8GB+ RAM, 100GB+ storage
- **Network**: Static IP address on your home network

### Software Requirements
- **Kubernetes cluster** (single-node is fine)
- **kubectl** configured and working
- **Git** installed
- **GitHub account** (free tier is sufficient)

### Tools to Install

```bash
# Install Flux CLI
curl -s https://fluxcd.io/install.sh | sudo bash

# Install Helmfile
brew install helmfile  # macOS
# OR download from: https://github.com/helmfile/helmfile/releases

# Verify installations
flux --version
helmfile --version
kubectl version --client
```

## Step 1: Fork and Customize

### 1.1 Fork the Repository
1. Go to https://github.com/YOUR_USERNAME/homelab-foundations
2. Click "Fork" to create your own copy
3. Clone your fork locally:
```bash
git clone https://github.com/YOUR_USERNAME/homelab-foundations.git
cd homelab-foundations
```

### 1.2 Customize for Your Network
Edit `clusters/um890/metallb/metallb.yaml`:
```yaml
spec:
  addresses:
    - 10.0.0.240-10.0.0.250  # Change to match your network
```

Common network ranges:
- `192.168.1.240-250` for most home routers
- `192.168.0.240-250` for some routers
- `10.0.0.240-250` for advanced setups

### 1.3 Customize MinIO Credentials
Edit `minio/tenant-values.yaml`:
```yaml
configSecret:
  accessKey: minio      # Change this
  secretKey: minio123   # Change this to something secure
```

### 1.4 Adjust Resource Limits (Optional)
In `minio/tenant-values.yaml`, adjust based on your hardware:
```yaml
resources:
  requests:
    cpu: "500m"     # For lower-end hardware
    memory: "1Gi"   # For lower-end hardware
  limits:
    cpu: "1000m"    # For lower-end hardware  
    memory: "2Gi"   # For lower-end hardware
```

## Step 2: Deploy the Foundation

### 2.1 Bootstrap Flux
```bash
# Set your GitHub details
export GITHUB_USER=YOUR_USERNAME
export GITHUB_REPO=homelab-foundations

# Bootstrap Flux (this sets up GitOps)
flux bootstrap github \
  --owner=$GITHUB_USER \
  --repository=$GITHUB_REPO \
  --branch=main \
  --path=./clusters/um890 \
  --personal
```

### 2.2 Wait for Infrastructure Deployment
```bash
# Watch Flux deploy the infrastructure
flux get all

# Wait for all components to be ready (2-5 minutes)
kubectl get pods -A
```

You should see pods running in:
- `flux-system` (GitOps controller)
- `metallb-system` (Load balancer)
- `longhorn-system` (Storage)
- `cert-manager` (Certificate management)
- `monitoring` (Prometheus + Grafana)

### 2.3 Deploy MinIO
```bash
# Deploy MinIO using Helmfile
cd minio/
helmfile apply

# Check MinIO status
kubectl get tenant -n minio-tenant
kubectl get pods -n minio-tenant
```

## Step 3: Verify Everything Works

### 3.1 Check Service IPs
```bash
kubectl get svc -A | grep LoadBalancer
```

You should see MinIO services with external IPs from your MetalLB range.

### 3.2 Access MinIO Console
1. Find the console IP: `kubectl get svc minio-tenant-console -n minio-tenant`
2. Open browser to: `https://CONSOLE_IP:9443`
3. Login with your credentials (default: minio/minio123)
4. Accept the self-signed certificate warning

### 3.3 Access Grafana Dashboard
1. Find the Grafana IP: `kubectl get svc grafana -n monitoring`
2. Open browser to: `http://GRAFANA_IP:3000`
3. Login with: admin/grafana123
4. Explore pre-configured dashboards for Kubernetes, nodes, and storage

### 3.4 Access Longhorn UI
```bash
# Port-forward to access Longhorn
kubectl port-forward -n longhorn-system svc/longhorn-frontend 8080:80
```
Open browser to: `http://localhost:8080`

## Step 4: Test GitOps Workflow

### 4.1 Make a Change
Edit any file in the repository (try changing a comment):
```bash
# Edit a file
echo "# Test change" >> clusters/um890/kustomization.yaml

# Commit and push
git add .
git commit -m "Test GitOps workflow"
git push origin main
```

### 4.2 Watch Flux Sync
```bash
# Force immediate sync (optional)
flux reconcile source git flux-system

# Watch the reconciliation
flux get all
```

## What You Now Have

### Infrastructure
- **Kubernetes cluster** with GitOps management
- **MetalLB** providing LoadBalancer services
- **Longhorn** providing persistent storage
- **cert-manager** providing TLS certificate management
- **MinIO** providing S3-compatible object storage
- **Prometheus + Grafana** providing comprehensive monitoring

### GitOps Workflow
- **Flux** automatically syncs infrastructure changes from Git
- **Helmfile** manages complex applications like MinIO
- **All configuration** stored in Git for version control

### Access Points
- **MinIO Console**: Web UI for object storage management
- **MinIO S3 API**: S3-compatible API for applications
- **Grafana**: Monitoring dashboards and metrics visualization
- **Longhorn UI**: Storage management interface
- **Kubernetes API**: Full cluster management via kubectl

## Next Steps

### Expand Your Homelab
- Add monitoring with Prometheus/Grafana
- Deploy applications using the same GitOps patterns
- Set up ingress controllers for web services
- Add backup solutions for critical data

### Learn More
- Read the full documentation in `docs/`
- Check `docs/QUICK_REFERENCE.md` for common commands
- Review `docs/ARCHITECTURE.md` for system design details

### Get Help
- Check existing issues on GitHub
- Create new issues for bugs or questions
- Join the homelab community discussions

## Troubleshooting

### Common Issues

**Flux not syncing:**
```bash
flux logs --follow
flux reconcile source git flux-system
```

**MinIO not starting:**
```bash
kubectl logs -n minio-operator deployment/minio-operator
kubectl describe tenant minio-tenant -n minio-tenant
```

**No LoadBalancer IPs:**
```bash
kubectl logs -n metallb-system deployment/controller
kubectl get ipaddresspool -n metallb-system
```

### Getting Support
1. Check the logs using commands above
2. Review the documentation in `docs/`
3. Search existing GitHub issues
4. Create a new issue with detailed information

Congratulations! You now have a production-ready homelab with GitOps management!
