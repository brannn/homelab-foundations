# ClickHouse Integration Plan (v25.6.3.116-stable)

This document outlines the steps to integrate ClickHouse version `25.6.3.116-stable` into the `homelab-foundations` GitOps-managed Kubernetes environment.

## Directory Structure

Target location: `clusters/um890/clickhouse/`

```
homelab-foundations/
├── clusters/
│   └── um890/
│       ├── clickhouse/
│       │   ├── helmrelease.yaml
│       │   ├── values.yaml
│       │   ├── namespace.yaml
│       │   └── kustomization.yaml
│       └── kustomization.yaml
```

## 1. Namespace Definition

`namespace.yaml`

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: clickhouse
```

## 2. Helm Release Definition

`helmrelease.yaml`

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta2
kind: HelmRelease
metadata:
  name: clickhouse
  namespace: clickhouse
spec:
  releaseName: clickhouse
  chart:
    spec:
      chart: clickhouse
      version: 0.25.0
      sourceRef:
        kind: HelmRepository
        name: clickhouse-operator
        namespace: flux-system
  interval: 1h
  values:
    clickhouse:
      image:
        repository: clickhouse/clickhouse-server
        tag: "25.6.3.116-stable"
      configuration:
        clusters:
          - name: default
            templates:
              podTemplate: pod-template
              volumeClaimTemplate: volume-template
            layout:
              shardsCount: 1
              replicasCount: 1
        settings:
          keep_alive_timeout: 3
          max_connections: 1024
    podTemplates:
      - name: pod-template
        spec:
          containers:
            - name: clickhouse
              resources:
                limits:
                  memory: 2Gi
                  cpu: 1
                requests:
                  memory: 1Gi
                  cpu: 0.5
    volumeClaimTemplates:
      - name: volume-template
        spec:
          accessModes: ["ReadWriteOnce"]
          storageClassName: longhorn
          resources:
            requests:
              storage: 10Gi
```

## 3. Optional Helm Values File

`values.yaml` can be used to store configuration separately if preferred.

## 4. Kustomization File

`kustomization.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - namespace.yaml
  - helmrelease.yaml
```

## 5. Cluster-Level Kustomization Reference

Update `clusters/um890/kustomization.yaml` to include:

```yaml
resources:
  - ./clickhouse
  - ./metallb
  - ./longhorn
  - ./minio
  ...
```

## 6. HelmRepository Source for Flux

Ensure this file exists in your `infrastructure/flux/` or equivalent location:

```yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: clickhouse-operator
  namespace: flux-system
spec:
  interval: 1h
  url: https://charts.altinity.com
```

## 7. Post-Deployment Validation

- Verify pod status:
  ```bash
  kubectl get pods -n clickhouse
  ```

- Test port-forwarding:
  ```bash
  kubectl port-forward svc/clickhouse-clickhouse 8123 -n clickhouse
  ```

- Connect via client:
  ```bash
  clickhouse-client --host 127.0.0.1
  ```

- Or expose through Traefik Ingress as needed.

