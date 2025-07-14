# Application Examples for Homelab Foundations

**Version**: 1.0
**Date**: 2025-07-14
**Author**: Community Contributors
**Status**: Active

## Overview

This directory contains boilerplate examples demonstrating how to add applications to your homelab-foundations cluster using Flux GitOps. Each example follows best practices and integrates with the existing infrastructure components.

## Available Examples

### 1. Simple Application (`simple-app/`)
- **Pattern**: Basic deployment with service
- **Use Case**: Simple stateless applications
- **Components**: Deployment, Service, ConfigMap
- **Storage**: None
- **Networking**: ClusterIP service

### 2. Web Application with Ingress (`web-app-with-ingress/`)
- **Pattern**: Web app with external access
- **Use Case**: Web applications, APIs, dashboards
- **Components**: Deployment, Service, Ingress, TLS certificates
- **Storage**: Optional persistent volume
- **Networking**: HAProxy ingress with HTTPS

### 3. Database Application (`database-app/`)
- **Pattern**: Stateful application with persistent storage
- **Use Case**: Databases, data stores, stateful services
- **Components**: StatefulSet, Service, PVC, ConfigMap, Secret
- **Storage**: Longhorn persistent volumes
- **Networking**: Internal service with optional external access

### 4. Monitoring Application (`monitoring-app/`)
- **Pattern**: Application with monitoring integration
- **Use Case**: Applications that need metrics collection
- **Components**: Deployment, Service, ServiceMonitor, PrometheusRule
- **Storage**: Optional for metrics retention
- **Networking**: Service discovery for Prometheus

## Integration with Homelab Infrastructure

All examples integrate with the existing homelab-foundations components:

### Storage Integration
- **Longhorn CSI**: Persistent volumes for stateful applications
- **Storage Classes**: Uses `longhorn` storage class (default)
- **Volume Management**: Automatic provisioning and management

### Networking Integration
- **MetalLB**: LoadBalancer services get external IPs automatically
- **HAProxy Ingress**: HTTP/HTTPS routing with TLS termination
- **cert-manager**: Automatic TLS certificate provisioning

### Monitoring Integration
- **Prometheus**: ServiceMonitor resources for metrics collection
- **Grafana**: Dashboard examples for application monitoring
- **Alerting**: PrometheusRule examples for application alerts

### GitOps Integration
- **Flux**: All examples use Flux HelmRelease or Kustomization
- **Git Workflow**: Standard commit-push-sync deployment pattern
- **Namespace Management**: Proper namespace isolation

## Usage Instructions

### 1. Choose an Example
Select the example that best matches your application pattern:
```bash
cd examples/applications/<example-name>/
```

### 2. Customize Configuration
Edit the manifests to match your application:
- Update image references
- Modify resource requirements
- Adjust storage requirements
- Configure ingress hostnames
- Set environment variables

### 3. Deploy to Your Cluster
Copy the example to your cluster configuration:
```bash
# Copy example to your cluster config
cp -r examples/applications/web-app-with-ingress/ clusters/um890/my-app/

# Edit the configuration
vim clusters/um890/my-app/helmrelease.yaml

# Add to main kustomization
echo "  - my-app" >> clusters/um890/kustomization.yaml
```

### 4. Commit and Deploy
```bash
git add clusters/um890/my-app/
git commit -m "Add my-app application"
git push origin main

# Flux will automatically deploy your application
flux get all
```

## Best Practices Demonstrated

### Security
- **RBAC**: Proper service account and role definitions
- **Secrets**: Kubernetes secrets for sensitive data
- **Network Policies**: Optional network isolation examples
- **Non-root**: Containers run as non-root users

### Resource Management
- **Resource Limits**: CPU and memory limits/requests
- **Health Checks**: Liveness and readiness probes
- **Graceful Shutdown**: Proper termination handling
- **Horizontal Scaling**: HPA examples where applicable

### Observability
- **Logging**: Structured logging examples
- **Metrics**: Prometheus metrics integration
- **Tracing**: Optional distributed tracing setup
- **Health Endpoints**: Application health check endpoints

### GitOps
- **Declarative**: All configuration as code
- **Version Control**: Proper Git workflow
- **Environment Separation**: Development vs production patterns
- **Rollback**: Easy rollback procedures

## Common Patterns

### Environment Variables
```yaml
env:
- name: DATABASE_URL
  valueFrom:
    secretKeyRef:
      name: app-secrets
      key: database-url
- name: LOG_LEVEL
  valueFrom:
    configMapKeyRef:
      name: app-config
      key: log-level
```

### Persistent Storage
```yaml
volumeClaimTemplates:
- metadata:
    name: data
  spec:
    accessModes: ["ReadWriteOnce"]
    storageClassName: longhorn
    resources:
      requests:
        storage: 10Gi
```

### Ingress with TLS
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    kubernetes.io/ingress.class: haproxy
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  tls:
  - hosts:
    - myapp.homelab.local
    secretName: myapp-tls
  rules:
  - host: myapp.homelab.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: myapp
            port:
              number: 80
```

## Troubleshooting

### Common Issues
1. **Application not starting**: Check resource limits and node capacity
2. **Storage issues**: Verify Longhorn is healthy and has capacity
3. **Ingress not working**: Check HAProxy controller and DNS resolution
4. **TLS certificates**: Verify cert-manager and ClusterIssuer configuration

### Debugging Commands
```bash
# Check application status
kubectl get pods -n <namespace>
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace>

# Check Flux deployment
flux get helmrelease <app-name> -n <namespace>
kubectl describe helmrelease <app-name> -n <namespace>

# Check ingress and certificates
kubectl get ingress -n <namespace>
kubectl get certificates -n <namespace>
kubectl describe certificate <cert-name> -n <namespace>
```

## Contributing Examples

To add new examples:
1. Create a new directory under `examples/applications/`
2. Include all necessary Kubernetes manifests
3. Add a README.md explaining the example
4. Test the example in a real cluster
5. Submit a pull request

## Next Steps

After deploying your applications:
1. **Monitor**: Set up dashboards in Grafana
2. **Alert**: Configure alerts in Prometheus
3. **Backup**: Plan backup strategy for persistent data
4. **Scale**: Consider horizontal pod autoscaling
5. **Secure**: Implement network policies and RBAC

## Resources

- [Flux Documentation](https://fluxcd.io/docs/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [HAProxy Ingress Guide](../docs/HAPROXY_INGRESS.md)
- [Homelab Architecture](../docs/ARCHITECTURE.md)
