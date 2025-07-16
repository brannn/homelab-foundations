# Resource Management Guide

**Version**: 1.0
**Date**: 2025-07-15
**Author**: Community Contributors
**Status**: Active

## Overview

This guide covers resource management strategies for the homelab-foundations environment, including scaling services to zero for resource conservation and scaling them back up when needed.

## Resource Conservation Strategy

### Foundation vs Application Services

**Foundation Services (Keep Running)**:
- **Longhorn CSI**: Storage foundation - required for all persistent volumes
- **MinIO**: Object storage - required for data lake operations
- **MetalLB**: Load balancer - required for service access
- **HAProxy Ingress**: Ingress controller - required for web access
- **Pi-hole DNS**: DNS resolution - required for .homelab.local domains
- **cert-manager**: Certificate management - lightweight, keep running

**Application Services (Can Scale to Zero)**:
- **ClickHouse**: Analytics database - 2Gi memory when running
- **Trino**: Query engine - ~4Gi memory total (coordinator + worker)
- **NATS**: Messaging system - 512Mi memory + JetStream storage
- **Monitoring Stack**: Prometheus (~2Gi) + Grafana (~512Mi)

## Scaling Commands by Service

### ClickHouse Analytics Database

**Scale Down**:
```bash
# Method 1: Scale StatefulSet (recommended)
kubectl scale statefulset chi-homelab-clickhouse-homelab-cluster-0-0 --replicas=0 -n clickhouse

# Method 2: Suspend ClickHouseInstallation
kubectl patch clickhouseinstallation homelab-clickhouse -n clickhouse --type='merge' -p='{"spec":{"stop":"yes"}}'

# Verify scaled down
kubectl get pods -n clickhouse
```

**Scale Up**:
```bash
# Method 1: Scale StatefulSet
kubectl scale statefulset chi-homelab-clickhouse-homelab-cluster-0-0 --replicas=1 -n clickhouse

# Method 2: Resume ClickHouseInstallation
kubectl patch clickhouseinstallation homelab-clickhouse -n clickhouse --type='merge' -p='{"spec":{"stop":"no"}}'

# Wait for ready
kubectl wait --for=condition=ready pod -l clickhouse.altinity.com/chi=homelab-clickhouse -n clickhouse --timeout=300s

# Test connectivity
kubectl exec -n clickhouse chi-homelab-clickhouse-homelab-cluster-0-0-0 -- clickhouse-client --query "SELECT 1"
```

### Trino Query Engine

**Scale Down**:
```bash
# Scale down coordinator and worker
kubectl scale deployment trino-coordinator --replicas=0 -n iceberg-system
kubectl scale deployment trino-worker --replicas=0 -n iceberg-system

# Verify scaled down
kubectl get pods -n iceberg-system | grep trino
```

**Scale Up**:
```bash
# Scale up coordinator first, then worker
kubectl scale deployment trino-coordinator --replicas=1 -n iceberg-system
kubectl wait --for=condition=available deployment/trino-coordinator -n iceberg-system --timeout=120s

kubectl scale deployment trino-worker --replicas=1 -n iceberg-system
kubectl wait --for=condition=available deployment/trino-worker -n iceberg-system --timeout=120s

# Test connectivity
kubectl exec -n iceberg-system deployment/trino-coordinator -- trino --execute "SELECT 1"
```

### NATS Messaging System

**Scale Down**:
```bash
# Scale down NATS server
kubectl scale statefulset nats --replicas=0 -n nats

# Verify scaled down
kubectl get pods -n nats
```

**Scale Up**:
```bash
# Scale up NATS
kubectl scale statefulset nats --replicas=1 -n nats

# Wait for ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=nats -n nats --timeout=120s

# Test connectivity
kubectl exec -n nats nats-0 -- nats server check connection
```

### Monitoring Stack

**Scale Down Grafana Only**:
```bash
# Keep Prometheus running, scale down Grafana
kubectl scale deployment grafana --replicas=0 -n monitoring

# Verify
kubectl get pods -n monitoring | grep grafana
```

**Scale Down Full Monitoring Stack**:
```bash
# Scale down Grafana
kubectl scale deployment grafana --replicas=0 -n monitoring

# Scale down Prometheus
kubectl scale statefulset prometheus-kube-prometheus-stack-prometheus --replicas=0 -n monitoring

# Scale down AlertManager (if present)
kubectl scale statefulset alertmanager-kube-prometheus-stack-alertmanager --replicas=0 -n monitoring

# Verify
kubectl get pods -n monitoring
```

**Scale Up Monitoring Stack**:
```bash
# Scale up Prometheus first
kubectl scale statefulset prometheus-kube-prometheus-stack-prometheus --replicas=1 -n monitoring
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=prometheus -n monitoring --timeout=180s

# Scale up AlertManager
kubectl scale statefulset alertmanager-kube-prometheus-stack-alertmanager --replicas=1 -n monitoring

# Scale up Grafana
kubectl scale deployment grafana --replicas=1 -n monitoring
kubectl wait --for=condition=available deployment/grafana -n monitoring --timeout=120s
```

## Automation Scripts

### Complete Scale Down Script

