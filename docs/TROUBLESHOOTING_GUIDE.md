# Homelab Foundations - Troubleshooting Guide

**Version**: 1.0
**Date**: 2025-07-15
**Author**: Community Contributors (with Augment Agent)
**Status**: Active

## Overview

This troubleshooting guide provides systematic approaches to diagnose and resolve common issues in the homelab-foundations Kubernetes cluster. The guide covers GitOps/Flux problems, storage issues, networking problems, and application-specific troubleshooting.

## Problem Categories

### 1. GitOps/Flux Issues

#### Symptom: Changes not deploying
**Check:**
```bash
flux get all
```

**If GitRepository shows "False":**
- Check SSH key access: `ssh -T git@github.com`
- Verify repository URL: `kubectl get gitrepository flux-system -n flux-system -o yaml`
- Check deploy key in GitHub repository settings

**If Kustomization shows "False":**
- Check syntax: `kubectl describe kustomization flux-system -n flux-system`
- Validate YAML locally: `kustomize build clusters/um890/`

**If HelmRelease shows "False":**
- Check Helm repository: `kubectl get helmrepository -n flux-system`
- Check chart availability: `kubectl describe helmrelease <name> -n <namespace>`

#### Symptom: Flux pods not running
```bash
kubectl get pods -n flux-system
kubectl logs -n flux-system deployment/source-controller
```

### 2. Storage Issues

#### Symptom: Volume shows "Degraded"
**Most common cause**: Replica scheduling failure on single-node

**Fix:**
```bash
# Get volume name
kubectl get volumes -n longhorn-system

# Reduce replicas to 1
kubectl patch volume <volume-name> -n longhorn-system \
  --type='merge' -p='{"spec":{"numberOfReplicas":1}}'
```

#### Symptom: PVC stuck "Pending"
**Check:**
```bash
kubectl describe pvc <pvc-name> -n <namespace>
```

**Common causes:**
- No available storage class
- Insufficient disk space
- Node selector issues

**Solutions:**
- Verify storage class exists: `kubectl get storageclass`
- Check disk space in Longhorn UI
- Check node labels and selectors

#### Symptom: Longhorn UI not accessible
**Check service:**
```bash
kubectl get svc longhorn-frontend -n longhorn-system
```

**If ClusterIP instead of LoadBalancer:**
- Service configuration missing in Helm values
- Add `service.ui.type: LoadBalancer` to Longhorn config

### 3. Network Issues

#### Symptom: Service not accessible externally
**Check service type:**
```bash
kubectl get svc <service-name> -n <namespace>
```

**If LoadBalancer shows "Pending":**
- Check MetalLB pods: `kubectl get pods -n metallb-system`
- Check IP pool availability: `kubectl get ipaddresspool -n metallb-system`
- Verify L2 advertisement: `kubectl get l2advertisement -n metallb-system`

**If External-IP shows "None":**
- Service might be ClusterIP type
- Change to LoadBalancer or use port-forward

#### Symptom: MetalLB not assigning IPs
**Check logs:**
```bash
kubectl logs -n metallb-system deployment/metallb-controller
kubectl logs -n metallb-system daemonset/metallb-speaker
```

**Common issues:**
- IP pool exhausted (only 10.0.0.240-250 available)
- Network configuration conflicts
- Node network issues

### 4. Application Issues

#### Symptom: MinIO pods not starting
**Check:**
```bash
kubectl get pods -n minio-tenant
kubectl describe pod <pod-name> -n minio-tenant
```

**Common causes:**
- PVC issues (see storage troubleshooting)
- Resource constraints
- Configuration errors

#### Symptom: MinIO console not accessible
**Check services:**
```bash
kubectl get svc -n minio-tenant
```

**Verify LoadBalancer:**
- Should show external IP (10.0.0.243)
- If pending, check MetalLB status

### 5. Resource Issues

#### Symptom: Pods stuck "Pending"
**Check resources:**
```bash
kubectl top nodes
kubectl describe pod <pod-name> -n <namespace>
```

**Common causes:**
- CPU/Memory limits exceeded
- Node not schedulable
- Resource quotas

#### Symptom: Node "NotReady"
**Check node status:**
```bash
kubectl describe node um890pro
```

**Common causes:**
- Disk pressure
- Memory pressure
- Network issues
- Kubelet problems

## 🔄 Recovery Procedures

### Flux Recovery
```bash
# If Flux is completely broken
kubectl delete namespace flux-system

# Re-bootstrap
flux bootstrap git \
  --url=ssh://git@github.com/brannn/homelab-foundations \
  --branch=main \
  --path=./clusters/um890
```

### Storage Recovery
```bash
# If Longhorn is corrupted
kubectl delete namespace longhorn-system

# Let Flux recreate it
flux reconcile kustomization flux-system
```

### Network Recovery
```bash
# If MetalLB is broken
kubectl delete namespace metallb-system

# Recreate via GitOps
flux reconcile kustomization flux-system
```

## Diagnostic Commands

### System Overview
```bash
# Cluster health
kubectl get nodes
kubectl get pods -A | grep -v Running

# Resource usage
kubectl top nodes
kubectl top pods -A --sort-by=cpu

# Storage overview
kubectl get pv
kubectl get pvc -A
```

### Network Diagnostics
```bash
# Service endpoints
kubectl get endpoints -A

# Network policies
kubectl get networkpolicy -A

# DNS resolution
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup kubernetes.default
```

### Flux Diagnostics
```bash
# Complete Flux status
flux get all

# Flux system health
kubectl get pods -n flux-system

# Recent reconciliations
flux logs --since=1h
```

## Maintenance Checklist

### Before Making Changes
- [ ] Check current system status: `flux get all`
- [ ] Verify all pods running: `kubectl get pods -A`
- [ ] Note current service IPs: `kubectl get svc -A`
- [ ] Backup current state: `git log --oneline -5`

### After Making Changes
- [ ] Monitor Flux sync: `flux logs --follow`
- [ ] Verify pods restart successfully
- [ ] Test service accessibility
- [ ] Check for any degraded volumes
- [ ] Update documentation if needed

### Weekly Health Check
- [ ] `flux get all` - all should be "True"
- [ ] `kubectl get pods -A` - all should be "Running"
- [ ] Check Longhorn UI for storage health
- [ ] Verify external service access
- [ ] Review recent Git commits

## 🆘 Emergency Contacts

### Self-Help Resources
1. **This documentation** - Start here
2. **Git history** - `git log --oneline -20`
3. **Kubernetes events** - `kubectl get events -A --sort-by='.lastTimestamp'`

### Community Resources
- **Flux Community**: https://fluxcd.io/community/
- **Longhorn Community**: https://github.com/longhorn/longhorn
- **MinIO Community**: https://min.io/community
- **K3s Documentation**: https://docs.k3s.io/

### Last Resort
- **Complete rebuild** from GitOps repository
- **Restore from backups**
- **Start fresh** with documented procedures

---

**Remember**: Most issues can be resolved by checking Flux status first, then working through the component stack systematically.
