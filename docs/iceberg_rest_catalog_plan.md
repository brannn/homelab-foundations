# Iceberg REST Catalog Homelab Deployment Plan

## Overview
This document outlines a Kubernetes-native deployment plan for running the Apache Iceberg REST Catalog in a minimal Trino-based homelab environment. It integrates with an existing MinIO tenant named `minio-tenant`, using a dedicated bucket called `iceberg`.

## Objectives
- Deploy the Apache Iceberg reference REST Catalog in K3s
- Use MinIO as the S3-compatible storage backend
- Integrate with Trino for querying Iceberg tables
- Keep total memory usage under 10 GB RAM

## Architecture Summary

| Component         | Resources    | Notes                             |
|------------------|--------------|-----------------------------------|
| Trino Coordinator| 2 GB RAM     | JVM heap: 1.5 GB                  |
| Trino Worker     | 4 GB RAM     | JVM heap: 3.5 GB                  |
| Iceberg Catalog  | 512 MB RAM   | JVM heap: 512 MB                  |
| MinIO Tenant     | Already running | Exposes bucket `iceberg`     |

Total memory footprint: ~6.5 GB RAM

## Prerequisites
- Running K3s cluster with Helm installed
- MinIO tenant `minio-tenant` with S3 bucket `iceberg`
- Namespace: `iceberg-system`
- Access credentials for MinIO (access + secret key)

## Step 1: Build and Deploy Apache Iceberg REST Catalog

### 1.1 Create Dockerfile (optional for homelab)
```Dockerfile
FROM eclipse-temurin:17-jre
WORKDIR /app
COPY iceberg-rest.jar .
EXPOSE 8181
ENTRYPOINT ["java", "-Xmx512m", "-jar", "iceberg-rest.jar"]
```

> Note: You must build `iceberg-rest.jar` from the Iceberg source or use a prebuilt release when available.

### 1.2 Deploy via Kubernetes

Create a `Deployment` manifest:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: iceberg-rest-catalog
  namespace: iceberg-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: iceberg-rest-catalog
  template:
    metadata:
      labels:
        app: iceberg-rest-catalog
    spec:
      containers:
        - name: iceberg-rest
          image: your-repo/iceberg-rest:latest
          ports:
            - containerPort: 8181
          env:
            - name: CATALOG_WAREHOUSE
              value: "s3a://iceberg/"
            - name: AWS_ACCESS_KEY_ID
              value: "<your-access-key>"
            - name: AWS_SECRET_ACCESS_KEY
              value: "<your-secret-key>"
            - name: S3_ENDPOINT
              value: "http://minio.minio-tenant.svc.cluster.local:9000"
          resources:
            limits:
              memory: "512Mi"
            requests:
              memory: "512Mi"
```

And a matching `Service`:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: iceberg-rest-catalog
  namespace: iceberg-system
spec:
  ports:
    - port: 8181
      targetPort: 8181
  selector:
    app: iceberg-rest-catalog
```

## Step 2: Configure Trino Iceberg Catalog

In your Trino Helm `values.yaml`:
```yaml
catalogs:
  iceberg: |
    connector.name=iceberg
    catalog.type=rest
    uri=http://iceberg-rest-catalog.iceberg-system.svc.cluster.local:8181
    warehouse=s3a://iceberg/
    fs.s3a.endpoint=http://minio.minio-tenant.svc.cluster.local:9000
    fs.s3a.access.key=<your-access-key>
    fs.s3a.secret.key=<your-secret-key>
    fs.s3a.path.style.access=true
    fs.s3a.connection.ssl.enabled=false
```

## Step 3: Deploy Trino

Install the official Helm chart with limited resources:
```yaml
coordinator:
  resources:
    limits:
      memory: 2Gi
  jvm:
    maxHeapSize: "1500m"

workers:
  count: 1
  resources:
    limits:
      memory: 4Gi
  jvm:
    maxHeapSize: "3500m"
```

## Step 4: Validate Integration

1. Connect to Trino CLI or Web UI
2. Create a test Iceberg table:
```sql
CREATE TABLE iceberg.default.sample (
  id INT,
  data VARCHAR
);
```
3. Insert and query data
4. Try time travel:
```sql
SELECT * FROM iceberg.default.sample FOR TIMESTAMP AS OF TIMESTAMP '2025-07-01 12:00:00';
```

## Conclusion
This plan provides a lightweight, REST-native Iceberg catalog deployment suitable for homelab use with minimal memory overhead, fully integrated with MinIO and Trino.

You can later substitute the REST catalog with Project Nessie if versioned data lake operations become desirable.

