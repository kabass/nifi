#!/bin/bash

# Script d'installation d'Ansible sur RedHat 10
# Ce script installe Ansible 2.15.13 avec les extensions Kubernetes

set -e

echo "=========================================="
echo "Installation d'Ansible 2.15.13"
echo "=========================================="

# Vérifier que nous sommes sur RedHat
if [ ! -f /etc/redhat-release ]; then
    echo "Erreur: Ce script est conçu pour RedHat 10"
    exit 1
fi

# Mettre à jour le système
echo "Mise à jour du système..."
sudo dnf update -y

# Installer les dépendances nécessaires
echo "Installation des dépendances..."
sudo dnf install -y \
    python3 \
    python3-pip \
    python3-devel \
    gcc \
    openssl-devel \
    libffi-devel \
    git

# Mettre à jour pip
echo "Mise à jour de pip..."
sudo python3 -m pip install --upgrade pip

# Installer Ansible 2.15.13
echo "Installation d'Ansible 2.15.13..."
sudo python3 -m pip install ansible==2.15.13

# Installer les collections Kubernetes pour Ansible
echo "Installation des collections Kubernetes..."
ansible-galaxy collection install kubernetes.core
ansible-galaxy collection install community.kubernetes

# Vérifier l'installation
echo "Vérification de l'installation..."
ansible --version
ansible-galaxy collection list | grep kubernetes

echo "=========================================="
echo "Ansible 2.15.13 installé avec succès!"
echo "=========================================="
