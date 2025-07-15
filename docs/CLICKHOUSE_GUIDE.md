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

### HAProxy Ingress (Recommended)
- **Hostname**: clickhouse.homelab.local
- **Protocol**: HTTP/HTTPS
- **TLS**: Self-signed certificates via cert-manager
- **Ingress IP**: Assigned by HAProxy controller (check with `kubectl get ingress -n clickhouse`)
- **Web UI**: /play (SQL editor), /dashboard (monitoring)
- **HTTP API**: All standard ClickHouse HTTP endpoints
- **Authentication**: None required (homelab configuration)

### LoadBalancer Service (MetalLB)
- **IP Address**: 10.0.0.248
- **HTTP Interface**: Port 8123
- **Native Protocol**: Port 9000 (for native ClickHouse clients)
- **Metrics**: Port 9363 (for Prometheus)
- **Authentication**: None required (homelab configuration)
- **Status**: Verified working - web interfaces accessible

### Internal Access
```bash
# From within cluster
kubectl exec -n clickhouse chi-homelab-clickhouse-homelab-cluster-0-0-0 -- clickhouse-client

# Port forwarding (not recommended - use LoadBalancer or ingress instead)
kubectl port-forward -n clickhouse chi-homelab-clickhouse-homelab-cluster-0-0-0 8123:8123
```

### Checking Ingress Status
```bash
# Check ingress configuration and IP assignment
kubectl get ingress -n clickhouse

# View detailed ingress information
kubectl describe ingress clickhouse-http -n clickhouse

# Check HAProxy ingress controller logs if needed
kubectl logs -n haproxy-controller deployment/haproxy-ingress
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
# Simple query via HAProxy ingress (recommended)
curl "https://clickhouse.homelab.local/?query=SELECT%201"

# Or via LoadBalancer (direct access)
curl "http://10.0.0.248:8123/?query=SELECT%201"

# With authentication (if configured)
curl -u username:password "https://clickhouse.homelab.local/?query=SELECT%201"
```

### Web UI Options

ClickHouse doesn't include a built-in web UI, but several community options are available:

#### 1. Built-in Web Interfaces
ClickHouse includes several built-in web interfaces:

**ClickHouse Play (SQL Editor):**
```bash
# Access via HAProxy ingress (recommended)
https://clickhouse.homelab.local/play
# or direct LoadBalancer access (verified working)
http://10.0.0.248:8123/play
```

**ClickHouse Dashboard (Monitoring):**
```bash
# Access via HAProxy ingress (recommended)
https://clickhouse.homelab.local/dashboard
# or direct LoadBalancer access (verified working)
http://10.0.0.248:8123/dashboard
```

**Features:**
- **No Authentication Required**: Direct access for homelab convenience
- **Real-time Interface**: Both interfaces update dynamically
- **Schema Browser**: Explore databases and tables in Play interface
- **Query History**: Previous queries saved in browser session
- **Performance Metrics**: Dashboard shows system performance and query statistics

#### 2. Tabix (Community Web UI)
Popular web-based SQL client for ClickHouse:
```bash
# Deploy Tabix as a separate service
kubectl create deployment tabix --image=spoonest/clickhouse-tabix-web-client -n clickhouse
kubectl expose deployment tabix --port=80 --type=LoadBalancer -n clickhouse
```

#### 3. DBeaver (Desktop Client)
Professional database client with ClickHouse support:
- Download from: https://dbeaver.io/
- Connection: JDBC URL `jdbc:clickhouse://10.0.0.248:8123/default`

#### 4. Grafana Integration
For visualization and dashboards:
- Add ClickHouse data source to existing Grafana
- Connection: `http://10.0.0.248:8123`
- Use for real-time monitoring dashboards

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

## ClickHouse Engines

### Engine Types

ClickHouse engines determine how data is stored, accessed, and processed. The `SHOW ENGINES` command displays all available engines.

#### **Table Engines (Data Storage)**
- **MergeTree**: Primary engine for analytical workloads (OLAP)
- **ReplacingMergeTree**: Deduplicates rows with same primary key
- **SummingMergeTree**: Pre-aggregates numeric columns
- **Log**: Simple append-only storage for small datasets

#### **Integration Engines (External Systems)**
These create virtual tables that connect to external data sources:

### NATS Engine Integration

Connect directly to NATS streams for real-time data ingestion:

