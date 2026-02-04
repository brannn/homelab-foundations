# Garage Object Storage Deployment

**Replaces MinIO** for AGPL-3.0 open-source compliance in homelab-foundations.

## Overview

Garage is a lightweight, S3-compatible object storage system written in Rust. It's perfect for homelab deployments where MinIO's commercial licensing would be required.

### Key Features

- ✅ **Fully Open Source**: AGPL-3.0 license (no commercial restrictions)
- ✅ **Lightweight**: 512MB-1GB RAM vs MinIO's 2-4GB
- ✅ **S3 Compatible**: Works with Trino, Iceberg, CNPG, etc.
- ✅ **High Performance**: Rust-based, efficient I/O
- ✅ **Simple Deployment**: Single binary, easy configuration
- ✅ **Perfect for Homelab**: Designed for 1-3 node deployments

## Deployment

### Manual Deployment (Foundation Storage)

```bash
cd garage/
helmfile apply

# Verify deployment
kubectl get pods -n garage
kubectl get svc -n garage
```

### GitOps Management

Garage is managed via Helmfile (like MinIO was) as foundation storage that must remain operational even if GitOps fails.

## Configuration

### Storage

- **Capacity**: 4TB (uses dedicated 4TB drive)
- **Storage Class**: Longhorn
- **Data Path**: `/var/lib/garage/data`

### S3 API Access

| Service | Type | IP | Port | Description |
|---------|------|----|-----|-------------|
| Garage S3 API | LoadBalancer | 10.0.0.241 | 80 | S3-compatible API |
| Garage Admin API | LoadBalancer | 10.0.0.242 | 3903 | Administration API |

### Credentials

**Default (CHANGE FOR DEPLOYMENT):**
- **Access Key**: `garage`
- **Secret Key**: `garage123`

Update in `garage/values.yaml` before deployment:

```yaml
garage:
  s3:
    accessKeyId: your_access_key
    secretAccessKey: your_secure_password
```

### Auto-Created Buckets

Garage automatically creates these buckets on deployment:

1. **iceberg** - Trino + Iceberg data lake storage
2. **postgres-backups** - CNPG PostgreSQL backups
3. **longhorn-backups** - Optional Longhorn volume backups

## Usage

### S3 Client Configuration

```bash
# Using AWS CLI (for example)
aws configure --profile garage
# Enter Garage credentials
# Default region: us-east-1
# S3 endpoint: http://10.0.0.241:80

# List buckets
aws --endpoint-url http://10.0.0.241:80 --profile garage s3 ls
```

### Testing Connectivity

```bash
# Run a test pod
kubectl run -it --rm garage-test --image=amazon/aws-cli --restart=Never -- sh

# Inside the pod:
export AWS_ACCESS_KEY_ID=garage
export AWS_SECRET_ACCESS_KEY=garage123
export AWS_DEFAULT_REGION=us-east-1

# Test S3 access
aws --endpoint-url http://garage.garage.svc.cluster.local:3900 s3 ls
```

## Integration Points

### Trino + Iceberg

Garage seamlessly replaces MinIO for Trino's Iceberg catalog:

```yaml
# Trino catalog configuration
warehouse=s3://iceberg/
fs.native-s3.endpoint=http://10.0.0.241:80
fs.native-s3.path-style-access=true
```

### PostgreSQL Backups (CNPG)

CNPG uses Garage for PostgreSQL backups:

```yaml
barmanObjectStore:
  destinationPath: "s3://postgres-backups"
  endpointURL: "http://10.0.0.241:80"
```

### ClickHouse

ClickHouse can use Garage for data import/export:

```sql
-- Example: Upload to Garage
INSERT INTO FUNCTION s3('http://10.0.0.241:80/iceberg/data.parquet', 
  'garage', 'garage123', 'parquet')
SELECT * FROM sensor_data;
```

## Operations

### Managing Buckets

```bash
# Access Garage pod
kubectl exec -it -n garage deployment/garage -- sh

# Use garage CLI
garage bucket list
garage bucket info iceberg
garage bucket create new-bucket
```

