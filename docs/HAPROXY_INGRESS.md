# HAProxy Ingress Controller Guide

**Version**: 1.0
**Date**: 2025-07-14
**Author**: Community Contributors
**Status**: Active

## Overview

This guide covers the HAProxy Ingress Controller deployment and usage in the homelab-foundations cluster. HAProxy provides high-performance HTTP/HTTPS ingress capabilities as an alternative to the default Traefik controller.

## Architecture

### Deployment Details
- **Namespace**: `haproxy-controller`
- **Chart**: `haproxytech/kubernetes-ingress` (version >=1.44.0)
- **Management**: Flux GitOps
- **LoadBalancer**: MetalLB provides external IP access

### Service Configuration
```yaml
Service: haproxy-ingress-kubernetes-ingress
Type: LoadBalancer
External IP: 10.0.0.244 (via MetalLB)
Ports:
  - 80 (HTTP)
  - 443 (HTTPS)
  - 1024 (HAProxy stats)
```

## Access Information

### External Access
- **HTTP**: http://10.0.0.244
- **HTTPS**: https://10.0.0.244
- **Stats**: http://10.0.0.244:1024/stats

### Internal Access
- **Service**: `haproxy-ingress-kubernetes-ingress.haproxy-controller.svc.cluster.local`
- **HTTP Port**: 80
- **HTTPS Port**: 443

## Configuration

### Current Configuration
The HAProxy ingress controller is configured with:
- **Resource Limits**: Optimized for homelab use
- **LoadBalancer Service**: Automatic external IP via MetalLB
- **Default Backend**: Configured for 404 responses
- **SSL Termination**: Ready for TLS certificates

### Configuration Files
- **HelmRelease**: `clusters/um890/haproxy-ingress/helmrelease.yaml`
- **Kustomization**: `clusters/um890/haproxy-ingress/kustomization.yaml`

## Usage Examples

### Basic HTTP Ingress
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: example-app
  namespace: default
  annotations:
    kubernetes.io/ingress.class: haproxy
spec:
  rules:
  - host: app.homelab.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: example-app
            port:
              number: 80
```

### HTTPS Ingress with cert-manager
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: example-app-tls
  namespace: default
  annotations:
    kubernetes.io/ingress.class: haproxy
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  tls:
  - hosts:
    - app.homelab.local
    secretName: example-app-tls
  rules:
  - host: app.homelab.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: example-app
            port:
              number: 80
```

### Path-based Routing
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: multi-app
  namespace: default
  annotations:
    kubernetes.io/ingress.class: haproxy
spec:
  rules:
  - host: services.homelab.local
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 8080
      - path: /web
        pathType: Prefix
        backend:
          service:
            name: web-service
            port:
              number: 80
```

## Monitoring

### Health Checks
```bash
# Check HAProxy pods
kubectl get pods -n haproxy-controller

# Check service status
kubectl get svc -n haproxy-controller

# Check ingress resources
kubectl get ingress -A
```

### HAProxy Stats
Access HAProxy statistics at: http://10.0.0.244:1024/stats

### Logs
```bash
# View HAProxy logs
kubectl logs -n haproxy-controller deployment/haproxy-ingress-kubernetes-ingress

# Follow logs
kubectl logs -n haproxy-controller deployment/haproxy-ingress-kubernetes-ingress -f
```

## Troubleshooting

### Common Issues

**1. Ingress not working**
```bash
# Check ingress status
kubectl describe ingress <ingress-name> -n <namespace>

# Check HAProxy configuration
kubectl logs -n haproxy-controller deployment/haproxy-ingress-kubernetes-ingress
```

**2. SSL/TLS issues**
```bash
# Check certificate status
kubectl get certificates -A

# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager
```

**3. LoadBalancer IP not assigned**
```bash
# Check MetalLB status
kubectl get pods -n metallb-system

# Check IP address pool
kubectl get ipaddresspool -n metallb-system
```

### Restart HAProxy
```bash
kubectl rollout restart deployment haproxy-ingress-kubernetes-ingress -n haproxy-controller
```

## Comparison with Traefik

### HAProxy Advantages
- **Performance**: Higher throughput for HTTP/HTTPS traffic
- **Stability**: Mature, battle-tested load balancer
- **Configuration**: Standard Kubernetes Ingress resources
- **Monitoring**: Built-in statistics dashboard

### Traefik Advantages (K3s Default)
- **Auto-discovery**: Automatic service discovery
- **Dashboard**: Web UI for configuration
- **Middleware**: Rich middleware ecosystem
- **Integration**: Tight K3s integration

### When to Use HAProxy
- Production workloads requiring high performance
- Standard Kubernetes ingress patterns
- When you need detailed traffic statistics
- Applications requiring advanced load balancing

### When to Use Traefik
- Development and testing
- Dynamic service discovery needs
- When you prefer automatic configuration
- Simple homelab applications

## Integration with cert-manager

HAProxy ingress works seamlessly with cert-manager for automatic TLS certificate provisioning:

```yaml
# ClusterIssuer example (already configured)
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: haproxy
```

## Best Practices

### Security
- Always use HTTPS for production applications
- Implement proper authentication and authorization
- Use network policies to restrict traffic
- Regular security updates via Flux

### Performance
- Monitor HAProxy stats for bottlenecks
- Use appropriate resource limits
- Consider connection pooling for backend services
- Implement proper health checks

### Maintenance
- Monitor certificate expiration
- Keep HAProxy chart version updated
- Test ingress configurations in development first
- Use proper DNS configuration for external access

## Conclusion

HAProxy Ingress Controller provides a robust, high-performance solution for HTTP/HTTPS traffic routing in the homelab-foundations cluster. Combined with MetalLB for load balancing and cert-manager for TLS automation, it offers enterprise-grade ingress capabilities suitable for production workloads.

The GitOps management via Flux ensures consistent, version-controlled deployments while maintaining the flexibility to customize configurations as needed.
