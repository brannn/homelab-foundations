# IP Address Assignments

**Version**: 1.0
**Date**: 2025-07-15
**Author**: Community Contributors
**Status**: Active

## Overview

This document defines the permanent IP address assignments for all LoadBalancer services in the homelab-foundations environment using MetalLB.

## MetalLB Configuration

### IP Address Pools

The MetalLB configuration uses dedicated pools for different service categories:

#### **Ingress Pool (10.0.0.244-245)**
- **10.0.0.244**: Traefik (K3s default ingress)
- **10.0.0.245**: HAProxy ingress controller

#### **Storage Pool (10.0.0.240-242)**
- **10.0.0.240**: MinIO S3 API
- **10.0.0.241**: MinIO Console
- **10.0.0.242**: Longhorn UI

#### **Analytics Pool (10.0.0.246-248)**
- **10.0.0.246**: Trino Query Engine
- **10.0.0.247**: Iceberg REST Catalog
- **10.0.0.248**: ClickHouse Analytics Database

#### **Monitoring Pool (10.0.0.243)**
- **10.0.0.243**: Grafana Dashboard

#### **Dynamic Pool (10.0.0.249-250)**
- **10.0.0.249-250**: Reserved for future services

## Service Assignments

### **Ingress Controllers**

#### **HAProxy Ingress Controller**
- **IP**: 10.0.0.245 (FIXED)
- **Ports**: 80 (HTTP), 443 (HTTPS), 1024 (stats), 6060 (admin)
- **Pool**: ingress-pool
- **Configuration**: `clusters/um890/haproxy-ingress/helmrelease.yaml`
- **Access**: 
  - HTTP: http://10.0.0.245
  - HTTPS: https://10.0.0.245
  - Stats: http://10.0.0.245:1024

#### **Traefik (K3s Default)**
- **IP**: 10.0.0.244 (FIXED)
- **Ports**: 80 (HTTP), 443 (HTTPS)
- **Pool**: ingress-pool

### **Storage Services**

#### **MinIO Object Storage**
- **S3 API IP**: 10.0.0.240 (FIXED)
- **Console IP**: 10.0.0.241 (FIXED)
- **Pool**: storage-pool
- **Access**:
  - S3 API: https://10.0.0.240:443
  - Console: https://10.0.0.241:9443

#### **Longhorn Storage UI**
- **IP**: 10.0.0.242 (FIXED)
- **Pool**: storage-pool
- **Access**: http://10.0.0.242:80

### **Analytics Services**

#### **Trino Query Engine**
- **IP**: 10.0.0.246 (FIXED)
- **Pool**: analytics-pool
- **Configuration**: `clusters/um890/trino/services.yaml`
- **Access**: http://10.0.0.246:8080

#### **Iceberg REST Catalog**
- **IP**: 10.0.0.247 (FIXED)
- **Pool**: analytics-pool
- **Configuration**: `clusters/um890/trino/services.yaml`
- **Access**: http://10.0.0.247:8181

#### **ClickHouse Analytics Database**
- **IP**: 10.0.0.248 (FIXED)
- **Pool**: analytics-pool
- **Configuration**: `clusters/um890/clickhouse/services.yaml`
- **Access**:
  - HTTP API: http://10.0.0.248:8123
  - SQL Editor: http://10.0.0.248:8123/play
  - Dashboard: http://10.0.0.248:8123/dashboard
  - Native Protocol: 10.0.0.248:9000
  - Metrics: http://10.0.0.248:9363

### **Monitoring Services**

#### **Grafana Dashboard**
- **IP**: 10.0.0.243 (FIXED)
- **Pool**: monitoring-pool
- **Access**: http://10.0.0.243:3000

## Implementation Details

### **MetalLB Pool Configuration**

Each service is assigned to a specific pool using annotations:

```yaml
metadata:
  annotations:
    metallb.universe.tf/loadBalancerIPs: "10.0.0.XXX"
    metallb.universe.tf/address-pool: "pool-name"
```

### **Service Configuration Examples**

#### **HAProxy Ingress**
```yaml
# clusters/um890/haproxy-ingress/helmrelease.yaml
service:
  type: LoadBalancer
  loadBalancerIP: 10.0.0.245
  annotations:
    metallb.universe.tf/loadBalancerIPs: "10.0.0.245"
```

#### **ClickHouse Service**
```yaml
# clusters/um890/clickhouse/services.yaml
metadata:
  annotations:
    metallb.universe.tf/loadBalancerIPs: "10.0.0.248"
    metallb.universe.tf/address-pool: "analytics-pool"
```

## Benefits of Fixed IP Assignments

### **Operational Benefits**
- **Predictable Access**: Services always available at known IPs
- **Bookmark Stability**: Web UI bookmarks remain valid after reboots
- **DNS Configuration**: Can configure local DNS with fixed mappings
- **Monitoring**: Consistent endpoints for health checks
- **Documentation**: Clear, stable reference points

### **Network Benefits**
- **Firewall Rules**: Can create specific rules for known IPs
- **Load Balancing**: External load balancers can use fixed targets
- **Service Discovery**: Applications can rely on consistent endpoints
- **Troubleshooting**: Easier to diagnose network issues

## Maintenance Procedures

### **Adding New Services**
1. Choose an available IP from the dynamic pool (10.0.0.249-250)
2. Create a new pool if needed for service category
3. Update service configuration with fixed IP annotation
4. Update this documentation

### **Changing IP Assignments**
1. Update MetalLB pool configuration
2. Update service annotations
3. Restart affected services
4. Update documentation and monitoring

### **Pool Management**
```bash
# Check current IP assignments
kubectl get svc --all-namespaces -o wide | grep LoadBalancer

# Check MetalLB pool status
kubectl get ipaddresspool -n metallb-system

# View MetalLB logs
kubectl logs -n metallb-system deployment/controller
```

## Troubleshooting

### **IP Assignment Issues**
```bash
# Check MetalLB controller logs
kubectl logs -n metallb-system deployment/controller

# Verify pool configuration
kubectl describe ipaddresspool -n metallb-system

# Check service annotations
kubectl describe svc <service-name> -n <namespace>
```

### **Service Not Getting Fixed IP**
1. Verify pool has available IPs
2. Check service annotation syntax
3. Restart MetalLB controller if needed
4. Delete and recreate service if necessary

## Future Expansion

### **Available IPs**
- **10.0.0.249-250**: Available for new services
- **Additional ranges**: Can expand MetalLB pool if needed

### **Recommended Additions**
- **10.0.0.249**: Reserved for additional ingress controller
- **10.0.0.250**: Reserved for development/testing services

## Security Considerations

### **Network Isolation**
- All IPs are in private RFC1918 range (10.0.0.0/24)
- Services isolated by Kubernetes network policies
- HAProxy provides single ingress point for web services

### **Access Control**
- Fixed IPs enable consistent firewall rules
- Can implement IP-based access controls
- Monitoring can track access patterns by IP

This IP assignment strategy provides stability, predictability, and easier management for the homelab-foundations environment.