### Monitoring

Garage exports metrics for Prometheus:

```bash
# Check metrics endpoint
kubectl port-forward -n garage svc/garage 3903:3903
curl http://localhost:3903/metrics
```

### Backup Configuration

For enhanced backup reliability, configure Garage replication:

```yaml
garage:
  layout:
    replication_factor: 2  # If you add a second node
```

## Troubleshooting

### Common Issues

**Service not accessible:**
```bash
# Check pod status
kubectl get pods -n garage

# Check service
kubectl get svc -n garage

# Check logs
kubectl logs -n garage deployment/garage
```

**S3 API not responding:**
```bash
# Verify port is listening
kubectl port-forward -n garage svc/garage 3900:3900
curl -v http://localhost:3900/
```

**Storage issues:**
```bash
# Check Longhorn volume
kubectl get pvc -n garage
kubectl describe pvc garage-data -n garage
```

### Logs

```bash
# View logs
kubectl logs -n garage deployment/garage -f

# View specific component logs
kubectl logs -n garage deployment/garage --all-containers=true
```

## Performance Characteristics

### Expected Performance (4TB NVMe)

- **Sequential Read**: 2-3 GB/s
- **Sequential Write**: 1.5-2 GB/s
- **Random I/O**: 50K+ IOPS
- **Latency**: <10ms for small objects

### Resource Usage

- **RAM**: 512MB-1GB (much less than MinIO)
- **CPU**: 0.5-1 core average
- **Storage**: Uses 4TB drive efficiently

## Migration from MinIO

### What Changed

| Aspect | MinIO | Garage |
|--------|-------|--------|
| **License** | Commercial (production) | AGPL-3.0 (free) |
| **RAM** | 2-4GB | 512MB-1GB |
| **Complexity** | Operator + Tenant | Single deployment |
| **Console** | Web UI | CLI/API only |
| **S3 Compatibility** | Full | Full |

### Compatibility

- ✅ **Trino**: Fully compatible
- ✅ **Iceberg**: Fully compatible
- ✅ **CNPG**: Fully compatible
- ✅ **ClickHouse**: Fully compatible
- ✅ **AWS CLI**: Fully compatible
- ✅ **Python boto3**: Fully compatible

### No Code Changes Required

All services using S3 API work identically with Garage. Only the endpoint URL changes from MinIO IPs to Garage IPs.

## Security Considerations

### Production Deployment

1. **Change default credentials** in `values.yaml`
2. **Enable TLS** if exposing externally (via ingress)
3. **Use strong access keys** (32+ characters)
4. **Enable bucket versioning** for critical data
5. **Regular backups** of Garage metadata

### Network Security

- **Internal Access**: Use ClusterIP service from within cluster
- **External Access**: Use LoadBalancer IPs (10.0.0.241, 10.0.0.242)
- **DNS Resolution**: Use Pi-hole for homelab.local domains

## Comparison with Alternatives

| Feature | Garage | SeaweedFS | Ceph | Wasabi (Cloud) |
|---------|--------|-----------|------|----------------|
| **License** | AGPL-3.0 | Apache 2.0 | LGPL | Commercial |
| **Complexity** | Simple | Moderate | Complex | N/A |
| **Resource Usage** | Low | Medium | High | N/A |
| **S3 Compatible** | Yes | Yes | Yes | Yes |
| **Homelab Fit** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐ | N/A |

## Support and Resources

- **Documentation**: https://garagehq.deuxfleurs.fr/
- **GitHub**: https://github.com/deuxfleurs/garage
- **Community Matrix**: https://matrix.to/#/#garage:deuxfleurs.fr
- **License**: AGPL-3.0

## Summary

Garage provides the perfect balance of:
- ✅ Open source freedom (AGPL-3.0)
- ✅ Homelab-appropriate scale
- ✅ Full S3 compatibility
- ✅ Low resource requirements
- ✅ Simple deployment and management

It's the ideal replacement for MinIO in homelab-foundations while maintaining all S3-based integrations.