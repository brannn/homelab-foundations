# NATS + JetStream Integration Plan for Homelab Foundations

**Version:** 1.0\
**Author:** Community Contributors\
**Last Updated:** 2025-07-15

---

## Overview

This document outlines the steps to integrate **NATS with JetStream** into the Flux-managed `homelab-foundations` Kubernetes cluster. The deployment uses the official NATS Helm chart with JetStream enabled for persistence and replay functionality.

## Goals

- Deploy NATS with JetStream enabled
- Support persistent memory and disk-backed streams
- Expose internal NATS endpoint for microservice communication
- Optionally enable Prometheus metrics for observability

---

## Components

| Component   | Description                                      |
| ----------- | ------------------------------------------------ |
| NATS        | High-performance messaging system                |
| JetStream   | NATS persistence and stream management extension |
| HelmRelease | Flux-managed Helm deployment                     |
| Prometheus  | Optional metrics integration                     |

---

## Prerequisites

- Flux installed and configured
- Helm controller and source controller running
- `homelab-foundations` GitOps repo structure
- MetalLB for LoadBalancer IPs (if external access is desired)

---

## Step-by-Step Implementation

### 1. Add HelmRepository for NATS

Create the following file:

``

```yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: nats
  namespace: flux-system
spec:
  url: https://nats-io.github.io/k8s/helm/charts/
  interval: 10m
```

### 2. Define HelmRelease for NATS

Create the following file:

``

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: nats
  namespace: nats
spec:
  releaseName: nats
  chart:
    spec:
      chart: nats
      version: "1.1.12"  # Or latest compatible
      sourceRef:
        kind: HelmRepository
        name: nats
        namespace: flux-system
  interval: 5m
  values:
    jetstream:
      enabled: true
      memStorage:
        enabled: true
        size: 1Gi
      fileStorage:
        enabled: true
        size: 10Gi
        storageDirectory: /data
    nats:
      image:
        tag: 2.10.11
      resources:
        requests:
          cpu: 100m
          memory: 128Mi
        limits:
          cpu: 500m
          memory: 512Mi
```

### 3. Define Namespace for NATS

Create the following file:

``

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: nats
```

### 4. Update Kustomization

In your `clusters/um890/kustomization.yaml`, add the NATS directory:

```yaml
resources:
  - ./nats
```

### 5. Commit to GitOps Repo

Commit and push all files to trigger Flux reconciliation:

```
homelab-foundations/
├── infrastructure/
│   └── helm-repositories/
│       └── nats.yaml
└── clusters/
    └── um890/
        ├── nats/
        │   ├── namespace.yaml
        │   └── helmrelease.yaml
        └── kustomization.yaml
```

### 6. (Optional) Port Forward for Local Access

```bash
kubectl -n nats port-forward svc/nats 4222:4222
```

Use this for testing with local clients like `nats-box` or scripts.

### 7. (Optional) Monitoring Integration

In `helmrelease.yaml` under `values`, add:

```yaml
prometheus:
  enabled: true
```

This assumes Prometheus is already deployed in the cluster.

---

## Validation

- Deploy `nats-box` pod for CLI exploration:

```bash
kubectl apply -f https://raw.githubusercontent.com/nats-io/k8s/main/nats-box/nats-box.yaml
```

- Confirm JetStream is active:

```bash
nats --server nats://localhost:4222 stream ls
```

---

## Future Enhancements

- Add authentication with NKeys or JWTs
- Enable clustering for high availability
- Create default streams and consumers using init jobs or Flux hooks

---

## References

- [https://docs.nats.io](https://docs.nats.io)
- [https://docs.nats.io/nats-concepts/jetstream](https://docs.nats.io/nats-concepts/jetstream)
- [https://github.com/nats-io/k8s](https://github.com/nats-io/k8s)
- [https://artifacthub.io/packages/helm/nats/nats](https://artifacthub.io/packages/helm/nats/nats)

---

## License

MIT or equivalent open-source license.

