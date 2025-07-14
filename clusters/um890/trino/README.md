# Trino with Iceberg Integration

## Overview

This deployment provides a complete Trino cluster with Apache Iceberg integration for the homelab-foundations environment. It includes:

- **Trino Coordinator**: Query planning and coordination (2GB RAM)
- **Trino Worker**: Query execution (4GB RAM)  
- **Iceberg REST Catalog**: Metadata management (512MB RAM)
- **MinIO Integration**: S3-compatible storage backend
- **Monitoring**: Prometheus metrics and Grafana dashboards

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│ Trino           │    │ Iceberg REST     │    │ MinIO           │
│ Coordinator     │◄──►│ Catalog          │◄──►│ S3 Storage      │
│ (2GB RAM)       │    │ (512MB RAM)      │    │ (iceberg bucket)│
└─────────────────┘    └──────────────────┘    └─────────────────┘
         ▲
         │
         ▼
┌─────────────────┐
│ Trino Worker    │
│ (4GB RAM)       │
└─────────────────┘
```

## Components

### Trino Cluster
- **Coordinator**: Handles query planning, parsing, and coordination
- **Worker**: Executes query tasks and processes data
- **Memory**: 6.5GB total (coordinator: 2GB, worker: 4GB)
- **JVM Heaps**: Coordinator 1.5GB, Worker 3.5GB

### Iceberg REST Catalog
- **Purpose**: Manages Iceberg table metadata
- **Storage**: Uses MinIO S3 backend for table metadata and data
- **Memory**: 512MB RAM with 512MB JVM heap
- **API**: REST API for table operations

### Storage Integration
- **Backend**: MinIO tenant with dedicated `iceberg` bucket
- **Format**: Apache Iceberg tables with S3-compatible storage
- **Features**: Time travel, schema evolution, ACID transactions

## Access Methods

### Trino Web UI
- **URL**: https://trino.homelab.local (via HAProxy ingress)
- **Direct IP**: http://10.0.0.241:8080 (via MetalLB LoadBalancer)
- **Features**: Query editor, execution history, cluster status

### Trino CLI
```bash
# Install Trino CLI
curl -o trino https://repo1.maven.org/maven2/io/trino/trino-cli/476/trino-cli-476-executable.jar
chmod +x trino

# Connect to cluster
./trino --server http://10.0.0.241:8080
```

### Iceberg REST API
- **URL**: https://iceberg.homelab.local (via HAProxy ingress)
- **Direct IP**: http://10.0.0.242:8181 (via MetalLB LoadBalancer)
- **Endpoints**: `/v1/config`, `/v1/namespaces`, `/v1/namespaces/{namespace}/tables`

## Usage Examples

### Basic Queries
```sql
-- Show available catalogs
SHOW CATALOGS;

-- Show schemas in iceberg catalog
SHOW SCHEMAS FROM iceberg;

-- Create a namespace (schema)
CREATE SCHEMA iceberg.analytics;

-- Create an Iceberg table
CREATE TABLE iceberg.analytics.sales (
    id BIGINT,
    product_name VARCHAR,
    price DECIMAL(10,2),
    sale_date DATE,
    customer_id BIGINT
) WITH (
    format = 'PARQUET',
    partitioning = ARRAY['sale_date']
);

-- Insert sample data
INSERT INTO iceberg.analytics.sales VALUES
(1, 'Laptop', 999.99, DATE '2025-01-01', 1001),
(2, 'Mouse', 29.99, DATE '2025-01-01', 1002),
(3, 'Keyboard', 79.99, DATE '2025-01-02', 1003);

-- Query the data
SELECT * FROM iceberg.analytics.sales;

-- Time travel query (view data as of specific timestamp)
SELECT * FROM iceberg.analytics.sales FOR TIMESTAMP AS OF TIMESTAMP '2025-01-01 12:00:00';
```

### Advanced Iceberg Features
```sql
-- Show table history
SELECT * FROM iceberg.analytics."sales$history";

-- Show table snapshots
SELECT * FROM iceberg.analytics."sales$snapshots";

-- Show table files
SELECT * FROM iceberg.analytics."sales$files";

-- Optimize table (compact small files)
ALTER TABLE iceberg.analytics.sales EXECUTE optimize;

