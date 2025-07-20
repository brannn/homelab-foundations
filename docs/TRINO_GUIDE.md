# Trino Analytics Engine Guide

**Version**: 1.0
**Date**: 2025-07-14
**Author**: Community Contributors (with Augment Agent)
**Status**: Active

## Overview

This guide covers the Trino distributed SQL query engine deployment in homelab-foundations, including integration with Apache Iceberg for modern data lake analytics.

## Architecture

### Cluster Configuration
- **Coordinator**: 1 node (4Gi RAM, 3g heap, 1 CPU)
- **Worker**: 1 node (6Gi RAM, 5g heap, 2 CPU)
- **Total Memory**: 10Gi cluster allocation
- **Query Memory**: 8GB total, 2GB coordinator + 3.5GB worker per node

### Components
- **Trino Coordinator**: Query planning, client connections, metadata
- **Trino Worker**: Query execution, data processing
- **Iceberg REST Catalog**: Table metadata, schema evolution, ACID transactions
- **PostgreSQL Backend**: CNPG-managed database for Iceberg metadata (concurrent-safe)
- **MinIO Integration**: S3-compatible storage backend (HTTP-only)

## Access Information

### Web UI
- **URL**: http://10.0.0.246:8080
- **Authentication**: None (open access)
- **Features**: Query monitoring, cluster status, execution plans

### API Access
- **Endpoint**: http://10.0.0.246:8080
- **Authentication**: X-Trino-User header (any username)
- **Example**: `curl -H "X-Trino-User: admin" http://10.0.0.246:8080/v1/info`

### CLI Access
```bash
# Download Trino CLI
curl -o trino https://repo1.maven.org/maven2/io/trino/trino-cli/476/trino-cli-476-executable.jar
chmod +x trino

# Connect to cluster
./trino --server http://10.0.0.246:8080 --user admin
```

## Available Catalogs

### Iceberg Catalog
- **Name**: `iceberg`
- **Type**: Apache Iceberg with REST catalog
- **Metadata Backend**: PostgreSQL via CNPG (concurrent-safe)
- **Storage**: MinIO S3 backend (HTTP-only for homelab simplicity)
- **Features**: ACID transactions, schema evolution, time travel
- **Concurrency**: Supports multiple simultaneous write operations
- **Status**: ✅ Production ready with PostgreSQL backend for high concurrency

### Built-in Catalogs
- **memory**: In-memory tables for testing
- **tpch**: TPC-H benchmark data
- **tpcds**: TPC-DS benchmark data

## PostgreSQL Backend Architecture

### Overview
The Iceberg REST Catalog uses a PostgreSQL database backend managed by CloudNativePG (CNPG) to store table metadata. This architecture replaces the default SQLite backend to support high-concurrency workloads.

### Benefits
- **Concurrent Operations**: Supports multiple simultaneous read/write operations
- **ACID Compliance**: Full transactional support for metadata operations
- **Scalability**: No single-writer bottleneck like SQLite
- **Reliability**: Automated backups and point-in-time recovery via CNPG
- **Monitoring**: Full PostgreSQL metrics integration with Prometheus/Grafana

### Components
- **PostgreSQL Cluster**: `iceberg-postgres` (single-node, 512Mi memory)
- **Database**: `iceberg_catalog`
- **User**: `iceberg_user`
- **Backup**: Automated to MinIO S3 storage
- **Connection**: `jdbc:postgresql://iceberg-postgres-rw.iceberg-system.svc.cluster.local:5432/iceberg_catalog`

### Operational Commands
```bash
# Check PostgreSQL cluster status
kubectl get clusters.postgresql.cnpg.io -n iceberg-system

# Connect to database
kubectl exec -it iceberg-postgres-1 -n iceberg-system -- psql -U postgres -d iceberg_catalog

# Check Iceberg metadata tables
kubectl exec -it iceberg-postgres-1 -n iceberg-system -- psql -U postgres -d iceberg_catalog -c "\dt"

# Monitor resource usage
kubectl top pods -n iceberg-system
```

## Getting Started Examples

### Basic Queries

```sql
-- Show available catalogs
SHOW CATALOGS;

-- Show schemas in iceberg catalog
SHOW SCHEMAS FROM iceberg;

-- Show current session info
SELECT current_user, current_catalog, current_schema;
```

### Schema Management

```sql
-- Create a new schema
CREATE SCHEMA iceberg.analytics
WITH (location = 's3://iceberg/analytics/');

-- Use the schema
USE iceberg.analytics;

-- Show tables in current schema
SHOW TABLES;
```

### Table Creation

```sql
-- Create a simple table
CREATE TABLE iceberg.analytics.sales (
    id BIGINT,
    product_name VARCHAR,
    price DECIMAL(10,2),
    quantity INTEGER,
    sale_date DATE,
    customer_id BIGINT
)
WITH (
    format = 'PARQUET',
    partitioning = ARRAY['sale_date']
);

-- Create table with more advanced features
CREATE TABLE iceberg.analytics.events (
    event_id UUID,
    user_id BIGINT,
    event_type VARCHAR,
    event_data JSON,
    created_at TIMESTAMP(6) WITH TIME ZONE,
    session_id VARCHAR
)
WITH (
    format = 'PARQUET',
    partitioning = ARRAY['date(created_at)', 'event_type']
);
```

