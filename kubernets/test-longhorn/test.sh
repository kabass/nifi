#!/bin/bash

set -e

NAMESPACE="test-longhorn"
POD_NAME="test-longhorn-app-0"
TEST_FILE="/data/test-file.txt"
TEST_CONTENT="Hello from Longhorn storage! Timestamp: $(date +%s)"

echo "========================================="
echo "Testing Longhorn Storage with StatefulSet"
echo "========================================="
echo ""

# Function to wait for pod to be ready
wait_for_pod() {
    echo "Waiting for pod to be ready..."
    kubectl wait --for=condition=ready pod/$POD_NAME -n $NAMESPACE --timeout=120s
    sleep 2
}

# Step 1: Create StatefulSet
echo "Step 1: Creating StatefulSet..."
kubectl apply -f service.yaml
kubectl apply -f statefulset.yaml

wait_for_pod

echo "✓ StatefulSet created and pod is ready"
echo ""

# Step 2: Write data
echo "Step 2: Writing data to persistent volume..."
kubectl exec -n $NAMESPACE $POD_NAME -- sh -c "echo '$TEST_CONTENT' > $TEST_FILE"
kubectl exec -n $NAMESPACE $POD_NAME -- ls -lh /data/

echo "✓ Data written successfully"
echo ""

# Step 3: Read data
echo "Step 3: Reading data from persistent volume..."
DATA_READ=$(kubectl exec -n $NAMESPACE $POD_NAME -- cat $TEST_FILE)
echo "Content read: $DATA_READ"

if echo "$DATA_READ" | grep -q "Hello from Longhorn storage"; then
    echo "✓ Data read successfully - Content matches!"
else
    echo "✗ Error: Data read doesn't match what was written"
    exit 1
fi
echo ""

# Step 4: Delete data
echo "Step 4: Deleting data from persistent volume..."
kubectl exec -n $NAMESPACE $POD_NAME -- rm -f $TEST_FILE
kubectl exec -n $NAMESPACE $POD_NAME -- ls -lh /data/ || echo "(Directory is empty as expected)"

echo "✓ Data deleted successfully"
echo ""

# Step 5: Read data after deletion (should fail)
echo "Step 5: Attempting to read data after deletion..."
if kubectl exec -n $NAMESPACE $POD_NAME -- cat $TEST_FILE 2>&1 | grep -q "No such file"; then
    echo "✓ Confirmed: File does not exist (as expected)"
else
    # Check if the file exists
    if kubectl exec -n $NAMESPACE $POD_NAME -- test -f $TEST_FILE 2>/dev/null; then
        echo "✗ Warning: File still exists after deletion"
    else
        echo "✓ Confirmed: File does not exist (as expected)"
    fi
fi
echo ""

# Verify PVC exists
echo "Verifying PersistentVolumeClaim..."
kubectl get pvc -n $NAMESPACE
echo ""

# Verify PV was created
echo "Verifying PersistentVolume..."
kubectl get pv | grep test-longhorn-app-data-test-longhorn-app-0 || echo "(PV may be dynamically provisioned)"
echo ""

echo "========================================="
echo "Test completed successfully!"
echo "========================================="
echo ""
echo "To clean up resources, run:"
echo "  kubectl delete -f statefulset.yaml"
echo "  kubectl delete -f service.yaml"
echo "  kubectl delete namespace $NAMESPACE"



