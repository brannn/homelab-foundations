# ClickHouse Analytics Database Guide

**Version**: 1.0
**Date**: 2025-07-15
**Author**: Community Contributors
**Status**: Active

## Overview

ClickHouse is a high-performance columnar database management system (DBMS) optimized for online analytical processing (OLAP). This guide covers the deployment and usage of ClickHouse in the homelab-foundations environment.

## Architecture

### Deployment Model
- **Management**: Flux CD GitOps
- **Operator**: Altinity ClickHouse Operator v0.25.0
- **ClickHouse Version**: 25.6.3.116 (latest stable)
- **Cluster Configuration**: Single-node deployment
- **Storage**: Longhorn CSI with 20Gi persistent volume
- **Namespace**: clickhouse

### Resource Allocation
- **CPU**: 500m requests, 2 CPU limits
- **Memory**: 1Gi requests, 2Gi limits
- **Storage**: 20Gi Longhorn persistent volume
- **Replicas**: 1 (single-node homelab configuration)

## Access Methods

### LoadBalancer Service (MetalLB)
- **IP Address**: 10.0.0.248
- **HTTP Interface**: Port 8123
- **Native Protocol**: Port 9000
- **Metrics**: Port 9363

### HAProxy Ingress
- **Hostname**: clickhouse.homelab.local
- **Protocol**: HTTP/HTTPS
- **TLS**: Self-signed certificates via cert-manager

### Internal Access
```bash
# From within cluster
kubectl exec -n clickhouse chi-homelab-clickhouse-homelab-cluster-0-0-0 -- clickhouse-client

# Port forwarding for external access
kubectl port-forward -n clickhouse chi-homelab-clickhouse-homelab-cluster-0-0-0 8123:8123
```

## Basic Usage

### Command Line Client
```bash
# Execute query directly
kubectl exec -n clickhouse chi-homelab-clickhouse-homelab-cluster-0-0-0 -- \
  clickhouse-client --query "SELECT version()"

# Interactive session
kubectl exec -it -n clickhouse chi-homelab-clickhouse-homelab-cluster-0-0-0 -- \
  clickhouse-client
```

### HTTP Interface
```bash
# Simple query via HTTP
curl "http://10.0.0.248:8123/?query=SELECT%201"

# With authentication (if configured)
curl -u username:password "http://10.0.0.248:8123/?query=SELECT%201"
```

## Database Operations

### Create Database
```sql
CREATE DATABASE IF NOT EXISTS analytics;
```

### Create Table (IoT Sensor Example)
```sql
CREATE TABLE analytics.sensor_data (
    timestamp DateTime,
    sensor_id String,
    location String,
    temperature Float32,
    humidity Float32,
    pressure Float32
) ENGINE = MergeTree()
ORDER BY (sensor_id, timestamp)
PARTITION BY toYYYYMM(timestamp);
```

### Insert Data
```sql
INSERT INTO analytics.sensor_data VALUES
    ('2025-07-15 10:00:00', 'temp_001', 'living_room', 22.5, 45.2, 1013.25),
    ('2025-07-15 10:01:00', 'temp_001', 'living_room', 22.7, 44.8, 1013.30);
```

### Query Data
```sql
-- Basic selection
SELECT * FROM analytics.sensor_data 
WHERE sensor_id = 'temp_001' 
ORDER BY timestamp DESC 
LIMIT 10;

-- Aggregation example
SELECT 
    sensor_id,
    avg(temperature) as avg_temp,
    max(temperature) as max_temp,
    min(temperature) as min_temp
FROM analytics.sensor_data 
WHERE timestamp >= now() - INTERVAL 1 HOUR
GROUP BY sensor_id;
```

## Integration with Data Pipeline

### NATS Integration
ClickHouse can consume data from NATS streams for real-time analytics:

```sql
-- Create table for NATS stream data
CREATE TABLE analytics.nats_events (
    event_time DateTime,
    subject String,
    data String
) ENGINE = MergeTree()
ORDER BY (subject, event_time);
```

### Trino Integration
ClickHouse can be accessed from Trino for federated queries:

