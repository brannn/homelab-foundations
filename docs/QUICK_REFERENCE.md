# Homelab Foundations - Quick Reference

**Version**: 1.1
**Date**: 2025-07-14
**Author**: Community Contributors
**Status**: Active

## Overview

Quick reference guide for common operations and access information for the homelab Kubernetes cluster.

## Essential Commands

### Cluster Access
```bash
export KUBECONFIG=~/.kube/homelab
kubectl cluster-info
```

### Service URLs
- **HAProxy Ingress**: http://10.0.0.245 (HTTP/HTTPS ingress controller)
- **Pi-hole DNS**: http://10.0.0.249/admin (admin/homelab123)
- **Grafana**: http://10.0.0.243:3000 (admin/grafana123)
- **MinIO Console**: http://10.0.0.242:9090 (HTTP-only)
- **MinIO S3 API**: http://10.0.0.241:80 (HTTP-only)
- **Longhorn UI**: http://10.0.0.240 (via LoadBalancer)
- **Traefik (K3s)**: http://10.0.0.244 (default K3s ingress)
- **Trino Web UI**: http://10.0.0.246:8080 (no authentication)
- **Iceberg REST API**: http://10.0.0.247:8181 (catalog management)
- **ClickHouse**: http://10.0.0.248:8123 (HTTP interface)
- **Temporal Web UI**: http://10.0.0.250:8080 (workflow monitoring)
- **Temporal gRPC**: grpc://10.0.0.250:7233 (client connections)
- **NATS Monitoring**: http://nats.homelab.local (metrics and health)

### Hostname Access (via Pi-hole DNS)
Configure Pi-hole (10.0.0.249) as secondary DNS server for hostname resolution:
- **Grafana**: http://grafana.homelab.local
- **ClickHouse**: http://clickhouse.homelab.local
- **Trino**: http://trino.homelab.local
- **Iceberg REST**: http://iceberg.homelab.local
- **Longhorn**: http://longhorn.homelab.local
- **NATS**: http://nats.homelab.local
- **Temporal**: http://temporal.homelab.local
- **MinIO Console**: http://minio-console.homelab.local
- **MinIO S3**: http://minio.homelab.local
- **Pi-hole**: http://pihole.homelab.local/admin

### Hybrid GitOps Workflow

**Flux-managed components** (MetalLB, HAProxy, cert-manager, Monitoring):
```bash
# Make changes, then:
git add .
git commit -m "description"
git push origin main

# Force sync if needed:
flux reconcile source git flux-system
```

**MinIO** (Helm-managed, HTTP-only):
```bash
# Edit files in minio/ directory, then:
cd minio/
helm upgrade --install minio-tenant minio/tenant -n minio-tenant -f tenant-values.yaml
```

### Check System Status
```bash
# Flux status
flux get all

# All pods
kubectl get pods -A

# Services with external IPs
kubectl get svc -A | grep LoadBalancer

# Storage health
kubectl get volumes -n longhorn-system

# MinIO status
kubectl get tenant -n minio-tenant
kubectl get svc -n minio-tenant

# Monitoring status
kubectl get pods -n monitoring
kubectl get svc -n monitoring

# cert-manager status
kubectl get pods -n cert-manager
kubectl get clusterissuers

# HAProxy ingress status
kubectl get pods -n haproxy-controller
kubectl get svc -n haproxy-controller

# Iceberg PostgreSQL backend status
kubectl get clusters.postgresql.cnpg.io -n iceberg-system
kubectl get pods -n iceberg-system
```

## Trino Analytics

### Quick Access
```bash
# Download Trino CLI
curl -o trino https://repo1.maven.org/maven2/io/trino/trino-cli/476/trino-cli-476-executable.jar
chmod +x trino

# Connect to cluster
./trino --server http://10.0.0.246:8080 --user admin
```

### Essential Queries
```sql
-- Show catalogs and schemas
SHOW CATALOGS;
SHOW SCHEMAS FROM iceberg;

-- Create schema
CREATE SCHEMA iceberg.analytics WITH (location = 's3://iceberg/analytics/');

-- Create table
CREATE TABLE iceberg.analytics.example (
    id BIGINT,
    name VARCHAR,
    created_at TIMESTAMP(6) WITH TIME ZONE
) WITH (format = 'PARQUET', partitioning = ARRAY['date(created_at)']);

-- Query data
SELECT * FROM iceberg.analytics.example;
```

### API Access
```bash
# Check cluster status
curl -H "X-Trino-User: admin" http://10.0.0.246:8080/v1/info

# Submit query
curl -X POST http://10.0.0.246:8080/v1/statement \
  -H "Content-Type: application/json" \
  -H "X-Trino-User: admin" \
  -d '{"query":"SHOW CATALOGS"}'

# Check Iceberg REST Catalog
curl -s http://10.0.0.247:8181/v1/config
```

### PostgreSQL Backend Operations
```bash
# Check PostgreSQL cluster status
kubectl get clusters.postgresql.cnpg.io -n iceberg-system

# Connect to Iceberg metadata database
kubectl exec -it iceberg-postgres-1 -n iceberg-system -- psql -U postgres -d iceberg_catalog

# Check Iceberg metadata tables
kubectl exec -it iceberg-postgres-1 -n iceberg-system -- psql -U postgres -d iceberg_catalog -c "\dt"

# Monitor PostgreSQL resource usage
kubectl top pods -n iceberg-system -l cnpg.io/cluster=iceberg-postgres
```

## NATS + JetStream Messaging

