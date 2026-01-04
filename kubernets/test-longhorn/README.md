# Longhorn Storage Test

This directory contains resources to test Longhorn storage class with a Kubernetes StatefulSet.

## Files

- `statefulset.yaml`: StatefulSet definition using Longhorn storage class
- `service.yaml`: Headless service for the StatefulSet
- `test.sh`: Automated test script
- `cleanup.sh`: Script to clean up all test resources
- `README.md`: This file

## Prerequisites

- Kubernetes cluster with Longhorn installed
- `kubectl` configured to access the cluster
- Longhorn storage class named `longhorn` should be available

## Usage

### Run the test

```bash
chmod +x test.sh
./test.sh
```

The test script will:
1. Create the StatefulSet and Service
2. Wait for the pod to be ready
3. Write data to the persistent volume
4. Read the data back to verify
5. Delete the data
6. Verify the data is deleted
7. Display PVC and PV information

### Clean up resources

```bash
chmod +x cleanup.sh
./cleanup.sh
```

Or manually:

```bash
kubectl delete -f statefulset.yaml
kubectl delete -f service.yaml
kubectl delete namespace test-longhorn
```

## What gets created

- **Namespace**: `test-longhorn`
- **StatefulSet**: `test-longhorn-app` with 1 replica
- **Service**: Headless service `test-longhorn-service`
- **PVC**: `data-test-longhorn-app-0` using Longhorn storage class
- **PV**: Dynamically provisioned by Longhorn

## Manual testing

If you want to test manually:

```bash
# Create resources
kubectl apply -f service.yaml
kubectl apply -f statefulset.yaml

# Wait for pod
kubectl wait --for=condition=ready pod/test-longhorn-app-0 -n test-longhorn

# Write data
kubectl exec -n test-longhorn test-longhorn-app-0 -- sh -c "echo 'Test data' > /data/test.txt"

# Read data
kubectl exec -n test-longhorn test-longhorn-app-0 -- cat /data/test.txt

# Delete data
kubectl exec -n test-longhorn test-longhorn-app-0 -- rm /data/test.txt

# Verify deletion
kubectl exec -n test-longhorn test-longhorn-app-0 -- ls /data/

# Check PVC
kubectl get pvc -n test-longhorn

# Check PV
kubectl get pv | grep test-longhorn

# Clean up
kubectl delete -f statefulset.yaml -f service.yaml
kubectl delete namespace test-longhorn
```



