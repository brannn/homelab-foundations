# Simple Application Example

## Overview

This example demonstrates deploying a basic stateless application using Flux GitOps. It includes a simple web server with configuration management and basic monitoring.

## Components

- **Deployment**: Nginx web server with custom configuration
- **Service**: ClusterIP service for internal access
- **ConfigMap**: Custom nginx configuration
- **Namespace**: Dedicated namespace for the application

## Features

- Resource limits and requests
- Health checks (liveness and readiness probes)
- Custom configuration via ConfigMap
- Proper labels and selectors
- Non-root container execution

## Deployment

1. Copy this directory to your cluster configuration:
   ```bash
   cp -r examples/applications/simple-app/ clusters/um890/simple-app/
   ```

2. Add to your main kustomization:
   ```bash
   echo "  - simple-app" >> clusters/um890/kustomization.yaml
   ```

3. Commit and push:
   ```bash
   git add clusters/um890/simple-app/
   git commit -m "Add simple-app example"
   git push origin main
   ```

4. Verify deployment:
   ```bash
   kubectl get pods -n simple-app
   kubectl get svc -n simple-app
   ```

## Accessing the Application

Since this uses a ClusterIP service, access it via port-forward:
```bash
kubectl port-forward -n simple-app svc/simple-app 8080:80
```

Then visit: http://localhost:8080

## Customization

### Change the Application Image
Edit `kustomization.yaml` and modify the image:
```yaml
images:
- name: nginx
  newTag: "1.25-alpine"
```

### Modify Configuration
Edit `configmap.yaml` to change the nginx configuration:
```yaml
data:
  nginx.conf: |
    # Your custom nginx configuration
```

### Adjust Resources
Edit `deployment.yaml` to change resource limits:
```yaml
resources:
  limits:
    cpu: 200m
    memory: 256Mi
  requests:
    cpu: 100m
    memory: 128Mi
```

## Monitoring

This example includes basic monitoring setup:
- Health check endpoints
- Prometheus metrics (if your app supports them)
- Proper logging configuration

## Scaling

To scale the application:
```bash
kubectl scale deployment simple-app -n simple-app --replicas=3
```

Or add HPA for automatic scaling (see monitoring-app example).

## Troubleshooting

### Pod not starting
```bash
kubectl describe pod <pod-name> -n simple-app
kubectl logs <pod-name> -n simple-app
```

### Service not accessible
```bash
kubectl get endpoints -n simple-app
kubectl describe svc simple-app -n simple-app
```

### Configuration issues
```bash
kubectl get configmap -n simple-app
kubectl describe configmap simple-app-config -n simple-app
```
