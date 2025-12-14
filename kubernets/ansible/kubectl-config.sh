#!/bin/bash
# Script pour configurer kubectl avec le kubeconfig du cluster RKE

KUBECONFIG_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/kube_config_cluster.yml"

if [ ! -f "$KUBECONFIG_PATH" ]; then
    echo "Erreur: Le fichier kubeconfig n'existe pas: $KUBECONFIG_PATH"
    echo "Déployez d'abord le cluster avec: ansible-playbook playbooks/deploy-rke.yml"
    exit 1
fi

export KUBECONFIG="$KUBECONFIG_PATH"
echo "KUBECONFIG configuré: $KUBECONFIG_PATH"
echo ""
echo "Vous pouvez maintenant utiliser kubectl normalement:"
echo "  kubectl get nodes"
echo "  kubectl get pods --all-namespaces"
echo ""
echo "Ou utiliser ce script pour exécuter des commandes:"
echo "  ./kubectl-config.sh kubectl get nodes"
echo ""

# Si des arguments sont fournis, exécuter la commande
if [ $# -gt 0 ]; then
    exec "$@"
fi

