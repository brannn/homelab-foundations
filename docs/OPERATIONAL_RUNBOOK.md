# Homelab Foundations - Operational Runbook

**Version**: 1.1
**Date**: 2025-07-14
**Author**: Community Contributors
**Status**: Active

## Overview

This operational runbook provides comprehensive procedures for managing the homelab Kubernetes cluster and its GitOps infrastructure. The cluster uses a hybrid approach with Flux for core infrastructure and Helmfile for complex applications like MinIO.

## Cluster Information (reference environment)

**Hardware**: UM890Pro (Ryzen 9 + 64GB RAM)
**OS**: SuSE Tumbleweed
**IP Address**: 10.0.0.79
**Architecture**: Single-node Kubernetes cluster
**GitOps**: Hybrid - Flux + Helmfile

## Daily Operations

### Health Checks

Check overall cluster health:
```bash
export KUBECONFIG=~/.kube/homelab
kubectl cluster-info
kubectl get nodes
kubectl get pods --all-namespaces | grep -v Running
```

Check Flux status:
```bash
flux get all
flux logs --follow
```

Check MinIO status:
```bash
cd minio/
helmfile status
kubectl get tenant -n minio-tenant
kubectl get pods -n minio-tenant
```

Check monitoring status:
```bash
kubectl get pods -n monitoring
kubectl get svc -n monitoring
kubectl get helmreleases -n monitoring
```

### Service Access

**HAProxy Ingress**: http://10.0.0.245 (HTTP/HTTPS ingress controller)

**Pi-hole DNS**: http://10.0.0.249/admin
**Credentials**: admin / homelab123
**DNS Service**: 10.0.0.249:53 (TCP/UDP)

**Grafana**: http://10.0.0.243:3000
**Credentials**: admin / grafana123

**MinIO Console**: https://10.0.0.242:9443
**MinIO S3 API**: https://10.0.0.241:443
**Credentials**: minio / minio123

**Longhorn UI**: http://10.0.0.243 (via LoadBalancer)

**Traefik (K3s)**: http://10.0.0.240 (default K3s ingress)
# Access at http://localhost:8080
```

## Deployment Procedures

### Flux-Managed Components

Update infrastructure components (MetalLB, Longhorn):
```bash
# Edit manifests in clusters/um890/ or infrastructure/
git add .
git commit -m "Update infrastructure configuration"
git push origin main

# Verify deployment
flux reconcile source git flux-system
flux get all
```

### MinIO Management

Deploy or update MinIO:
```bash
cd minio/
helmfile apply

# Check deployment status
helmfile status
kubectl get tenant -n minio-tenant
```

## Troubleshooting

### Flux Issues

Flux not syncing:
```bash
flux logs --follow
flux reconcile source git flux-system
kubectl describe gitrepository flux-system -n flux-system
```

HelmRelease failures:
```bash
kubectl describe helmrelease <name> -n <namespace>
kubectl logs -n flux-system deployment/helm-controller
```

### MinIO Issues

Operator problems:
```bash
kubectl logs -n minio-operator deployment/minio-operator
kubectl describe deployment minio-operator -n minio-operator
```

Tenant issues:
```bash
kubectl describe tenant minio-tenant -n minio-tenant
kubectl logs -n minio-tenant minio-tenant-pool-0-0 -c minio
```

Certificate problems:
```bash
kubectl get secrets -n minio-tenant | grep tls
kubectl describe secret <cert-secret> -n minio-tenant
```

### Storage Issues

Longhorn problems:
```bash
kubectl get pv,pvc --all-namespaces
kubectl logs -n longhorn-system deployment/longhorn-manager
kubectl describe storageclass longhorn
```

### Network Issues

MetalLB problems:
```bash
kubectl logs -n metallb-system deployment/controller
kubectl get ipaddresspool -n metallb-system
kubectl get l2advertisement -n metallb-system
```

Service connectivity:
```bash
kubectl get svc --all-namespaces -o wide
kubectl describe svc <service-name> -n <namespace>
```

## Backup and Recovery

### Configuration Backup

All configuration is stored in Git. Ensure regular commits and pushes to GitHub.

### Data Backup

MinIO data backup (if needed):
```bash
# Access MinIO and use mc client for backup
# Or backup Longhorn volumes directly
```

### Disaster Recovery

Complete cluster rebuild:
1. Reinstall Kubernetes on UM890Pro
2. Bootstrap Flux: `flux bootstrap github --owner=brannn --repository=homelab-foundations --branch=main --path=./clusters/um890`
3. Deploy MinIO: `cd minio && helmfile apply`
4. Restore data from backups if needed

## Maintenance

### Regular Tasks

Weekly:
- Check cluster health
- Review Flux reconciliation logs
- Verify all services are accessible
- Check storage usage

Monthly:
- Update Helm charts if needed
- Review and update documentation
- Check for security updates

### Updates

Kubernetes updates:
- Follow SuSE Tumbleweed update procedures
- Test in staging environment if available

Application updates:
- Update chart versions in Git
- Test deployment in development namespace first
- Monitor deployment and rollback if issues occur

## Emergency Procedures

### Service Outages

MinIO unavailable:
1. Check tenant status: `kubectl get tenant -n minio-tenant`
2. Check operator logs: `kubectl logs -n minio-operator deployment/minio-operator`
3. Restart if needed: `kubectl rollout restart deployment/minio-operator -n minio-operator`

Flux not working:
1. Check Flux system pods: `kubectl get pods -n flux-system`
2. Check Git connectivity: `flux reconcile source git flux-system`
3. Restart Flux controllers if needed

### Data Loss

If MinIO data is lost:
1. Check Longhorn volume status
2. Restore from backup if available
3. Recreate tenant if necessary

## Monitoring and Alerting

### Key Metrics

Monitor these indicators:
- Cluster node status
- Pod restart counts
- Storage usage (Longhorn)
- Service availability
- Certificate expiration

### Log Locations

- Flux logs: `flux logs`
- MinIO operator: `kubectl logs -n minio-operator deployment/minio-operator`
- MinIO tenant: `kubectl logs -n minio-tenant minio-tenant-pool-0-0`
- Longhorn: `kubectl logs -n longhorn-system deployment/longhorn-manager`

## Contact Information

**Repository**: https://github.com/brannn/homelab-foundations
**Documentation**: See docs/ directory for additional guides
**Community**: GitHub Issues for questions and contributions