### Quick Access
```bash
# Get NATS box pod name
NATS_BOX=$(kubectl get pods -n nats -l app=nats-box -o jsonpath='{.items[0].metadata.name}')

# Connect to NATS
kubectl exec -n nats $NATS_BOX -- nats --server nats://nats:4222 server info
```

### Essential Commands
```bash
# List streams
kubectl exec -n nats $NATS_BOX -- nats --server nats://nats:4222 stream ls

# Create IoT stream
kubectl exec -n nats $NATS_BOX -- nats --server nats://nats:4222 stream add iot-sensors \
  --subjects "sensors.>" --storage file --retention limits --max-age=24h --replicas=1 --defaults

# Publish test message
kubectl exec -n nats $NATS_BOX -- nats --server nats://nats:4222 pub sensors.temperature.room1 "22.5"

# Subscribe to messages
kubectl exec -n nats $NATS_BOX -- nats --server nats://nats:4222 sub sensors.>
```

### Monitoring
```bash
# Check JetStream status
kubectl exec -n nats $NATS_BOX -- nats --server nats://nats:4222 stream info iot-sensors

# View metrics
curl http://10.0.0.248:8222/varz
```

## Temporal Workflow System

### Quick Access
```bash
# Check Temporal services
kubectl get pods -n temporal-system

# Check PostgreSQL cluster
kubectl get clusters.postgresql.cnpg.io -n temporal-system

# Check LoadBalancer services
kubectl get svc -n temporal-system | grep LoadBalancer
```

### Essential Commands
```bash
# Scale to zero (save ~2.3Gi memory)
kubectl scale deployment -n temporal-system --replicas=0 \
  temporal-frontend temporal-history temporal-matching temporal-worker temporal-web

# Scale up from zero
kubectl scale deployment -n temporal-system --replicas=1 \
  temporal-frontend temporal-history temporal-matching temporal-worker temporal-web

# Connect to PostgreSQL
kubectl exec -it temporal-postgres-1 -n temporal-system -- psql -U temporal -d temporal

# Check backup status
kubectl get backups -n temporal-system
```

### Monitoring
```bash
# Check resource usage
kubectl top pods -n temporal-system

# View service logs
kubectl logs -n temporal-system -l app.kubernetes.io/name=temporal

# Test connectivity
curl -s http://10.0.0.250:8080 | head -5
```

## Common Fixes

### Volume Degraded (Single Node)
```bash
kubectl patch volume <volume-name> -n longhorn-system \
  --type='merge' -p='{"spec":{"numberOfReplicas":1}}'
```

### Force Flux Sync
```bash
flux reconcile source git flux-system
flux reconcile kustomization flux-system
```

### MinIO Issues
```bash
# Redeploy MinIO
cd minio && helm upgrade --install minio-tenant minio/tenant -n minio-tenant -f tenant-values.yaml

# Check operator logs
kubectl logs -n minio-operator deployment/minio-operator

# Check tenant logs
kubectl logs -n minio-tenant minio-tenant-pool-0-0 -c minio
```

### Check Logs
```bash
# Flux logs
flux logs --follow

# Pod logs
kubectl logs <pod-name> -n <namespace>

# Previous pod logs
kubectl logs <pod-name> -n <namespace> --previous
```

## Monitoring

### Resource Usage
```bash
kubectl top nodes
kubectl top pods -A
```

### Storage Status
```bash
# Longhorn volumes
kubectl get volumes -n longhorn-system

# PVCs across all namespaces
kubectl get pvc -A

# Storage classes
kubectl get storageclass
```

### Network Status
```bash
# MetalLB status
kubectl get pods -n metallb-system

# IP address pools
kubectl get ipaddresspool -n metallb-system

# LoadBalancer services
kubectl get svc -A --field-selector spec.type=LoadBalancer
```

## Emergency Commands

### Restart Flux
```bash
kubectl rollout restart deployment -n flux-system
```

### Restart Longhorn
```bash
kubectl rollout restart deployment longhorn-ui -n longhorn-system
kubectl rollout restart daemonset longhorn-manager -n longhorn-system
```

### Restart MinIO
```bash
# Restart operator
kubectl rollout restart deployment minio-operator -n minio-operator

# Restart tenant
kubectl delete pod minio-tenant-pool-0-0 -n minio-tenant
```

### Redeploy MinIO
```bash
cd minio/
helm upgrade --install minio-tenant minio/tenant -n minio-tenant -f tenant-values.yaml
```

## File Locations

### Local Files
- **Kubeconfig**: `~/.kube/homelab`
- **SSH Key**: `~/.ssh/github_stylograph`
- **Repository**: `/Users/bran/PycharmProjects/homelab-foundations`

### Important Configs
- **Flux System**: `clusters/um890/flux-system/`
- **MetalLB**: `clusters/um890/metallb/`
- **HAProxy Ingress**: `clusters/um890/haproxy-ingress/`
- **cert-manager**: `clusters/um890/cert-manager/`
- **Monitoring**: `clusters/um890/monitoring/`
- **Longhorn**: `longhorn/` (Helmfile-managed)
- **MinIO**: `minio/` (Helmfile-managed)

## When Things Break

1. **Check Flux first**: `flux get all`
2. **Check pod status**: `kubectl get pods -A`
3. **Check MinIO**: `cd minio && helmfile status`
4. **Check recent changes**: `git log --oneline -10`
5. **Check logs**: `flux logs --follow`
6. **Rollback if needed**: `git revert <commit>`

## Resources

- **Documentation**: `docs/` directory in repository
- **Architecture**: `docs/ARCHITECTURE.md`
- **Setup Guide**: `docs/SETUP.md`
- **Full Runbook**: `docs/OPERATIONAL_RUNBOOK.md`
