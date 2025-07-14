# Monitoring Stack Guide

**Version**: 1.0  
**Date**: 2025-07-13  
**Author**: Community Contributors  
**Status**: Active

## Overview

The homelab-foundations monitoring stack provides comprehensive observability for your Kubernetes cluster using industry-standard tools. The stack includes Prometheus for metrics collection, Grafana for visualization, and supporting components for complete cluster monitoring.

## Components

### Core Monitoring
- **Prometheus**: Time-series metrics database with 30-day retention
- **Grafana**: Visualization and dashboarding platform
- **Alertmanager**: Alert routing and management

### Metrics Collection
- **Node Exporter**: Host-level metrics (CPU, memory, disk, network)
- **Kube State Metrics**: Kubernetes object metrics (pods, deployments, services)
- **Prometheus Operator**: Manages Prometheus instances and configuration

## Access Information

### Grafana Dashboard
- **URL**: http://10.0.0.244:3000 (via MetalLB LoadBalancer)
- **Username**: admin
- **Password**: grafana123 (change for production)

### Internal Services
- **Prometheus**: http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090
- **Alertmanager**: http://kube-prometheus-stack-alertmanager.monitoring.svc.cluster.local:9093

## Pre-configured Dashboards

**Note**: Dashboard compatibility may vary depending on your Kubernetes distribution (K3s, kubeadm, managed services), CNI, CSI, and cluster configuration. Metric names and availability can differ between environments. You may need to customize dashboard queries or import alternative dashboards specific to your infrastructure.

The monitoring stack includes several community dashboards:

### Kubernetes Cluster Overview (ID: 7249)
- Cluster resource utilization
- Node status and capacity
- Pod distribution and status
- Network and storage metrics

### Node Exporter Full (ID: 1860)
- Detailed host metrics
- CPU, memory, disk, and network usage
- System load and performance indicators
- Hardware monitoring

### Kubernetes Pod Monitoring (ID: 6417)
- Pod resource consumption
- Container metrics
- Restart counts and status
- Resource requests vs limits

### Longhorn Dashboard (ID: 13032)
- Storage volume status
- Disk usage and performance
- Replica health
- Backup status

## Storage Configuration

### Prometheus Storage
- **Size**: 50Gi Longhorn volume
- **Retention**: 30 days
- **Retention Size**: 45GB
- **Storage Class**: longhorn

### Grafana Storage
- **Size**: 10Gi Longhorn volume
- **Purpose**: Dashboard and configuration persistence
- **Storage Class**: longhorn

### Alertmanager Storage
- **Size**: 10Gi Longhorn volume
- **Purpose**: Alert state and configuration
- **Storage Class**: longhorn

## Resource Allocation

### Prometheus
```yaml
resources:
  requests:
    cpu: 200m
    memory: 512Mi
  limits:
    cpu: 1000m
    memory: 2Gi
```

### Grafana
```yaml
resources:
  requests:
    cpu: 100m
    memory: 256Mi
  limits:
    cpu: 500m
    memory: 1Gi
```

### Alertmanager
```yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

## Configuration Management

### Grafana Configuration
Grafana is configured with:
- Automatic Prometheus data source
- Pre-loaded community dashboards
- Persistent storage for custom dashboards
- LoadBalancer service for external access

### Prometheus Configuration
Prometheus automatically discovers:
- Kubernetes API server metrics
- Node metrics via Node Exporter
- Pod metrics via cAdvisor
- Kubernetes object metrics via Kube State Metrics

## Monitoring Targets

### Automatic Discovery
The monitoring stack automatically monitors:
- **Kubernetes Control Plane**: API server, scheduler, controller manager
- **Nodes**: CPU, memory, disk, network via Node Exporter
- **Pods**: Resource usage, status, logs
- **Services**: Endpoint availability and performance
- **Longhorn**: Storage metrics and health
- **MetalLB**: Load balancer status and metrics

### Custom Metrics
To add custom application metrics:
1. Expose metrics endpoint in your application
2. Create a ServiceMonitor resource
3. Prometheus will automatically discover and scrape metrics

Example ServiceMonitor:
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: my-app
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: my-app
  endpoints:
  - port: metrics
```

## Alerting

### Default Alerts
The stack includes default alerts for:
- High CPU usage
- High memory usage
- Disk space warnings
- Pod crash loops
- Node unavailability

### Custom Alerts
Create custom alerts using PrometheusRule resources:
```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: my-alerts
  namespace: monitoring
spec:
  groups:
  - name: my-app.rules
    rules:
    - alert: MyAppDown
      expr: up{job="my-app"} == 0
      for: 5m
      annotations:
        summary: "My application is down"
```

## Troubleshooting

### Common Issues

**Dashboard panels showing "N/A" or no data:**
- Check if metric names match your Kubernetes distribution
- Verify dashboard variables are properly configured
- Consider importing dashboards specific to your infrastructure (K3s, EKS, etc.)
- Test individual PromQL queries in Prometheus UI (port-forward to :9090)

**Grafana not accessible:**
```bash
kubectl get svc grafana -n monitoring
kubectl get pods -n monitoring | grep grafana
```

**Prometheus not collecting metrics:**
```bash
kubectl logs -n monitoring prometheus-kube-prometheus-stack-prometheus-0
kubectl get servicemonitors -n monitoring
```

**High resource usage:**
- Adjust retention period in Prometheus configuration
- Reduce scrape intervals for non-critical metrics
- Scale down replica counts if needed

### Useful Commands

Check monitoring stack status:
```bash
kubectl get pods -n monitoring
kubectl get svc -n monitoring
kubectl get helmreleases -n monitoring
```

View Prometheus targets:
```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Access http://localhost:9090/targets
```

Check storage usage:
```bash
kubectl get pvc -n monitoring
kubectl describe pvc -n monitoring
```

## Maintenance

### Regular Tasks
- Monitor storage usage and adjust retention as needed
- Review and update dashboard configurations
- Check alert rules and notification channels
- Update Helm chart versions periodically

### Backup Considerations
- Grafana dashboards are stored in persistent volumes
- Prometheus data can be backed up via snapshots
- Configuration is stored in Git (GitOps)

## Security Considerations

### Default Credentials
- Change default Grafana password for production use
- Consider enabling authentication providers (LDAP, OAuth)
- Restrict network access if needed

### Network Security
- Grafana exposed via LoadBalancer (consider ingress with TLS)
- Internal services use ClusterIP (not externally accessible)
- Consider network policies for additional isolation

## Performance Tuning

### For Larger Clusters
- Increase Prometheus resource limits
- Adjust scrape intervals based on requirements
- Consider federation for multi-cluster setups
- Use recording rules for complex queries

### For Resource-Constrained Environments
- Reduce retention period
- Disable unnecessary exporters
- Adjust scrape intervals
- Use smaller storage allocations

This monitoring stack provides a solid foundation for observing your homelab infrastructure and can be extended as your needs grow.
