#!/bin/bash
# Script helper pour utiliser kubectl avec le cluster RKE
# Usage: ./kubectl.sh <kubectl-command>
# Exemple: ./kubectl.sh get nodes

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KUBECONFIG_PATH="$SCRIPT_DIR/ansible/kube_config_cluster.yml"

if [ ! -f "$KUBECONFIG_PATH" ]; then
    echo "Erreur: Le fichier kubeconfig n'existe pas: $KUBECONFIG_PATH"
    echo "Déployez d'abord le cluster avec: cd ansible && ansible-playbook playbooks/deploy-rke.yml"
    exit 1
fi

export KUBECONFIG="$KUBECONFIG_PATH"
exec kubectl "$@"

