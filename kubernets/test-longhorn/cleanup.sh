#!/bin/bash

set -e

NAMESPACE="test-longhorn"

echo "Cleaning up test resources..."

# Delete StatefulSet
if kubectl get statefulset test-longhorn-app -n $NAMESPACE &>/dev/null; then
    echo "Deleting StatefulSet..."
    kubectl delete statefulset test-longhorn-app -n $NAMESPACE
    echo "Waiting for StatefulSet to be deleted..."
    kubectl wait --for=delete statefulset/test-longhorn-app -n $NAMESPACE --timeout=60s || true
fi

# Delete Service
if kubectl get service test-longhorn-service -n $NAMESPACE &>/dev/null; then
    echo "Deleting Service..."
    kubectl delete service test-longhorn-service -n $NAMESPACE
fi

# Delete PVCs (this will trigger PV deletion)
if kubectl get pvc -n $NAMESPACE &>/dev/null; then
    echo "Deleting PVCs..."
    kubectl delete pvc -n $NAMESPACE --all
    echo "Waiting for PVCs to be deleted..."
    sleep 5
fi

# Delete namespace
if kubectl get namespace $NAMESPACE &>/dev/null; then
    echo "Deleting namespace..."
    kubectl delete namespace $NAMESPACE
    echo "Waiting for namespace to be deleted..."
    kubectl wait --for=delete namespace/$NAMESPACE --timeout=60s || true
fi

echo "Cleanup completed!"



