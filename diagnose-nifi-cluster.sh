#!/bin/bash

# Script de diagnostic pour le cluster NiFi
# Usage: ./diagnose-nifi-cluster.sh

NAMESPACE="data-platform-integration"

echo "=========================================="
echo "Diagnostic du cluster NiFi"
echo "=========================================="
echo ""

echo "1. État des pods NiFi:"
echo "----------------------"
kubectl get pods -n $NAMESPACE | grep nifi-platform-nifi
echo ""

echo "2. Configuration cluster de chaque pod:"
echo "----------------------------------------"
for pod in nifi-platform-nifi-0 nifi-platform-nifi-1 nifi-platform-nifi-2; do
  echo "=== $pod ==="
  echo "  - Cluster node address:"
  kubectl exec -n $NAMESPACE $pod -- grep "^nifi.cluster.node.address=" /opt/nifi/nifi-current/conf/nifi.properties 2>/dev/null || echo "    Non trouvé"
  echo "  - Cluster is node:"
  kubectl exec -n $NAMESPACE $pod -- grep "^nifi.cluster.is.node=" /opt/nifi/nifi-current/conf/nifi.properties 2>/dev/null || echo "    Non trouvé"
  echo "  - ZooKeeper connect string:"
  kubectl exec -n $NAMESPACE $pod -- grep "^nifi.zookeeper.connect.string=" /opt/nifi/nifi-current/conf/nifi.properties 2>/dev/null || echo "    Non trouvé"
  echo ""
done


echo "3. État dans ZooKeeper:"
echo "----------------------"
echo "Contenu de /nifi:"
kubectl exec -n $NAMESPACE nifi-platform-zookeeper-0 -- /bin/sh -c 'echo "ls /nifi" | /apache-zookeeper-3.9.4-bin/bin/zkCli.sh 2>/dev/null' | grep -v "INFO\|WARN\|DEBUG\|Connecting\|Client\|Welcome\|JLine\|WATCHER" | tail -5
echo ""

echo "4. Résolution DNS du headless service:"
echo "-------------------------------------"
kubectl exec -n $NAMESPACE nifi-platform-nifi-0 -- getent hosts nifi-platform-nifi-headless.data-platform-integration.svc.cluster.local 2>/dev/null || echo "Erreur de résolution DNS"
echo ""


echo "5. Derniers logs de chaque pod (erreurs/cluster):"
echo "------------------------------------------------"
for pod in nifi-platform-nifi-0 nifi-platform-nifi-1 nifi-platform-nifi-2; do
  echo "=== $pod ==="
  kubectl logs -n $NAMESPACE $pod --tail=50 2>/dev/null | grep -iE "error|exception|cluster|zookeeper|coordinator|node.*join" | tail -5 || echo "Aucun log pertinent"
  echo ""
done

echo "6. Vérification des services:"
echo "----------------------------"
kubectl get svc -n $NAMESPACE | grep nifi-platform-nifi
echo ""

echo "7. Vérification des heartbeats (derniers):"
echo "------------------------------------------"
for pod in nifi-platform-nifi-0 nifi-platform-nifi-1 nifi-platform-nifi-2; do
  echo "=== $pod ==="
  kubectl logs -n $NAMESPACE $pod --tail=10 2>/dev/null | grep -i "heartbeat.*sent to" | tail -1 || echo "Aucun heartbeat trouvé"
  echo ""
done

echo "=========================================="
echo "Diagnostic terminé"
echo "=========================================="

