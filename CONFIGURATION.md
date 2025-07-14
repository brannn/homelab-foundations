# Configuration Guide

**Version**: 1.0  
**Date**: 2025-07-13  
**Author**: Community Contributors  
**Status**: Active

## Overview

This guide helps you customize the homelab-foundations repository for your specific environment. Before deploying, you'll need to update several configuration files with your network settings, credentials, and resource requirements.

## Required Customizations

### 1. Network Configuration

**File**: `clusters/um890/metallb/metallb.yaml`

Update the IP address pool for your network:
```yaml
spec:
  addresses:
    - 192.168.1.240-192.168.1.250  # Change to your network range
```

RFC1918 private address ranges:
- `10.0.0.0/8` (10.0.0.0 - 10.255.255.255)
- `172.16.0.0/12` (172.16.0.0 - 172.31.255.255)
- `192.168.0.0/16` (192.168.0.0 - 192.168.255.255)

### 2. MinIO Credentials

**File**: `minio/tenant-values.yaml`

Update the MinIO access credentials:
```yaml
configSecret:
  name: minio-tenant-env-configuration
  accessKey: admin  # Change this
  secretKey: changeme123  # Change this to a strong password
```

**Security Note**: Use strong, unique credentials for production use.

### 3. Resource Allocation

**File**: `minio/tenant-values.yaml`

Adjust CPU and memory limits based on your hardware:
```yaml
resources:
  requests:
    cpu: "1000m"  # 1 CPU core
    memory: "2Gi"  # 2GB RAM
  limits:
    cpu: "2000m"  # 2 CPU cores  
    memory: "4Gi"  # 4GB RAM
```

**Hardware Recommendations**:
- **Minimum**: 2 cores, 4GB RAM
- **Recommended**: 4+ cores, 8+ GB RAM
- **Storage**: 100GB+ available disk space

### 4. Storage Configuration

**File**: `minio/tenant-values.yaml`

Adjust storage size based on your needs:
```yaml
size: 300Gi  # Adjust for your storage requirements
storageClassName: longhorn
```

### 5. Monitoring Credentials

**File**: `clusters/um890/monitoring/grafana/helmrelease.yaml`

Update Grafana admin credentials:
```yaml
values:
  adminUser: admin
  adminPassword: grafana123  # Change this for your deployment
```

**Security Note**: Change the default Grafana password for production use.

### 6. Cluster Name and Paths

**Directory**: `clusters/um890/`

Rename the `um890` directory to match your cluster name:
```bash
mv clusters/um890 clusters/YOUR_CLUSTER_NAME
```

Update references in:
- Flux bootstrap command
- Documentation
- Any hardcoded paths

## Optional Customizations

### 1. Replica Counts

For single-node clusters, keep replica counts at 1:
```yaml
# MinIO Operator
operator:
  replicaCount: 1

# MinIO Tenant  
servers: 1
```

For multi-node clusters, you can increase these values.

### 2. Storage Classes

If using a different storage provider than Longhorn:
```yaml
storageClassName: your-storage-class
```

### 3. Namespace Names

Default namespaces can be changed if needed:
- `minio-operator`
- `minio-tenant`
- `longhorn-system`
- `metallb-system`

## Deployment Checklist

Before deploying, ensure you have:

- [ ] Updated MetalLB IP ranges for your network
- [ ] Changed MinIO credentials from defaults
- [ ] Changed Grafana admin password from default
- [ ] Adjusted resource limits for your hardware
- [ ] Configured appropriate storage sizes
- [ ] Renamed cluster directory if needed
- [ ] Forked/copied repository to your GitHub account
- [ ] Updated Flux bootstrap command with your details

## Security Considerations

### Production Deployments

For production use:
1. **Use strong passwords** for all services
2. **Enable TLS** where possible
3. **Restrict network access** to necessary ports
4. **Regular backups** of critical data
5. **Monitor resource usage** and set alerts
6. **Keep software updated** regularly

### Development/Testing

For development environments:
1. Default credentials may be acceptable
2. Self-signed certificates are fine
3. Resource limits can be lower
4. Backup frequency can be reduced

## Getting Help

If you encounter issues:

1. **Check the documentation** in the `docs/` directory
2. **Review logs** using the commands in `docs/QUICK_REFERENCE.md`
3. **Search existing issues** in the GitHub repository
4. **Create a new issue** with detailed information about your setup

## Contributing

Found an issue or have an improvement? Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

Your contributions help make this project better for the entire homelab community!