```sql
-- Create table that reads from NATS stream
CREATE TABLE analytics.nats_temperature_stream (
    timestamp DateTime,
    sensor_id String,
    temperature Float32,
    location String
) ENGINE = NATS
SETTINGS
    nats_url = 'nats://nats.nats.svc.cluster.local:4222',
    nats_subjects = 'sensors.temperature',
    nats_format = 'JSONEachRow',
    nats_row_delimiter = '\n';

-- Query real-time data from NATS
SELECT * FROM analytics.nats_temperature_stream LIMIT 10;

-- Create materialized view to store NATS data
CREATE MATERIALIZED VIEW analytics.nats_to_storage TO analytics.sensor_data AS
SELECT
    timestamp,
    sensor_id,
    location,
    temperature,
    0 as humidity,  -- default value
    0 as pressure   -- default value
FROM analytics.nats_temperature_stream;
```

### Iceberg Engine Integration

Connect to Apache Iceberg tables via REST catalog:

```sql
-- Connect to existing Iceberg table
CREATE TABLE analytics.iceberg_historical_data (
    timestamp DateTime,
    sensor_id String,
    temperature Float32,
    humidity Float32,
    location String
) ENGINE = Iceberg('http://iceberg-rest-catalog-lb.iceberg-system.svc.cluster.local:8181', 'homelab.sensors.historical_data');

-- Query Iceberg data alongside ClickHouse data
SELECT
    'realtime' as source,
    avg(temperature) as avg_temp,
    count() as record_count
FROM analytics.sensor_data
WHERE timestamp >= now() - INTERVAL 1 HOUR

UNION ALL

SELECT
    'historical' as source,
    avg(temperature) as avg_temp,
    count() as record_count
FROM analytics.iceberg_historical_data
WHERE timestamp >= now() - INTERVAL 24 HOUR;
```

### Other Integration Engines

**MySQL Engine**:
```sql
CREATE TABLE mysql_data (
    id UInt64,
    name String
) ENGINE = MySQL('mysql-server:3306', 'database', 'table', 'user', 'password');
```

**PostgreSQL Engine**:
```sql
CREATE TABLE postgres_data (
    id UInt64,
    data String
) ENGINE = PostgreSQL('postgres-server:5432', 'database', 'table', 'user', 'password');
```

**S3 Engine** (for MinIO):
```sql
CREATE TABLE s3_data (
    timestamp DateTime,
    data String
) ENGINE = S3('http://minio-tenant-hl.minio-tenant.svc.cluster.local:9000/bucket/path/*.parquet', 'access_key', 'secret_key', 'Parquet');
```

## Integration with Data Pipeline

### Engine Discovery and Configuration

**Check Available Engines**:
```sql
-- List all available engines
SHOW ENGINES;

-- Check specific engine support
SELECT * FROM system.table_engines WHERE name = 'NATS';

-- View engine settings
SELECT * FROM system.settings WHERE name LIKE '%nats%';
```

**Engine Configuration**:
Most integration engines are configured via:
- **Connection strings**: URLs, hostnames, ports
- **Authentication**: Usernames, passwords, tokens
- **Format settings**: Data formats (JSON, Parquet, CSV, etc.)
- **Behavioral settings**: Timeouts, batch sizes, etc.

### Trino Integration
ClickHouse can be accessed from Trino for federated queries:

1. Configure ClickHouse connector in Trino
2. Query across ClickHouse and Iceberg tables
3. Combine real-time (ClickHouse) and batch (Iceberg) analytics

**Example Trino Query**:
```sql
-- Query from Trino across multiple systems
SELECT
    ch.sensor_id,
    ch.avg_temp as realtime_avg,
    ic.avg_temp as historical_avg
FROM clickhouse.analytics.sensor_data ch
JOIN iceberg.homelab.historical_sensors ic
  ON ch.sensor_id = ic.sensor_id
WHERE ch.timestamp >= current_timestamp - INTERVAL '1' HOUR;
```

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

4. **Web UI Not Loading**
   ```bash
   # Check LoadBalancer service endpoints
   kubectl get endpoints clickhouse-lb -n clickhouse

   # Test direct HTTP access
   curl "http://10.0.0.248:8123/?query=SELECT%201"

   # Check ingress status
   kubectl get ingress -n clickhouse
   kubectl describe ingress clickhouse-http -n clickhouse
   ```