-- Expire old snapshots (cleanup)
ALTER TABLE iceberg.analytics.sales EXECUTE expire_snapshots(retention_threshold => '7d');
```

## Configuration

### Resource Allocation
The deployment is configured for homelab use with conservative resource limits:

| Component | CPU Request | CPU Limit | Memory Request | Memory Limit | JVM Heap |
|-----------|-------------|-----------|----------------|--------------|----------|
| Coordinator | 500m | 1000m | 2Gi | 2Gi | 1500m |
| Worker | 1000m | 2000m | 4Gi | 4Gi | 3500m |
| Iceberg REST | 100m | 500m | 512Mi | 512Mi | 512m |

### Network Configuration
- **MetalLB IPs**: 
  - Trino: 10.0.0.241
  - Iceberg REST: 10.0.0.242
- **Ingress Hosts**:
  - Trino: trino.homelab.local
  - Iceberg REST: iceberg.homelab.local

### Storage Configuration
- **MinIO Endpoint**: https://10.0.0.241:443 (S3 API via LoadBalancer)
- **S3 Bucket**: iceberg
- **Credentials**: Stored in Kubernetes secret `minio-credentials`

## Monitoring

### Prometheus Metrics
Both Trino and Iceberg REST catalog expose metrics for Prometheus:

- **Trino Metrics**: Available on port 5556 via JMX exporter
- **Iceberg Metrics**: Available on port 8181/metrics
- **ServiceMonitors**: Automatically configured for Prometheus discovery

### Key Metrics to Monitor
- `trino_running_queries`: Number of currently executing queries
- `trino_queued_queries`: Number of queries waiting to execute
- `trino_cluster_memory_bytes`: Total cluster memory usage
- HTTP request metrics from Iceberg REST catalog

### Grafana Dashboards
The monitoring stack includes pre-configured dashboards for:
- Trino cluster overview
- Query performance metrics
- Resource utilization
- Iceberg catalog operations

## Troubleshooting

### Common Issues

1. **Trino pods not starting**:
   ```bash
   kubectl describe pod -n iceberg-system -l app.kubernetes.io/name=trino
   kubectl logs -n iceberg-system -l app.kubernetes.io/name=trino
   ```

2. **Iceberg catalog connection issues**:
   ```bash
   kubectl logs -n iceberg-system deployment/iceberg-rest-catalog
   kubectl get svc -n iceberg-system iceberg-rest-catalog
   ```

3. **MinIO connectivity problems**:
   ```bash
   # Test MinIO connectivity from within cluster
   kubectl run -it --rm debug --image=busybox --restart=Never -- sh
   # Inside the pod:
   wget -qO- http://minio.minio-tenant.svc.cluster.local:9000
   ```

4. **Query failures**:
   ```bash
   # Check Trino coordinator logs
   kubectl logs -n iceberg-system deployment/trino-coordinator
   
   # Check worker logs
   kubectl logs -n iceberg-system deployment/trino-worker
   ```

### Health Checks
```bash
# Check all pods are running
kubectl get pods -n iceberg-system

# Check services
kubectl get svc -n iceberg-system

# Check ingress
kubectl get ingress -n iceberg-system

# Test Trino health
curl http://10.0.0.241:8080/v1/info

# Test Iceberg REST health
curl http://10.0.0.242:8181/v1/config
```

## Security Considerations

- **Network**: All components run within the cluster network
- **Authentication**: No authentication configured (suitable for homelab)
- **TLS**: Self-signed certificates for ingress (via cert-manager)
- **Secrets**: MinIO credentials stored in plain text (update for production)

## Scaling

### Horizontal Scaling
To add more workers:
```yaml
# In helmrelease.yaml
server:
  workers: 2  # Increase worker count
```

### Vertical Scaling
To increase resources:
```yaml
# In helmrelease.yaml
coordinator:
  jvm:
    maxHeapSize: "2G"  # Increase heap
  resources:
    limits:
      memory: 3Gi      # Increase memory limit
```

## Integration with Other Services

### Data Sources
Trino can connect to additional data sources by adding catalogs:
```yaml
catalogs:
  postgresql: |
    connector.name=postgresql
    connection-url=jdbc:postgresql://postgres:5432/database
    connection-user=user
    connection-password=password
```

### ETL Pipelines
Use Trino for ETL operations with Iceberg tables:
- Extract data from various sources
- Transform using SQL
- Load into Iceberg tables with ACID guarantees

## Prerequisites

### 1. MinIO Bucket Setup
Before deploying Trino, ensure the `iceberg` bucket exists in MinIO:

1. **Access MinIO Console**:
   ```bash
   # Get MinIO console LoadBalancer IP
   kubectl get svc -n minio-tenant
   # Visit https://<MINIO-CONSOLE-IP>:9443
   ```

2. **Login with your MinIO credentials**

3. **Create bucket**: Create a bucket named `iceberg`

4. **Alternative - CLI method**:
   ```bash
   # Install MinIO client
   curl https://dl.min.io/client/mc/release/linux-amd64/mc -o mc
   chmod +x mc

   # Configure MinIO endpoint (use your actual credentials)
   ./mc alias set homelab https://<MINIO-API-IP>:443 <ACCESS_KEY> <SECRET_KEY>

   # Create bucket
   ./mc mb homelab/iceberg
   ```

### 2. MinIO Credentials Secret
Create a Kubernetes secret with your MinIO credentials:

```bash
# Create the secret with your actual MinIO credentials
kubectl create secret generic minio-credentials \
  --from-literal=access-key="YOUR_MINIO_ACCESS_KEY" \
  --from-literal=secret-key="YOUR_MINIO_SECRET_KEY" \
  --namespace=iceberg-system

# Verify the secret was created
kubectl get secret minio-credentials -n iceberg-system
```

**Important**: Never commit actual credentials to Git. The `secret-template.yaml` file is provided as a reference only.

## Next Steps

1. **Create the iceberg bucket** in MinIO (see Prerequisites above)
2. **Deploy the Trino cluster** via Flux GitOps
3. **Create your first Iceberg table** using the examples above
4. **Set up monitoring dashboards** in Grafana
5. **Configure additional data sources** as needed
6. **Implement data pipelines** using Trino + Iceberg
7. **Explore advanced Iceberg features** like time travel and schema evolution
