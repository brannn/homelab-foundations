# Web Application with Ingress Example

## Overview

This example demonstrates deploying a web application with external access via HAProxy ingress controller, including HTTPS with automatic TLS certificate provisioning via cert-manager.

## Components

- **Deployment**: Web application (nginx with custom content)
- **Service**: LoadBalancer service for external access
- **Ingress**: HAProxy ingress with TLS termination
- **Certificate**: Automatic TLS certificate via cert-manager
- **ConfigMap**: Application configuration
- **Secret**: Application secrets (example)

## Features

- External HTTPS access via HAProxy ingress
- Automatic TLS certificate provisioning
- LoadBalancer service with MetalLB integration
- Custom domain configuration
- Security headers and best practices
- Resource limits and health checks

## Prerequisites

- HAProxy ingress controller deployed
- cert-manager deployed with ClusterIssuer configured
- MetalLB providing LoadBalancer IPs
- DNS resolution for your chosen hostname

## Configuration

### 1. Update Hostname
Edit `ingress.yaml` and change the hostname:
```yaml
spec:
  tls:
  - hosts:
    - myapp.homelab.local  # Change this
    secretName: myapp-tls
  rules:
  - host: myapp.homelab.local  # Change this
```

### 2. DNS Configuration
Add DNS entry pointing to your HAProxy LoadBalancer IP:
```
myapp.homelab.local -> 10.0.0.244
```

Or add to your `/etc/hosts` file:
```
10.0.0.244 myapp.homelab.local
```

## Deployment

1. Copy this directory to your cluster configuration:
   ```bash
   cp -r examples/applications/web-app-with-ingress/ clusters/um890/myapp/
   ```

2. Customize the hostname in `ingress.yaml`

3. Add to your main kustomization:
   ```bash
   echo "  - myapp" >> clusters/um890/kustomization.yaml
   ```

4. Commit and push:
   ```bash
   git add clusters/um890/myapp/
   git commit -m "Add myapp web application with ingress"
   git push origin main
   ```

5. Verify deployment:
   ```bash
   kubectl get pods -n myapp
   kubectl get svc -n myapp
   kubectl get ingress -n myapp
   kubectl get certificate -n myapp
   ```

## Accessing the Application

### Via Ingress (Recommended)
Visit: https://myapp.homelab.local

### Via LoadBalancer IP
Get the LoadBalancer IP:
```bash
kubectl get svc -n myapp myapp-loadbalancer
```

Visit: http://<LOADBALANCER-IP>

## TLS Certificate Status

Check certificate provisioning:
```bash
kubectl describe certificate myapp-tls -n myapp
kubectl get certificaterequest -n myapp
```

## Customization

### Change Application Content
Edit `configmap.yaml` to modify the web content:
```yaml
data:
  index.html: |
    # Your custom HTML content
```

### Add Environment Variables
Edit `deployment.yaml` to add environment variables:
```yaml
env:
- name: MY_ENV_VAR
  value: "my-value"
- name: SECRET_VALUE
  valueFrom:
    secretKeyRef:
      name: myapp-secrets
      key: secret-key
```

### Modify Ingress Rules
Edit `ingress.yaml` to add path-based routing:
```yaml
rules:
- host: myapp.homelab.local
  http:
    paths:
    - path: /api
      pathType: Prefix
      backend:
        service:
          name: myapp-api
          port:
            number: 8080
    - path: /
      pathType: Prefix
      backend:
        service:
          name: myapp
          port:
            number: 80
```

## Monitoring

This example includes monitoring endpoints:
- `/health` - Health check
- `/metrics` - Prometheus metrics
- `/ready` - Readiness check

## Security Features

- Non-root container execution
- Read-only root filesystem
- Security context with dropped capabilities
- TLS encryption via cert-manager
- Security headers in nginx configuration

## Troubleshooting

### Certificate Issues
```bash
kubectl describe certificate myapp-tls -n myapp
kubectl logs -n cert-manager deployment/cert-manager
```

### Ingress Issues
```bash
kubectl describe ingress myapp -n myapp
kubectl logs -n haproxy-controller deployment/haproxy-ingress-kubernetes-ingress
```

### LoadBalancer Issues
```bash
kubectl describe svc myapp-loadbalancer -n myapp
kubectl get pods -n metallb-system
```

### DNS Issues
```bash
nslookup myapp.homelab.local
dig myapp.homelab.local
```
