# Monitoring Application Example

## Overview

This example shows deployment of an application with monitoring integration, including Prometheus metrics, custom dashboards, alerting rules, and horizontal pod autoscaling.

## Components

- **Deployment**: Sample application with metrics endpoint
- **Service**: Service with metrics port exposed
- **ServiceMonitor**: Prometheus scraping configuration
- **PrometheusRule**: Custom alerting rules
- **HorizontalPodAutoscaler**: Automatic scaling based on metrics
- **Grafana Dashboard**: Custom dashboard for application metrics
- **ConfigMap**: Application configuration

## Features

- Prometheus metrics collection
- Custom Grafana dashboard
- Alerting rules for application health
- Horizontal pod autoscaling
- Health checks and monitoring endpoints
- Resource monitoring and optimization

## Prerequisites

- Prometheus operator deployed (part of monitoring stack)
- Grafana deployed with dashboard provisioning
- Metrics server for HPA (usually included in K3s)

## Metrics Exposed

The example application exposes the following metrics:
- `myapp_requests_total` - Total HTTP requests
- `myapp_request_duration_seconds` - Request duration histogram
- `myapp_active_connections` - Current active connections
- `myapp_errors_total` - Total errors by type
- `myapp_uptime_seconds` - Application uptime

## Deployment

1. Copy this directory to your cluster configuration:
   ```bash
   cp -r examples/applications/monitoring-app/ clusters/um890/monitored-app/
   ```

2. Review and customize the configuration files

3. Add to your main kustomization:
   ```bash
   echo "  - monitored-app" >> clusters/um890/kustomization.yaml
   ```

4. Commit and push:
   ```bash
   git add clusters/um890/monitored-app/
   git commit -m "Add monitored application example"
   git push origin main
   ```

5. Verify deployment:
   ```bash
   kubectl get pods -n monitored-app
   kubectl get servicemonitor -n monitored-app
   kubectl get prometheusrule -n monitored-app
   kubectl get hpa -n monitored-app
   ```

## Accessing Metrics

### Direct metrics endpoint
```bash
kubectl port-forward -n monitored-app svc/monitored-app 8080:8080
curl http://localhost:8080/metrics
```

### Prometheus targets
Check that Prometheus is scraping the application:
1. Access Prometheus UI
2. Go to Status → Targets
3. Look for `monitored-app/monitored-app` target

### Grafana dashboard
1. Access Grafana UI
2. Navigate to Dashboards
3. Look for "Monitored App Dashboard"

## Alerting

The example includes several alerting rules:
- **HighErrorRate**: Triggers when error rate > 5%
- **HighResponseTime**: Triggers when 95th percentile > 1s
- **ApplicationDown**: Triggers when application is unreachable
- **HighMemoryUsage**: Triggers when memory usage > 80%

### Testing alerts
Generate load to trigger alerts:
```bash
# Generate high error rate
for i in {1..100}; do curl -f http://monitored-app.monitored-app.svc.cluster.local:8080/error || true; done

# Generate high response time
for i in {1..50}; do curl http://monitored-app.monitored-app.svc.cluster.local:8080/slow & done
```

## Horizontal Pod Autoscaling

The HPA is configured to scale based on:
- CPU utilization (target: 70%)
- Memory utilization (target: 80%)
- Custom metric: requests per second (target: 100 RPS)

### Monitor scaling
```bash
kubectl get hpa -n monitored-app -w
kubectl top pods -n monitored-app
```

### Generate load for scaling
```bash
kubectl run -i --tty load-generator --rm --image=busybox --restart=Never -- /bin/sh
# Inside the pod:
while true; do wget -q -O- http://monitored-app.monitored-app.svc.cluster.local:8080/; done
```

## Custom Dashboard

The Grafana dashboard includes:
- Request rate and error rate graphs
- Response time percentiles
- Active connections
- Resource utilization (CPU, memory)
- Pod scaling events
- Alert status

### Dashboard features
- Time range selector
- Variable filters (namespace, pod)
- Drill-down capabilities
- Alert annotations

## Monitoring Best Practices

### Metrics naming
- Use consistent naming conventions
- Include units in metric names
- Use labels for dimensions

### Alerting
- Set appropriate thresholds
- Include runbook links in alerts
- Use severity levels (warning, critical)
- Avoid alert fatigue

### Dashboards
- Focus on key business metrics
- Use appropriate visualization types
- Include context and documentation
- Regular review and updates

## Troubleshooting

### Metrics not appearing in Prometheus
```bash
kubectl describe servicemonitor monitored-app -n monitored-app
kubectl logs -n monitoring prometheus-kube-prometheus-stack-prometheus-0
```

### Alerts not firing
```bash
kubectl describe prometheusrule monitored-app -n monitored-app
# Check Prometheus rules page for syntax errors
```

### HPA not scaling
```bash
kubectl describe hpa monitored-app -n monitored-app
kubectl get --raw /apis/metrics.k8s.io/v1beta1/namespaces/monitored-app/pods
```

### Dashboard not loading
```bash
kubectl logs -n monitoring deployment/grafana
# Check dashboard ConfigMap
kubectl get configmap -n monitoring | grep dashboard
```

## Customization

### Add custom metrics
Edit `deployment.yaml` to expose additional metrics:
```yaml
# Add environment variables for metrics configuration
env:
- name: METRICS_ENABLED
  value: "true"
- name: METRICS_PATH
  value: "/metrics"
```

### Modify alerting rules
Edit `prometheusrule.yaml` to add or modify alerts:
```yaml
- alert: CustomAlert
  expr: custom_metric > 100
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "Custom metric is high"
```

### Update dashboard
Edit `grafana-dashboard.yaml` to modify visualizations:
```json
{
  "title": "Custom Panel",
  "type": "graph",
  "targets": [
    {
      "expr": "rate(myapp_requests_total[5m])",
      "legendFormat": "Request Rate"
    }
  ]
}
```

## Performance Considerations

- Monitor metrics collection overhead
- Use appropriate scrape intervals
- Consider metric cardinality
- Implement metric retention policies
- Regular performance reviews

## Integration with Homelab Infrastructure

This example integrates with all homelab-foundations components:
- **Longhorn**: Optional persistent storage for application data
- **MetalLB**: LoadBalancer service for external access
- **HAProxy**: Ingress for web interface
- **cert-manager**: TLS certificates for secure access
- **Prometheus**: Metrics collection and alerting
- **Grafana**: Visualization and dashboards