1. Configure ClickHouse connector in Trino
2. Query across ClickHouse and Iceberg tables
3. Combine real-time (ClickHouse) and batch (Iceberg) analytics

## Monitoring

### Prometheus Integration
- **ServiceMonitor**: Configured for metrics collection
- **Metrics Endpoint**: http://10.0.0.248:9363/metrics
- **Grafana Dashboards**: Available for ClickHouse monitoring

### Health Checks
```bash
# Check cluster status
kubectl get clickhouseinstallations -n clickhouse

# Check pod health
kubectl get pods -n clickhouse

# Test connectivity
kubectl exec -n clickhouse chi-homelab-clickhouse-homelab-cluster-0-0-0 -- \
  clickhouse-client --query "SELECT 1"
```

## Configuration

### ClickHouseInstallation Resource
Located at: `clusters/um890/clickhouse/clickhouse-installation.yaml`

Key configuration sections:
- **Cluster Layout**: Single shard, single replica
- **Pod Template**: Resource limits and security context
- **Volume Template**: Longhorn storage configuration
- **Settings**: Performance and monitoring configuration

### Customization
To modify ClickHouse configuration:

1. Edit `clusters/um890/clickhouse/clickhouse-installation.yaml`
2. Commit changes to Git
3. Flux automatically applies updates
4. Monitor deployment: `kubectl get chi -n clickhouse`

## Performance Tuning

### Memory Settings
Current configuration optimized for homelab:
- **Container Memory**: 2Gi limit
- **User Memory Limit**: 1Gi (configured in profiles)

### Storage Optimization
- **Engine**: MergeTree for most use cases
- **Partitioning**: By date for time-series data
- **Compression**: LZ4 (default) for balance of speed/size

## Troubleshooting

### Common Issues

1. **Pod CrashLoopBackOff**
   ```bash
   kubectl logs -n clickhouse chi-homelab-clickhouse-homelab-cluster-0-0-0
   ```

2. **Configuration Errors**
   ```bash
   kubectl describe chi homelab-clickhouse -n clickhouse
   ```

3. **Storage Issues**
   ```bash
   kubectl get pvc -n clickhouse
   kubectl describe pvc volume-template-chi-homelab-clickhouse-homelab-cluster-0-0-0 -n clickhouse
   ```

### Recovery Procedures

1. **Restart ClickHouse**
   ```bash
   kubectl delete pod chi-homelab-clickhouse-homelab-cluster-0-0-0 -n clickhouse
   ```

2. **Reconfigure Installation**
   ```bash
   kubectl delete chi homelab-clickhouse -n clickhouse
   # Flux will recreate from Git
   ```

## Security Considerations

### Current Configuration
- **Authentication**: None (homelab environment)
- **Network Access**: Limited to homelab network (10.0.0.0/24)
- **TLS**: Available via HAProxy ingress with self-signed certificates

### Production Recommendations
- Enable user authentication
- Configure SSL/TLS for native protocol
- Implement network policies
- Regular security updates

## Backup and Recovery

### Data Backup
```sql
-- Create backup
BACKUP TABLE analytics.sensor_data TO Disk('backups', 'sensor_data_backup.zip');

-- Restore backup
RESTORE TABLE analytics.sensor_data FROM Disk('backups', 'sensor_data_backup.zip');
```

### Volume Backup
- Longhorn provides snapshot capabilities
- Configure automated snapshots for persistent volumes
- Test restore procedures regularly

## Use Cases

### IoT Data Analytics
- Real-time sensor data ingestion
- Time-series analysis
- Anomaly detection
- Dashboard visualization

### Log Analytics
- Application log processing
- Performance monitoring
- Error tracking
- Audit trails

### Business Intelligence
- Data warehousing
- Reporting and dashboards
- Ad-hoc analytics
- Data exploration

## External Resources

- [ClickHouse Documentation](https://clickhouse.com/docs/)
- [Altinity Operator Documentation](https://docs.altinity.com/)
- [ClickHouse SQL Reference](https://clickhouse.com/docs/sql-reference/)
- [Performance Optimization Guide](https://clickhouse.com/docs/optimize/)
