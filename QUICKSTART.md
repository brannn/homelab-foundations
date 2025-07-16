# Homelab Foundations - Quick Start Guide

**Version**: 1.0  
**Date**: 2025-07-14
**Author**: Community Contributors  
**Status**: Active

## Overview

This guide will get you from zero to a fully functional homelab in under 30 minutes. You'll have Kubernetes with foundation storage (Longhorn CSI + MinIO), GitOps management (Flux), MetalLB load balancing, HAProxy ingress, Pi-hole DNS for local hostname resolution, comprehensive monitoring with Prometheus + Grafana, analytics with Trino + Iceberg, real-time analytics with ClickHouse, and IoT messaging with NATS + JetStream.

**Architecture**: Core storage components are managed via Helmfile for high availability, while other services use GitOps (Flux) for automated deployment and management.

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

## Step 2: Deploy Foundation Storage

**Foundation components are deployed first using Helmfile to ensure storage is available before GitOps takes over.**

### 2.1 Deploy Longhorn Storage
```bash
# Deploy Longhorn CSI for persistent volumes
cd longhorn/
helmfile apply

# Verify Longhorn is running
kubectl get pods -n longhorn-system
kubectl get storageclass
```

### 2.2 Deploy MinIO Object Storage
```bash
# Deploy MinIO for S3-compatible object storage
cd ../minio/
helmfile apply

# Verify MinIO is running
kubectl get pods -n minio-operator
kubectl get pods -n minio-tenant
```

## Step 3: Deploy GitOps Infrastructure

**Now that storage foundation is ready, deploy GitOps-managed components.**

### 3.1 Bootstrap Flux
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

### 3.2 Wait for Infrastructure Deployment
```bash
# Watch Flux deploy the infrastructure
flux get all

# Wait for all components to be ready (2-5 minutes)
kubectl get pods -A
```

You should see pods running in:
- `flux-system` (GitOps controller)
- `metallb-system` (Load balancer)
- `cert-manager` (Certificate management)
- `haproxy-controller` (Ingress controller)
- `monitoring` (Prometheus + Grafana)

## Step 4: Verify Everything Works

### 4.1 Check Service IPs
```bash
kubectl get svc -A | grep LoadBalancer
```

You should see MinIO services with external IPs from your MetalLB range.

### 4.2 Access MinIO Console
1. Find the console IP: `kubectl get svc minio-tenant-console -n minio-tenant`
2. Open browser to: `https://CONSOLE_IP:9443`
3. Login with your credentials (default: minio/minio123)
4. Accept the self-signed certificate warning

### 4.3 Access Grafana Dashboard
1. Find the Grafana IP: `kubectl get svc grafana -n monitoring`
2. Open browser to: `http://GRAFANA_IP:3000`
3. Login with: admin/grafana123
4. Explore pre-configured dashboards for Kubernetes, nodes, and storage

### 4.4 Access Longhorn UI
```bash
# Port-forward to access Longhorn
kubectl port-forward -n longhorn-system svc/longhorn-frontend 8080:80
```
Open browser to: `http://localhost:8080`

### 4.5 Access Trino Analytics Engine
1. Find the Trino IP: `kubectl get svc trino-coordinator-lb -n iceberg-system`
2. Open browser to: `http://TRINO_IP:8080`
3. No authentication required - direct access to query interface
4. Use Trino CLI for advanced queries:
```bash
# Download Trino CLI
curl -o trino https://repo1.maven.org/maven2/io/trino/trino-cli/476/trino-cli-476-executable.jar
chmod +x trino

# Connect to cluster
./trino --server http://TRINO_IP:8080 --user admin
```

### 4.6 Test NATS + JetStream Messaging
```bash
# Test NATS connectivity
kubectl exec -n nats nats-box-XXXXX -- nats --server nats://nats:4222 stream ls

# Create a test stream for IoT data
kubectl exec -n nats nats-box-XXXXX -- nats --server nats://nats:4222 stream add iot-sensors --subjects "sensors.>" --storage file --retention limits --max-age=24h --replicas=1 --defaults
```

### 4.7 Access ClickHouse Analytics Database
1. Find the ClickHouse IP: `kubectl get svc clickhouse-lb -n clickhouse`
2. Open browser to: `http://CLICKHOUSE_IP:8123/play` (SQL editor)
3. Or access dashboard: `http://CLICKHOUSE_IP:8123/dashboard` (monitoring)
4. Test with a simple query:
```sql
-- In the Play interface, try:
SELECT version(), uptime();

-- Create a test database
CREATE DATABASE IF NOT EXISTS homelab_test;

-- Create a sample IoT table
CREATE TABLE homelab_test.sensor_data (
    timestamp DateTime,
    sensor_id String,
    temperature Float32,
    humidity Float32
) ENGINE = MergeTree()
ORDER BY (sensor_id, timestamp);
```

## Step 5: Test GitOps Workflow

### 5.1 Make a Change
Edit any file in the repository (try changing a comment):
```bash
# Edit a file
echo "# Test change" >> clusters/um890/kustomization.yaml

# Commit and push
git add .
git commit -m "Test GitOps workflow"
git push origin main
```

### 5.2 Watch Flux Sync
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
- **HAProxy Ingress** providing application load balancing
- **Pi-hole DNS** providing local hostname resolution for .homelab.local domains
- **MinIO** providing S3-compatible object storage
- **Prometheus + Grafana** providing comprehensive monitoring
- **Trino + Iceberg** providing analytics engine and data lake capabilities
- **ClickHouse** providing real-time analytics database for IoT data processing
- **NATS + JetStream** providing high-performance messaging for IoT data streams

### GitOps Workflow
- **Flux** automatically syncs infrastructure changes from Git
- **Helmfile** manages complex applications like MinIO
- **All configuration** stored in Git for version control

### Access Points
- **Pi-hole Admin**: DNS management and ad-blocking configuration
- **MinIO Console**: Web UI for object storage management
- **MinIO S3 API**: S3-compatible API for applications
- **Grafana**: Monitoring dashboards and metrics visualization
- **Longhorn UI**: Storage management interface
- **Trino Web UI**: SQL query interface for analytics (no authentication)
- **Trino CLI**: Command-line SQL interface for advanced queries
- **ClickHouse Play**: Interactive SQL editor for real-time analytics
- **ClickHouse Dashboard**: System monitoring and performance metrics
- **NATS**: High-performance messaging system for IoT data streams
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