```bash
#!/bin/bash
# save as: homelab-scale-down.sh

echo "=== Homelab Scale Down ==="
echo "Scaling down application services to conserve resources..."

# Scale down analytics services
echo "Scaling down ClickHouse..."
kubectl scale statefulset chi-homelab-clickhouse-homelab-cluster-0-0 --replicas=0 -n clickhouse

echo "Scaling down Trino..."
kubectl scale deployment trino-coordinator --replicas=0 -n iceberg-system
kubectl scale deployment trino-worker --replicas=0 -n iceberg-system

# Scale down messaging
echo "Scaling down NATS..."
kubectl scale statefulset nats --replicas=0 -n nats

# Scale down monitoring (optional - keep Prometheus for basic monitoring)
echo "Scaling down Grafana..."
kubectl scale deployment grafana --replicas=0 -n monitoring

echo "Waiting for pods to terminate..."
sleep 30

echo "=== Scale Down Complete ==="
echo "Resources freed. Foundation services still running:"
kubectl get pods -n longhorn-system | grep -c Running
kubectl get pods -n minio-tenant | grep -c Running
kubectl get pods -n metallb-system | grep -c Running

echo "Current resource usage:"
kubectl top nodes
```

### Complete Scale Up Script

```bash
#!/bin/bash
# save as: homelab-scale-up.sh

echo "=== Homelab Scale Up ==="
echo "Scaling up application services..."

# Scale up messaging first (dependency for others)
echo "Scaling up NATS..."
kubectl scale statefulset nats --replicas=1 -n nats
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=nats -n nats --timeout=120s

# Scale up analytics services
echo "Scaling up ClickHouse..."
kubectl scale statefulset chi-homelab-clickhouse-homelab-cluster-0-0 --replicas=1 -n clickhouse
kubectl wait --for=condition=ready pod -l clickhouse.altinity.com/chi=homelab-clickhouse -n clickhouse --timeout=300s

echo "Scaling up Trino..."
kubectl scale deployment trino-coordinator --replicas=1 -n iceberg-system
kubectl wait --for=condition=available deployment/trino-coordinator -n iceberg-system --timeout=120s
kubectl scale deployment trino-worker --replicas=1 -n iceberg-system
kubectl wait --for=condition=available deployment/trino-worker -n iceberg-system --timeout=120s

# Scale up monitoring
echo "Scaling up Grafana..."
kubectl scale deployment grafana --replicas=1 -n monitoring
kubectl wait --for=condition=available deployment/grafana -n monitoring --timeout=120s

echo "=== Scale Up Complete ==="
echo "Testing service connectivity..."

# Test services
echo "Testing ClickHouse..."
kubectl exec -n clickhouse chi-homelab-clickhouse-homelab-cluster-0-0-0 -- clickhouse-client --query "SELECT 'ClickHouse OK' as status" 2>/dev/null || echo "ClickHouse not ready yet"

echo "Testing Trino..."
kubectl exec -n iceberg-system deployment/trino-coordinator -- trino --execute "SELECT 'Trino OK' as status" 2>/dev/null || echo "Trino not ready yet"

echo "Service URLs:"
echo "ClickHouse Play: http://10.0.0.248:8123/play"
echo "ClickHouse Dashboard: http://10.0.0.248:8123/dashboard"
echo "Trino UI: http://10.0.0.246:8080"
echo "Grafana: http://10.0.0.241:3000"

echo "Current resource usage:"
kubectl top nodes
```

## Resource Monitoring

### Check Current Resource Usage

```bash
# Node resource usage
kubectl top nodes

# Pod resource usage by namespace
kubectl top pods -n clickhouse
kubectl top pods -n iceberg-system  
kubectl top pods -n nats
kubectl top pods -n monitoring

# All pods sorted by resource usage
kubectl top pods --all-namespaces --sort-by=memory
kubectl top pods --all-namespaces --sort-by=cpu
```

### Identify Scaling Candidates

```bash
# Find resource-heavy pods
kubectl top pods --all-namespaces --sort-by=memory | head -10

# Check resource requests vs limits
kubectl describe nodes | grep -A 10 "Allocated resources"

# Check persistent volume usage
kubectl get pvc --all-namespaces -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,SIZE:.spec.resources.requests.storage,STORAGECLASS:.spec.storageClassName
```

## Best Practices

### Scaling Order

**Scale Down Order** (reverse dependency):
1. Analytics services (ClickHouse, Trino)
2. Messaging services (NATS)
3. Monitoring services (Grafana, optionally Prometheus)
4. Never scale: Foundation services (Longhorn, MinIO, MetalLB, HAProxy)

**Scale Up Order** (dependency order):
1. Foundation services (should already be running)
2. Messaging services (NATS)
3. Analytics services (ClickHouse, Trino)
4. Monitoring services (Prometheus, Grafana)

### Resource Conservation Tips

1. **Selective Scaling**: Scale down only services not currently needed
2. **Keep Prometheus**: For basic cluster monitoring even when other services are down
3. **Monitor Dependencies**: Some services depend on others (e.g., analytics may need NATS)
4. **Test After Scaling**: Always verify service functionality after scaling up
5. **Document Your Patterns**: Create custom scripts for your specific usage patterns

### Startup Time Expectations

- **NATS**: 10-20 seconds
- **ClickHouse**: 30-60 seconds  
- **Trino**: 20-30 seconds (coordinator), 15-25 seconds (worker)
- **Grafana**: 15-30 seconds
- **Prometheus**: 30-90 seconds (depends on data volume)

### Data Persistence

All services maintain data persistence when scaled to zero:
- **ClickHouse**: Data in Longhorn persistent volumes
- **NATS**: JetStream data in persistent volumes  
- **Trino**: Stateless (no data stored)
- **Prometheus**: Metrics data in persistent volumes
- **Grafana**: Dashboards and settings in persistent volumes

This allows safe scaling without data loss.
