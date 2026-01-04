# Controller Init - Préparation d'une machine RedHat 10

Ce dossier contient les scripts et playbooks Ansible pour préparer une machine RedHat 10 (localhost) en tant que contrôleur Kubernetes.

## Packages installés

- **kubectl** : version 1.30
- **Helm** : version 3.19.3
- **Ansible** : version 2.15.13 avec les extensions Kubernetes
- **Python** : version 3.10 avec le package kubernetes
- **git** : gestionnaire de versions
- **nano** : éditeur de texte

## Prérequis

- Machine RedHat 10 (exécution locale, pas besoin de SSH)
- Accès root ou utilisateur avec privilèges sudo
- Connexion Internet pour télécharger les packages

## Installation

### Étape 1 : Installer Ansible (si pas déjà installé)

Si Ansible n'est pas installé sur votre machine, exécutez le script d'installation :

```bash
chmod +x install-ansible.sh
./install-ansible.sh
```

### Étape 2 : Installer les collections Ansible requises

```bash
ansible-galaxy collection install -r requirements.yml
```

### Étape 3 : Exécuter le playbook

Le playbook s'exécute en localhost (pas besoin de SSH) :

```bash
ansible-playbook playbook.yml
```

Pour exécuter avec un mot de passe sudo (si nécessaire) :

```bash
ansible-playbook playbook.yml --ask-become-pass
```

## Structure des fichiers

- `install-ansible.sh` : Script shell pour installer Ansible sur la machine locale
- `playbook.yml` : Playbook Ansible principal qui installe tous les packages
- `inventory.ini` : Fichier d'inventory Ansible (configuré pour localhost)
- `ansible.cfg` : Configuration Ansible
- `requirements.yml` : Collections Ansible requises
- `README.md` : Ce fichier

## Vérification

Après l'exécution du playbook, vous pouvez vérifier les installations :

```bash
# Vérifier kubectl
kubectl version --client --short

# Vérifier Helm
helm version --short

# Vérifier Python
python3.10 --version

# Vérifier le package kubernetes Python
python3.10 -c "import kubernetes; print(kubernetes.__version__)"

# Vérifier git
git --version

# Vérifier nano
nano --version

# Vérifier Ansible
ansible --version
ansible-galaxy collection list | grep kubernetes
```

## Notes

- Le playbook nécessite des privilèges root (via `become: yes`)
- Les téléchargements se font depuis les sources officielles (Kubernetes, Helm)
- Python 3.10 est installé via dnf (si disponible) ou depuis les sources
- Le package Python `kubernetes` est installé via pip3.10

## Dépannage

### Problème de permissions sudo

Si vous utilisez un utilisateur non-root, assurez-vous qu'il peut exécuter sudo sans mot de passe ou utilisez `--ask-become-pass`.

### Problème avec les repositories

Si le repository Kubernetes n'est pas disponible, le playbook basculera automatiquement sur un téléchargement direct de kubectl.
