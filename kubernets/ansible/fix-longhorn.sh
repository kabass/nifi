#!/bin/bash
# Script pour corriger la configuration des disques Longhorn

set -e

KUBECONFIG_PATH="$(dirname "$0")/kube_config_cluster.yml"
LONGHORN_NAMESPACE="longhorn-system"
LONGHORN_DISK_PATH="/var/lib/longhorn"

echo "🔧 Correction de la configuration Longhorn..."

# Vérifier que kubectl est disponible
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl n'est pas installé"
    exit 1
fi

# Vérifier que le kubeconfig existe
if [ ! -f "$KUBECONFIG_PATH" ]; then
    echo "❌ Le fichier kubeconfig n'existe pas: $KUBECONFIG_PATH"
    exit 1
fi

export KUBECONFIG="$KUBECONFIG_PATH"

echo "📋 Étape 1: Configuration du répertoire sur les nœuds..."
# Créer le répertoire sur tous les nœuds via Ansible
cd "$(dirname "$0")"
ansible kubernetes -m shell -a "mkdir -p $LONGHORN_DISK_PATH && chmod 755 $LONGHORN_DISK_PATH" || echo "⚠️  Note: Assurez-vous que les nœuds sont accessibles via Ansible"

echo "📋 Étape 2: Configuration du setting Longhorn..."
# Configurer le chemin de données par défaut
kubectl patch setting default-data-path \
  -n "$LONGHORN_NAMESPACE" \
  --type merge \
  -p "{\"value\":\"$LONGHORN_DISK_PATH\"}" || echo "⚠️  Le setting existe déjà"

echo "📋 Étape 3: Configuration des disques pour chaque nœud..."
# Obtenir la liste des nœuds
NODES=$(kubectl get nodes -o jsonpath='{.items[*].metadata.name}')

for NODE in $NODES; do
    echo "  Configuring disk for node: $NODE"
    kubectl patch node.longhorn.io "$NODE" \
      -n "$LONGHORN_NAMESPACE" \
      --type merge \
      -p "{
        \"spec\": {
          \"allowScheduling\": true,
          \"disks\": {
            \"default-disk\": {
              \"path\": \"$LONGHORN_DISK_PATH\",
              \"allowScheduling\": true,
              \"evictionRequested\": false,
              \"storageReserved\": 0,
              \"tags\": []
            }
          }
        }
      }" || echo "  ⚠️  Erreur lors de la configuration du nœud $NODE (peut-être déjà configuré)"
done

echo "⏳ Attente de 10 secondes pour que Longhorn détecte les changements..."
sleep 10

echo "📊 Étape 4: Vérification de l'état..."
echo ""
echo "État des nœuds Longhorn:"
kubectl get nodes.longhorn.io -n "$LONGHORN_NAMESPACE" || echo "⚠️  Impossible de récupérer les nœuds Longhorn"

echo ""
echo "Volumes Longhorn:"
kubectl get volumes -n "$LONGHORN_NAMESPACE" | head -10 || echo "⚠️  Impossible de récupérer les volumes"

echo ""
echo "✅ Configuration terminée!"
echo ""
echo "Pour vérifier l'état complet:"
echo "  kubectl --kubeconfig=$KUBECONFIG_PATH get nodes.longhorn.io -n $LONGHORN_NAMESPACE"
echo "  kubectl --kubeconfig=$KUBECONFIG_PATH get volumes -n $LONGHORN_NAMESPACE"
echo ""
echo "Pour accéder à l'interface Longhorn:"
echo "  kubectl --kubeconfig=$KUBECONFIG_PATH port-forward -n $LONGHORN_NAMESPACE svc/longhorn-frontend 8080:80"
echo "  Puis ouvrez http://localhost:8080"

