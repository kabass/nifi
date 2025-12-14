#!/bin/bash
# Script pour configurer kubectl de manière permanente
# Ce script ajoute la configuration KUBECONFIG à votre shell profile

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KUBECONFIG_PATH="$SCRIPT_DIR/ansible/kube_config_cluster.yml"
SHELL_RC=""

# Détecter le shell
if [ -n "$ZSH_VERSION" ]; then
    SHELL_RC="$HOME/.zshrc"
elif [ -n "$BASH_VERSION" ]; then
    SHELL_RC="$HOME/.bashrc"
    # Sur macOS, utiliser .bash_profile si .bashrc n'existe pas
    if [ ! -f "$SHELL_RC" ] && [ -f "$HOME/.bash_profile" ]; then
        SHELL_RC="$HOME/.bash_profile"
    fi
else
    echo "Shell non supporté. Veuillez ajouter manuellement:"
    echo "export KUBECONFIG=\"$KUBECONFIG_PATH\""
    exit 1
fi

if [ ! -f "$KUBECONFIG_PATH" ]; then
    echo "Erreur: Le fichier kubeconfig n'existe pas: $KUBECONFIG_PATH"
    echo "Déployez d'abord le cluster avec: cd ansible && ansible-playbook playbooks/deploy-rke.yml"
    exit 1
fi

# Vérifier si la configuration existe déjà
if grep -q "KUBECONFIG.*kubernets.*kube_config_cluster" "$SHELL_RC" 2>/dev/null; then
    echo "La configuration KUBECONFIG existe déjà dans $SHELL_RC"
    exit 0
fi

# Ajouter la configuration
echo "" >> "$SHELL_RC"
echo "# Kubernetes cluster configuration (RKE)" >> "$SHELL_RC"
echo "export KUBECONFIG=\"$KUBECONFIG_PATH\"" >> "$SHELL_RC"

echo "Configuration ajoutée à $SHELL_RC"
echo "Rechargez votre shell avec: source $SHELL_RC"
echo "Ou ouvrez un nouveau terminal"

