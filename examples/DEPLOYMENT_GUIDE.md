# Application Deployment Guide

**Version**: 1.0
**Date**: 2025-07-14
**Author**: Community Contributors
**Status**: Active

## Overview

This guide provides step-by-step instructions for deploying applications to your homelab-foundations cluster using the provided examples and Flux GitOps.

## Prerequisites

Before deploying applications, verify your homelab-foundations cluster has:

### Required Components
- **Kubernetes cluster** (K3s recommended)
- **Flux GitOps** deployed and operational
- **Longhorn CSI** for persistent storage
- **MetalLB** for LoadBalancer services
- **HAProxy Ingress Controller** for HTTP/HTTPS routing
- **cert-manager** for TLS certificate automation

### Optional Components (for full functionality)
- **Prometheus + Grafana** for monitoring
- **MinIO** for object storage
- **DNS resolution** for custom domains

### Verification Commands
```bash
# Check cluster status
kubectl cluster-info

# Verify Flux
flux get all

# Check storage
kubectl get storageclass
kubectl get pods -n longhorn-system

# Check networking
kubectl get pods -n metallb-system
kubectl get pods -n haproxy-controller

# Check monitoring (optional)
kubectl get pods -n monitoring
```

## Deployment Workflow

### 1. Choose Application Pattern

Select the example that best matches your needs:

| Pattern | Use Case | Components | Complexity |
|---------|----------|------------|------------|
| **simple-app** | Basic web service | Deployment, Service, ConfigMap | Basic |
| **web-app-with-ingress** | External web app | + Ingress, TLS certificates | Intermediate |
| **database-app** | Stateful service | + StatefulSet, PVC, Secrets | Advanced |
| **monitoring-app** | Full observability | + ServiceMonitor, Alerts, HPA | Expert |

### 2. Copy and Customize

```bash
# Copy example to your cluster config
cp -r examples/applications/<pattern>/ clusters/um890/<your-app>/

# Navigate to your app directory
cd clusters/um890/<your-app>/

# Customize configuration files
vim kustomization.yaml
vim helmrelease.yaml  # if using Helm
```

### 3. Common Customizations

#### Update Application Name
```yaml
# In kustomization.yaml
metadata:
  name: your-app-name
  namespace: your-app-namespace
```

#### Configure Resources
```yaml
# In deployment.yaml or helmrelease.yaml
resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi
```

#### Set Storage Requirements
```yaml
# For stateful applications
volumeClaimTemplates:
- metadata:
    name: data
  spec:
    storageClassName: longhorn
    resources:
      requests:
        storage: 10Gi
```

#### Configure Ingress
```yaml
# In ingress.yaml
spec:
  tls:
  - hosts:
    - your-app.homelab.local
    secretName: your-app-tls
  rules:
  - host: your-app.homelab.local
```

### 4. Add to Cluster Configuration

```bash
# Add your app to the main kustomization
echo "  - your-app" >> clusters/um890/kustomization.yaml

# Verify the configuration
kubectl kustomize clusters/um890/your-app/
```

### 5. Deploy via GitOps

```bash
# Commit your changes
git add clusters/um890/your-app/
git add clusters/um890/kustomization.yaml
git commit -m "Add your-app application"

# Push to trigger deployment
git push origin main

# Monitor deployment
flux get all
kubectl get pods -n your-app-namespace -w
```

## Application Patterns Deep Dive

### Simple Application Pattern

**Best for**: Static websites, simple APIs, microservices

**Key files**:
- `deployment.yaml` - Application deployment
- `service.yaml` - Internal service
- `configmap.yaml` - Configuration data

**Customization points**:
- Container image and tag
- Resource limits
- Configuration data
- Health check endpoints

### Web Application with Ingress Pattern

**Best for**: Web applications requiring external access

**Key files**:
- `helmrelease.yaml` - Helm-based deployment
- `ingress.yaml` - External access configuration

**Customization points**:
- Domain name configuration
- TLS certificate settings
- Load balancer configuration
- Security headers

### Database Application Pattern

**Best for**: Databases, data stores, stateful services

**Key files**:
- `helmrelease.yaml` - PostgreSQL Helm chart
- Automatic PVC creation via Helm values

**Customization points**:
- Database credentials
- Storage size and class
- Backup configuration
- Performance tuning

### Monitoring Application Pattern

**Best for**: Applications requiring comprehensive observability

