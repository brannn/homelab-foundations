# Foundation Architecture

**Version**: 1.0  
**Date**: 2025-07-14  
**Author**: Community Contributors  
**Status**: Active

## Overview

This document explains the architectural decision to manage core storage components (Longhorn CSI and MinIO object storage) outside of Flux using Helmfile, while other infrastructure services are managed via GitOps.

## Architecture Decision

### Problem Statement

Traditional GitOps approaches create circular dependencies when storage and GitOps controllers depend on each other:

1. **Flux needs storage** for persistent operations and temporary files
2. **Storage needs Flux** to be deployed and managed
3. **If Flux fails**, storage can't be recovered via GitOps
4. **If storage fails**, Flux can't function properly

### Solution: Foundation-First Architecture

**Core Principle**: Storage must be available before GitOps can function reliably.

```
┌─────────────────────────────────────────────────────────────┐
│                    FOUNDATION LAYER                         │
│                  (Helmfile Managed)                         │
│                                                             │
│  ┌─────────────────┐    ┌─────────────────────────────────┐ │
│  │   Longhorn CSI  │    │      MinIO Object Storage      │ │
│  │                 │    │                                 │ │
│  │ • Persistent    │    │ • S3-compatible storage        │ │
│  │   Volumes       │    │ • Application data             │ │
│  │ • StatefulSets  │    │ • Backup storage               │ │
│  │ • Database      │    │ • Container registry           │ │
│  │   storage       │    │                                 │ │
│  └─────────────────┘    └─────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────┐
│                     GITOPS LAYER                            │
│                   (Flux Managed)                            │
│                                                             │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌────────┐ │
│  │   MetalLB   │ │cert-manager │ │   HAProxy   │ │Monitor │ │
│  │             │ │             │ │   Ingress   │ │  Stack │ │
│  │ • Load      │ │ • TLS certs │ │             │ │        │ │
│  │   balancing │ │ • Auto      │ │ • HTTP/S    │ │• Prom  │ │
│  │ • External  │ │   renewal   │ │   routing   │ │• Graf  │ │
│  │   IPs       │ │             │ │             │ │        │ │
│  └─────────────┘ └─────────────┘ └─────────────┘ └────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Component Classification

### Foundation Components (Helmfile)

**Criteria**: Components that other services depend on for basic functionality.

- **Longhorn CSI**: Provides persistent storage for all stateful workloads
- **MinIO Object Storage**: Provides S3-compatible storage for applications

**Characteristics**:
- Must be available before GitOps
- Rarely change once configured
- Critical for cluster functionality
- Manual deployment acceptable for stability

### GitOps Components (Flux)

**Criteria**: Components that can be safely removed and redeployed without data loss.

- **MetalLB**: Load balancer (can be recreated)
- **cert-manager**: Certificate management (certificates can be regenerated)
- **HAProxy Ingress**: HTTP routing (stateless)
- **Monitoring Stack**: Observability (can lose historical data)

**Characteristics**:
- Can tolerate temporary removal
- Benefit from automated management
- Configuration changes frequently
- No persistent data dependencies

## Operational Benefits

### High Availability
- **Storage remains stable** during GitOps operations
- **No circular dependencies** between storage and GitOps
- **Independent recovery paths** for foundation vs. GitOps components

### Operational Safety
- **Foundation protected** from accidental GitOps changes
- **Clear separation** of concerns between layers
- **Predictable recovery** procedures

### Development Workflow
- **Foundation changes** require intentional manual deployment
- **GitOps changes** automatically deployed and tested
- **Reduced blast radius** for configuration experiments

## Deployment Workflow

### Initial Setup
1. **Deploy Foundation** (Helmfile): Longhorn + MinIO
2. **Bootstrap GitOps** (Flux): Enable automated management
3. **Verify Integration**: Ensure GitOps can use foundation storage

### Day-to-Day Operations
- **Foundation updates**: Manual Helmfile deployment (rare)
- **Service updates**: Automatic via GitOps (frequent)
- **Configuration changes**: Git commits trigger Flux reconciliation

### Disaster Recovery
1. **Foundation recovery**: Direct Helmfile deployment
2. **GitOps recovery**: Flux bootstrap (depends on foundation)
3. **Service recovery**: Automatic once GitOps is restored

## Implementation Details

### Foundation Deployment
```bash
# Deploy storage foundation
cd longhorn/ && helmfile apply
cd ../minio/ && helmfile apply

# Verify foundation is ready
kubectl get storageclass
kubectl get pods -n longhorn-system
kubectl get pods -n minio-tenant
```

### GitOps Integration
```bash
# Bootstrap GitOps (requires foundation)
flux bootstrap github --owner=USER --repository=REPO

# GitOps manages everything else
flux get all
```

This architecture ensures reliable, maintainable infrastructure with clear separation between foundation and application layers.