### Data Insertion

```sql
-- Insert sample data
INSERT INTO iceberg.analytics.sales VALUES
(1, 'Laptop', 999.99, 1, DATE '2025-01-15', 1001),
(2, 'Mouse', 29.99, 2, DATE '2025-01-15', 1002),
(3, 'Keyboard', 79.99, 1, DATE '2025-01-16', 1001),
(4, 'Monitor', 299.99, 1, DATE '2025-01-16', 1003);

-- Insert with current timestamp
INSERT INTO iceberg.analytics.events VALUES
(UUID(), 1001, 'login', JSON '{"ip": "192.168.1.100"}', current_timestamp, 'sess_123'),
(UUID(), 1002, 'purchase', JSON '{"amount": 29.99, "product": "Mouse"}', current_timestamp, 'sess_456');
```

### Querying Data

```sql
-- Basic queries
SELECT * FROM iceberg.analytics.sales;

SELECT product_name, SUM(price * quantity) as total_revenue
FROM iceberg.analytics.sales
GROUP BY product_name
ORDER BY total_revenue DESC;

-- Date-based queries (leveraging partitioning)
SELECT *
FROM iceberg.analytics.sales
WHERE sale_date >= DATE '2025-01-16';

-- JSON data queries
SELECT 
    user_id,
    event_type,
    JSON_EXTRACT_SCALAR(event_data, '$.ip') as ip_address
FROM iceberg.analytics.events
WHERE event_type = 'login';
```

## Iceberg Advanced Features

### Time Travel Queries

```sql
-- Query table as of specific timestamp
SELECT * FROM iceberg.analytics.sales
FOR TIMESTAMP AS OF TIMESTAMP '2025-01-15 10:00:00';

-- Query table as of specific version
SELECT * FROM iceberg.analytics.sales
FOR VERSION AS OF 1;

-- Show table history
SELECT * FROM iceberg.analytics."sales$history";

-- Show table snapshots
SELECT * FROM iceberg.analytics."sales$snapshots";
```

### Schema Evolution

```sql
-- Add a new column
ALTER TABLE iceberg.analytics.sales
ADD COLUMN discount_percent DECIMAL(5,2);

-- Rename a column
ALTER TABLE iceberg.analytics.sales
RENAME COLUMN product_name TO item_name;

-- Drop a column
ALTER TABLE iceberg.analytics.sales
DROP COLUMN discount_percent;
```

### Partition Management

```sql
-- Show table partitions
SELECT * FROM iceberg.analytics."sales$partitions";

-- Optimize table (compact small files)
ALTER TABLE iceberg.analytics.sales EXECUTE optimize;

-- Expire old snapshots (cleanup)
ALTER TABLE iceberg.analytics.sales EXECUTE expire_snapshots(retention_threshold => '7d');
```

## Performance Optimization

### Query Optimization
```sql
-- Use EXPLAIN to understand query plans
EXPLAIN SELECT * FROM iceberg.analytics.sales WHERE sale_date = DATE '2025-01-15';

-- Analyze query performance
EXPLAIN (TYPE DISTRIBUTED) 
SELECT product_name, COUNT(*) 
FROM iceberg.analytics.sales 
GROUP BY product_name;
```

### Table Maintenance
```sql
-- Collect table statistics
ANALYZE TABLE iceberg.analytics.sales;

-- Show table statistics
SHOW STATS FOR iceberg.analytics.sales;
```

## Integration Examples

### Working with External Data

```sql
-- Create external table pointing to existing data
CREATE TABLE iceberg.analytics.external_data (
    id BIGINT,
    name VARCHAR,
    value DOUBLE
)
WITH (
    external_location = 's3://iceberg/external/',
    format = 'PARQUET'
);
```

### Data Pipeline Example

```sql
-- ETL pipeline: transform and load data
CREATE TABLE iceberg.analytics.daily_summary AS
SELECT 
    sale_date,
    COUNT(*) as total_sales,
    SUM(price * quantity) as total_revenue,
    AVG(price * quantity) as avg_order_value
FROM iceberg.analytics.sales
GROUP BY sale_date;
```

## Monitoring and Troubleshooting

### Query Monitoring
- **Web UI**: http://10.0.0.246:8080 - View running and completed queries
- **System Tables**: Query `system.runtime.queries` for programmatic access

### Common Issues

1. **Out of Memory**: Increase query memory limits or optimize queries
2. **Slow Queries**: Check partitioning, add table statistics
3. **Connection Issues**: Verify LoadBalancer IP and service endpoints

### Useful System Queries

```sql
-- Show running queries
SELECT query_id, state, query FROM system.runtime.queries WHERE state = 'RUNNING';

-- Show cluster nodes
SELECT * FROM system.runtime.nodes;

-- Show memory usage
SELECT * FROM system.runtime.memory_pools;
```

## Next Steps

1. **Set up external query tools** (DBeaver, DataGrip)
2. **Create data pipelines** using Iceberg's ACID properties
3. **Implement data governance** with schema evolution
4. **Scale cluster** by adding more worker nodes
5. **Integrate with BI tools** (Apache Superset, Grafana)

For more advanced configurations and troubleshooting, see the [Operational Runbook](OPERATIONAL_RUNBOOK.md).