5. **Authentication Issues**
   ```bash
   # Check user configuration
   kubectl get configmap chi-homelab-clickhouse-common-usersd -n clickhouse -o yaml

   # Test with explicit empty credentials
   curl "http://default:@10.0.0.248:8123/?query=SELECT%201"
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

## Resource Management

### Scaling ClickHouse to Zero (Resource Conservation)

For homelab environments, you may want to scale down ClickHouse when not in use to conserve CPU and memory resources.

#### **Method 1: Scale StatefulSet to Zero**
```bash
# Scale down ClickHouse to zero replicas
kubectl scale statefulset chi-homelab-clickhouse-homelab-cluster-0-0 --replicas=0 -n clickhouse

# Verify scaling
kubectl get pods -n clickhouse

# Scale back up when needed
kubectl scale statefulset chi-homelab-clickhouse-homelab-cluster-0-0 --replicas=1 -n clickhouse

# Wait for pod to be ready
kubectl wait --for=condition=ready pod -l clickhouse.altinity.com/chi=homelab-clickhouse -n clickhouse --timeout=300s
```

#### **Method 2: Suspend ClickHouseInstallation**
```bash
# Suspend the ClickHouse installation (stops all pods)
kubectl patch clickhouseinstallation homelab-clickhouse -n clickhouse --type='merge' -p='{"spec":{"stop":"yes"}}'

# Check status
kubectl get clickhouseinstallations -n clickhouse

# Resume when needed
kubectl patch clickhouseinstallation homelab-clickhouse -n clickhouse --type='merge' -p='{"spec":{"stop":"no"}}'
```

#### **Method 3: Temporary Flux Suspension**
```bash
# Suspend Flux management (prevents automatic restart)
kubectl patch helmrelease clickhouse -n clickhouse --type='merge' -p='{"spec":{"suspend":true}}'

# Scale down
kubectl scale statefulset chi-homelab-clickhouse-homelab-cluster-0-0 --replicas=0 -n clickhouse

# Resume Flux management when ready to scale up
kubectl patch helmrelease clickhouse -n clickhouse --type='merge' -p='{"spec":{"suspend":false}}'
```

### Scaling Other Homelab Services

#### **NATS (Messaging System)**
```bash
# Scale down NATS
kubectl scale statefulset nats --replicas=0 -n nats

# Scale up NATS
kubectl scale statefulset nats --replicas=1 -n nats
```

#### **Trino (Analytics Engine)**
```bash
# Scale down Trino coordinator and workers
kubectl scale deployment trino-coordinator --replicas=0 -n iceberg-system
kubectl scale deployment trino-worker --replicas=0 -n iceberg-system

# Scale up Trino
kubectl scale deployment trino-coordinator --replicas=1 -n iceberg-system
kubectl scale deployment trino-worker --replicas=1 -n iceberg-system
```

#### **Monitoring Stack**
```bash
# Scale down Grafana (keep Prometheus for metrics collection)
kubectl scale deployment grafana --replicas=0 -n monitoring

# Scale down Prometheus (if not needed)
kubectl scale statefulset prometheus-kube-prometheus-stack-prometheus --replicas=0 -n monitoring

# Scale up when needed
kubectl scale deployment grafana --replicas=1 -n monitoring
kubectl scale statefulset prometheus-kube-prometheus-stack-prometheus --replicas=1 -n monitoring
```

### Automated Scaling Scripts

#### **ClickHouse Scale Down Script**
```bash
#!/bin/bash
# save as: scale-clickhouse-down.sh

echo "Scaling down ClickHouse..."
kubectl scale statefulset chi-homelab-clickhouse-homelab-cluster-0-0 --replicas=0 -n clickhouse

echo "Waiting for pods to terminate..."
kubectl wait --for=delete pod -l clickhouse.altinity.com/chi=homelab-clickhouse -n clickhouse --timeout=120s

echo "ClickHouse scaled down. Resources freed:"
kubectl top nodes
```

#### **ClickHouse Scale Up Script**
```bash
#!/bin/bash
# save as: scale-clickhouse-up.sh

echo "Scaling up ClickHouse..."
kubectl scale statefulset chi-homelab-clickhouse-homelab-cluster-0-0 --replicas=1 -n clickhouse

echo "Waiting for ClickHouse to be ready..."
kubectl wait --for=condition=ready pod -l clickhouse.altinity.com/chi=homelab-clickhouse -n clickhouse --timeout=300s

echo "ClickHouse is ready!"
echo "Web UI: http://10.0.0.248:8123/play"
echo "Dashboard: http://10.0.0.248:8123/dashboard"

# Test connectivity
kubectl exec -n clickhouse chi-homelab-clickhouse-homelab-cluster-0-0-0 -- clickhouse-client --query "SELECT 'ClickHouse is ready!' as status"
```

### Resource Monitoring

#### **Check Resource Usage**
```bash
# Check node resource usage
kubectl top nodes