**Key files**:
- `deployment.yaml` - Application with metrics
- `servicemonitor.yaml` - Prometheus scraping
- `prometheusrule.yaml` - Alerting rules
- `hpa.yaml` - Auto-scaling configuration

**Customization points**:
- Metrics endpoints
- Alert thresholds
- Scaling parameters
- Dashboard configuration

## DNS Configuration

For applications with ingress, configure DNS resolution:

### Option 1: Local DNS (Development)
```bash
# Add to /etc/hosts
echo "10.0.0.244 your-app.homelab.local" >> /etc/hosts
```

### Option 2: Router DNS
Configure your router to resolve `*.homelab.local` to your HAProxy LoadBalancer IP (`10.0.0.244`).

### Option 3: External DNS
Use external DNS services like Cloudflare, pointing to your public IP with port forwarding.

## Monitoring Integration

### Enable Metrics Collection
```yaml
# Add to deployment annotations
annotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "8080"
  prometheus.io/path: "/metrics"
```

### Create ServiceMonitor
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: your-app
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: your-app
  endpoints:
  - port: http
    path: /metrics
```

### Configure Alerts
```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: your-app
spec:
  groups:
  - name: your-app.rules
    rules:
    - alert: YourAppDown
      expr: up{job="your-app"} == 0
      for: 1m
```

## Security Best Practices

### Container Security
```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1001
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop:
    - ALL
```

### Network Security
```yaml
# NetworkPolicy example
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: your-app
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: your-app
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-system
```

### Secret Management
```yaml
# Use Kubernetes secrets for sensitive data
apiVersion: v1
kind: Secret
metadata:
  name: your-app-secrets
type: Opaque
data:
  database-password: <base64-encoded-password>
```

## Troubleshooting

### Common Issues

#### 1. Pod Not Starting
```bash
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace>
```

#### 2. Storage Issues
```bash
kubectl get pvc -n <namespace>
kubectl describe pvc <pvc-name> -n <namespace>
kubectl get volumes -n longhorn-system
```

#### 3. Ingress Not Working
```bash
kubectl describe ingress <ingress-name> -n <namespace>
kubectl logs -n haproxy-controller deployment/haproxy-ingress-kubernetes-ingress
```

#### 4. Certificate Issues
```bash
kubectl get certificates -n <namespace>
kubectl describe certificate <cert-name> -n <namespace>
kubectl logs -n cert-manager deployment/cert-manager
```

#### 5. Flux Deployment Issues
```bash
flux get all
kubectl describe helmrelease <app-name> -n <namespace>
flux logs --follow
```

### Debug Commands
```bash
# Check resource usage
kubectl top nodes
kubectl top pods -n <namespace>

# Check events
kubectl get events -n <namespace> --sort-by='.lastTimestamp'

# Check service endpoints
kubectl get endpoints -n <namespace>

# Test connectivity
kubectl run debug --image=busybox -it --rm --restart=Never -- /bin/sh
```

## Best Practices Summary

1. **Start Simple**: Begin with the simple-app pattern and add complexity gradually
2. **Use Namespaces**: Isolate applications in dedicated namespaces
3. **Set Resource Limits**: Always define CPU and memory limits
4. **Health Checks**: Implement liveness and readiness probes
5. **Security**: Use non-root containers and security contexts
6. **Monitoring**: Add metrics and alerting from the start
7. **Documentation**: Document your customizations and deployment procedures
8. **Testing**: Test applications in development before production deployment
9. **Backup**: Plan backup strategies for stateful applications
10. **Updates**: Keep applications and dependencies updated

## Next Steps

After successfully deploying your first application:

1. **Add Monitoring**: Integrate with Prometheus and Grafana
2. **Set Up Alerts**: Configure alerting for critical issues
3. **Implement Backups**: Plan backup strategies for data
4. **Scale Applications**: Configure horizontal pod autoscaling
5. **Secure Access**: Implement proper authentication and authorization
6. **Optimize Performance**: Monitor and tune resource usage
7. **Plan Disaster Recovery**: Document recovery procedures

## Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Flux Documentation](https://fluxcd.io/docs/)
- [Helm Documentation](https://helm.sh/docs/)
- [Prometheus Operator](https://prometheus-operator.dev/)
- [HAProxy Ingress Guide](../docs/HAPROXY_INGRESS.md)
- [Homelab Architecture](../docs/ARCHITECTURE.md)
