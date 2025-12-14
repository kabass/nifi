# ZooKeeper /nifi Node Analysis

## Summary

Checked the ZooKeeper `/nifi` node structure and NiFi cluster configuration to diagnose why only one node is visible in the NiFi UI.

## ZooKeeper Structure

**Current Structure:**
```
/nifi
├── /nifi/leaders
    ├── /nifi/leaders/Cluster Coordinator
    │   └── _c_07ce7a35-85de-4050-ade6-795e59212dfa-lock-0000000000
    └── /nifi/leaders/Primary Node
        └── _c_67311ea1-3560-4ad5-aad2-5cfe2f270f26-lock-0000000000
```

**Leader Information:**
- **Cluster Coordinator**: `nifi-platform-nifi-1.nifi-platform-nifi-headless.data-platform-integration.svc.cluster.local:8082`
- **Primary Node**: `nifi-platform-nifi-1.nifi-platform-nifi-headless.data-platform-integration.svc.cluster.local:8082`
- Both roles are held by the same node (nifi-1)

**Missing Structure:**
- ❌ No `/nifi/node` directory exists
- ❌ No `/nifi/nodes` directory exists  
- ❌ No `/nifi/cluster/nodes` directory exists
- **This is EXPECTED in NiFi 2.7.1** - nodes use peer-to-peer discovery, not ZooKeeper node registration
- In NiFi 2.7.1, ZooKeeper is only used for leader election (`/nifi/leaders`), not for node registration

## Cluster Status

**From NiFi API (`/nifi-api/controller/cluster`):**
```json
{
  "cluster": {
    "nodes": [{
      "nodeId": "c32eb01d-c19e-4e13-ad56-2ff0a974de53",
      "address": "localhost",  // ⚠️ PROBLEM: Should be FQDN
      "apiPort": 8080,
      "status": "CONNECTED",
      "roles": ["Primary Node", "Cluster Coordinator"]
    }]
  }
}
```

**Cluster Summary:**
- Connected Nodes: `1 / 1`
- Total Node Count: `1`
- Only one node visible despite 3 pods running

## Configuration Analysis

### ✅ Correctly Configured

1. **ZooKeeper Connection:**
   - `nifi.zookeeper.connect.string=nifi-platform-zookeeper:2181` ✓
   - `nifi.zookeeper.root.node=/nifi` ✓

2. **Cluster Node Addresses (in config files):**
   - Pod 0: `nifi-platform-nifi-0.nifi-platform-nifi-headless.data-platform-integration.svc.cluster.local` ✓
   - Pod 1: `nifi-platform-nifi-1.nifi-platform-nifi-headless.data-platform-integration.svc.cluster.local` ✓
   - Pod 2: `nifi-platform-nifi-2.nifi-platform-nifi-headless.data-platform-integration.svc.cluster.local` ✓

3. **Cluster Protocol:**
   - `nifi.cluster.is.node=true` ✓
   - `nifi.cluster.node.protocol.port=8082` ✓

### ❌ Issues Found

1. **Node Address in API shows "localhost":**
   - Configuration files have correct FQDNs
   - But API returns "localhost" as the address
   - This suggests NiFi is using web server hostname instead of cluster node address

2. **Cluster Protocol Security:**
   - `nifi.remote.input.secure=true` is set
   - But SSL might not be properly configured for cluster communication
   - This could prevent nodes from connecting to each other

3. **Missing Property:**
   - `nifi.cluster.protocol.is.secure` might need to be explicitly set
   - Should be `false` if not using SSL for cluster communication

## Logs Analysis

**From Pod Logs:**
- ✅ Nodes ARE connecting to ZooKeeper (CuratorLeaderElectionManager messages)
- ✅ Nodes ARE connecting to cluster ("This node is now connected to the cluster")
- ✅ Nodes ARE communicating (NODE_STATUS_CHANGE messages between nodes)
- ⚠️ But each node sees itself as "localhost:8080" instead of its FQDN

**Communication Evidence:**
```
INFO [Process Cluster Protocol Request-34] Finished processing request 
  from nifi-platform-nifi-2.nifi-platform-nifi-headless.data-platform-integration.svc.cluster.local
```

This shows nodes CAN communicate, but they're not properly identifying each other in the cluster.

## Root Cause

The issue appears to be that:
1. NiFi is using the web server hostname ("localhost") as the node identifier
2. Nodes can communicate but don't recognize each other as separate cluster nodes
3. This might be due to:
   - Missing `nifi.cluster.protocol.is.secure` property
   - SSL configuration mismatch (`nifi.remote.input.secure=true` but no SSL configured)
   - Web server hostname configuration issue

## Recommendations

### 1. Fix Cluster Protocol Security Configuration

Add to `nifi-configmap.yaml`:
```yaml
nifi.cluster.protocol.is.secure=false
```

And ensure `nifi.remote.input.secure` matches:
```yaml
nifi.remote.input.secure=false
```

### 2. Verify Web Server Hostname

Check if `nifi.web.http.host` or `nifi.web.https.host` needs to be set to the FQDN instead of defaulting to localhost.

### 3. Check Network Connectivity

Verify that all pods can reach each other on port 8082:
```bash
kubectl exec -n data-platform-integration nifi-platform-nifi-0 -- \
  nc -zv nifi-platform-nifi-1.nifi-platform-nifi-headless.data-platform-integration.svc.cluster.local 8082
```

### 4. Review NiFi 2.7.1 Cluster Discovery

In NiFi 2.7.1, cluster discovery works differently than older versions. Nodes should discover each other via:
- ZooKeeper leader election (working ✓)
- Direct peer-to-peer communication on port 8082 (needs verification)

### 5. Check for Firewall Configuration

Verify if `nifi.cluster.firewall.file` is set and if it's blocking node communication.

## Next Steps

1. Add `nifi.cluster.protocol.is.secure=false` to the configmap
2. Set `nifi.remote.input.secure=false` to match
3. Restart the NiFi pods
4. Verify cluster discovery after restart
5. Check if nodes now appear in the cluster API

## Commands for Verification

```bash
# Check ZooKeeper structure
kubectl exec -n data-platform-integration nifi-platform-zookeeper-0 -- \
  /bin/sh -c '/apache-zookeeper-3.9.4-bin/bin/zkCli.sh <<EOF
ls -R /nifi
quit
EOF'

# Check cluster status from each pod
for pod in nifi-platform-nifi-0 nifi-platform-nifi-1 nifi-platform-nifi-2; do
  echo "=== $pod ==="
  kubectl exec -n data-platform-integration $pod -- \
    curl -s http://localhost:8080/nifi-api/controller/cluster | jq '.cluster.nodes[] | {nodeId, address, status}'
done

# Check network connectivity
kubectl exec -n data-platform-integration nifi-platform-nifi-0 -- \
  nc -zv nifi-platform-nifi-1.nifi-platform-nifi-headless.data-platform-integration.svc.cluster.local 8082
```