# Check pod resource usage
kubectl top pods -n clickhouse
kubectl top pods -n iceberg-system
kubectl top pods -n nats
kubectl top pods -n monitoring

# Check resource requests/limits
kubectl describe nodes | grep -A 5 "Allocated resources"
```

#### **Identify Resource-Heavy Services**
```bash
# Find pods using most CPU
kubectl top pods --all-namespaces --sort-by=cpu

# Find pods using most memory
kubectl top pods --all-namespaces --sort-by=memory

# Check persistent volume usage
kubectl get pvc --all-namespaces
```

### Considerations

#### **Data Persistence**
- **ClickHouse**: Data persists in Longhorn volumes when scaled to zero
- **NATS**: JetStream data persists in persistent volumes
- **Trino**: Stateless - no data loss when scaled down
- **Monitoring**: Prometheus data persists, Grafana dashboards persist

#### **Startup Times**
- **ClickHouse**: ~30-60 seconds to fully initialize
- **NATS**: ~10-20 seconds
- **Trino**: ~20-30 seconds
- **Monitoring**: ~30-60 seconds for full stack

#### **Dependencies**
- Scale up **NATS** before services that depend on messaging
- Scale up **ClickHouse** before analytics workloads
- Keep **Prometheus** running if you want continuous monitoring
- **Longhorn** and **MinIO** should remain running (foundation services)

### Best Practices

1. **Scale down in reverse dependency order**: Analytics → Messaging → Storage
2. **Scale up in dependency order**: Storage → Messaging → Analytics
3. **Keep foundation services running**: Longhorn, MinIO, MetalLB, HAProxy
4. **Monitor resource usage** before and after scaling
5. **Test connectivity** after scaling up
6. **Document your scaling procedures** for your specific use cases

## Security Considerations

### Current Configuration
- **Authentication**: None required (default user with empty password)
- **Network Access**: Open access for homelab convenience (configured for ::/0)
- **TLS**: Available via HAProxy ingress with self-signed certificates
- **Network Isolation**: Protected by homelab network boundaries

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

## Complete Data Pipeline Example

### Real-time IoT Pipeline with NATS and Iceberg

**Step 1: Create storage table**:
```sql
CREATE DATABASE IF NOT EXISTS iot;

CREATE TABLE iot.sensor_readings (
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

**Step 2: Create NATS stream reader**:
```sql
CREATE TABLE iot.nats_sensor_stream (
    timestamp DateTime,
    sensor_id String,
    location String,
    temperature Float32,
    humidity Float32,
    pressure Float32
) ENGINE = NATS
SETTINGS
    nats_url = 'nats://nats.nats.svc.cluster.local:4222',
    nats_subjects = 'iot.sensors.*',
    nats_format = 'JSONEachRow';
```

**Step 3: Create materialized view for real-time ingestion**:
```sql
CREATE MATERIALIZED VIEW iot.realtime_ingestion TO iot.sensor_readings AS
SELECT * FROM iot.nats_sensor_stream;
```

**Step 4: Create Iceberg connection for historical data**:
```sql
CREATE TABLE iot.historical_readings (
    timestamp DateTime,
    sensor_id String,
    location String,
    temperature Float32,
    humidity Float32,
    pressure Float32
) ENGINE = Iceberg('http://iceberg-rest-catalog-lb.iceberg-system.svc.cluster.local:8181', 'homelab.iot.historical_sensors');
```

**Step 5: Query combined real-time and historical data**:
```sql
-- Combined analytics query
WITH realtime_data AS (
    SELECT
        location,
        avg(temperature) as avg_temp,
        count() as readings
    FROM iot.sensor_readings
    WHERE timestamp >= now() - INTERVAL 1 HOUR
    GROUP BY location
),
historical_data AS (
    SELECT
        location,
        avg(temperature) as avg_temp,
        count() as readings
    FROM iot.historical_readings
    WHERE timestamp >= now() - INTERVAL 24 HOUR
    GROUP BY location
)
SELECT
    r.location,
    r.avg_temp as realtime_avg,
    h.avg_temp as historical_avg,
    r.readings as realtime_count,
    h.readings as historical_count
FROM realtime_data r
FULL OUTER JOIN historical_data h ON r.location = h.location;
```

## Use Cases

### IoT Data Analytics
- Real-time sensor data ingestion via NATS engine
- Time-series analysis with MergeTree partitioning
- Anomaly detection using statistical functions
- Dashboard visualization with Grafana integration

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
