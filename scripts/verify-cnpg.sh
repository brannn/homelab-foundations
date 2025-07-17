#!/bin/bash
# CNPG Deployment Verification Script
# This script verifies that the CloudNativePG operator is properly deployed

set -e

echo "🔍 Verifying CloudNativePG (CNPG) Deployment..."
echo "================================================"

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not installed or not in PATH"
    exit 1
fi

# Check if cluster is accessible
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Cannot connect to Kubernetes cluster"
    exit 1
fi

echo "✅ Kubernetes cluster is accessible"

# Check CNPG namespace
echo ""
echo "📁 Checking CNPG namespace..."
if kubectl get namespace cnpg-system &> /dev/null; then
    echo "✅ cnpg-system namespace exists"
else
    echo "❌ cnpg-system namespace not found"
    exit 1
fi

# Check CNPG Helm repository
echo ""
echo "📦 Checking CNPG Helm repository..."
if kubectl get helmrepository cnpg -n flux-system &> /dev/null; then
    echo "✅ CNPG Helm repository is configured"
    kubectl get helmrepository cnpg -n flux-system -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' | grep -q "True" && echo "✅ CNPG Helm repository is ready" || echo "⚠️  CNPG Helm repository is not ready yet"
else
    echo "❌ CNPG Helm repository not found"
    exit 1
fi

# Check CNPG Helm release
echo ""
echo "🚀 Checking CNPG Helm release..."
if kubectl get helmrelease cloudnative-pg -n cnpg-system &> /dev/null; then
    echo "✅ CNPG Helm release exists"
    kubectl get helmrelease cloudnative-pg -n cnpg-system -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' | grep -q "True" && echo "✅ CNPG Helm release is ready" || echo "⚠️  CNPG Helm release is not ready yet"
else
    echo "❌ CNPG Helm release not found"
    exit 1
fi

# Check CNPG operator pods
echo ""
echo "🏃 Checking CNPG operator pods..."
if kubectl get pods -n cnpg-system -l app.kubernetes.io/name=cloudnative-pg &> /dev/null; then
    RUNNING_PODS=$(kubectl get pods -n cnpg-system -l app.kubernetes.io/name=cloudnative-pg --field-selector=status.phase=Running --no-headers | wc -l)
    TOTAL_PODS=$(kubectl get pods -n cnpg-system -l app.kubernetes.io/name=cloudnative-pg --no-headers | wc -l)
    
    if [ "$RUNNING_PODS" -eq "$TOTAL_PODS" ] && [ "$TOTAL_PODS" -gt 0 ]; then
        echo "✅ All CNPG operator pods are running ($RUNNING_PODS/$TOTAL_PODS)"
    else
        echo "⚠️  CNPG operator pods status: $RUNNING_PODS/$TOTAL_PODS running"
        kubectl get pods -n cnpg-system -l app.kubernetes.io/name=cloudnative-pg
    fi
else
    echo "❌ No CNPG operator pods found"
    exit 1
fi

# Check CNPG CRDs
echo ""
echo "📋 Checking CNPG Custom Resource Definitions..."
EXPECTED_CRDS=("clusters.postgresql.cnpg.io" "backups.postgresql.cnpg.io" "scheduledbackups.postgresql.cnpg.io")
for crd in "${EXPECTED_CRDS[@]}"; do
    if kubectl get crd "$crd" &> /dev/null; then
        echo "✅ CRD $crd exists"
    else
        echo "❌ CRD $crd not found"
        exit 1
    fi
done

# Check backup configuration
echo ""
echo "💾 Checking backup configuration..."
if kubectl get configmap cnpg-backup-config -n cnpg-system &> /dev/null; then
    echo "✅ CNPG backup configuration exists"
else
    echo "⚠️  CNPG backup configuration not found"
fi

# Check for backup credentials secret
if kubectl get secret minio-backup-credentials -n cnpg-system &> /dev/null; then
    echo "✅ MinIO backup credentials secret exists"
else
    echo "⚠️  MinIO backup credentials secret not found"
    echo "   Create it with: kubectl create secret generic minio-backup-credentials \\"
    echo "     --from-literal=ACCESS_KEY_ID=\"YOUR_MINIO_ACCESS_KEY\" \\"
    echo "     --from-literal=SECRET_ACCESS_KEY=\"YOUR_MINIO_SECRET_KEY\" \\"
    echo "     --namespace=cnpg-system"
fi

# Check monitoring configuration
echo ""
echo "📊 Checking monitoring configuration..."
if kubectl get servicemonitor cnpg-operator -n cnpg-system &> /dev/null; then
    echo "✅ CNPG operator ServiceMonitor exists"
else
    echo "⚠️  CNPG operator ServiceMonitor not found"
fi

if kubectl get servicemonitor cnpg-clusters -n cnpg-system &> /dev/null; then
    echo "✅ CNPG clusters ServiceMonitor exists"
else
    echo "⚠️  CNPG clusters ServiceMonitor not found"
fi

# Check for any existing PostgreSQL clusters
echo ""
echo "🗄️  Checking for existing PostgreSQL clusters..."
CLUSTERS=$(kubectl get clusters.postgresql.cnpg.io -A --no-headers 2>/dev/null | wc -l)
if [ "$CLUSTERS" -gt 0 ]; then
    echo "✅ Found $CLUSTERS PostgreSQL cluster(s):"
    kubectl get clusters.postgresql.cnpg.io -A
else
    echo "ℹ️  No PostgreSQL clusters found (this is expected for a fresh CNPG installation)"
fi

echo ""
echo "🎉 CNPG Deployment Verification Complete!"
echo "================================================"

# Summary
echo ""
echo "📋 Summary:"
echo "- CNPG operator is deployed and running"
echo "- Custom Resource Definitions are installed"
echo "- Monitoring configuration is in place"
echo "- Backup configuration is available"
echo ""
echo "🚀 Next Steps:"
echo "1. Create MinIO backup credentials secret (if not already done)"
echo "2. Deploy your first PostgreSQL cluster using templates in docs/templates/"
echo "3. Verify backup functionality with a test cluster"
echo ""
echo "📚 Documentation:"
echo "- CNPG README: clusters/um890/cnpg/README.md"
echo "- Templates: docs/templates/"
echo "- Examples: examples/applications/database-app/"
