# Projet Ansible pour déploiement RKE (Rancher Kubernetes Engine)

Ce projet Ansible permet de déployer un cluster Kubernetes avec RKE sur trois nœuds.

## Architecture

Le cluster Kubernetes est composé de trois nœuds, chacun ayant les rôles :
- **controlplane** : Plan de contrôle Kubernetes
- **etcd** : Base de données distribuée pour les métadonnées du cluster
- **worker** : Nœuds de travail pour exécuter les pods

### Nœuds

- **node-1** : 65.109.229.12
- **node-2** : 37.27.253.78
- **node-3** : 77.42.23.65

## Prérequis

1. **Ansible** installé sur la machine de déploiement (version 2.9+)
   ```bash
   pip install ansible
   ```

2. **Accès SSH** aux trois nœuds avec la clé privée `vmkey`

3. **Python 3** installé sur tous les nœuds cibles

4. **Connexion Internet** sur tous les nœuds pour télécharger les packages

## Structure du projet

```
ansible/
├── ansible.cfg              # Configuration Ansible
├── cluster.yml              # Configuration RKE
├── inventory/
│   └── hosts.yml           # Inventaire des hôtes
├── group_vars/
│   └── all.yml             # Variables globales
├── playbooks/
│   ├── prepare-nodes.yml   # Préparation des nœuds
│   ├── deploy-rke.yml      # Déploiement RKE
│   └── deploy-addons.yml   # Déploiement des addons
├── addons/                  # Manifests des addons
│   ├── longhorn/
│   ├── cert-manager/
│   ├── metallb/
│   └── README.md
└── README.md               # Documentation
```

## Utilisation

### 1. Préparer les nœuds

Cette étape installe Docker et configure les prérequis système sur tous les nœuds :

```bash
cd ansible
ansible-playbook playbooks/prepare-nodes.yml
```

Cette commande va :
- Installer les packages requis
- Désactiver le swap
- Activer le forwarding IP
- Installer et configurer Docker
- Configurer les modules kernel nécessaires

### 2. Vérifier la préparation

Vérifier que tous les nœuds sont prêts :

```bash
ansible kubernetes -m ping
ansible kubernetes -m shell -a "docker --version"
```

### 3. Déployer RKE

Déployer le cluster Kubernetes avec RKE :

```bash
ansible-playbook playbooks/deploy-rke.yml
```

Cette commande va :
- Télécharger RKE si nécessaire
- Déployer le cluster selon la configuration `cluster.yml`
- Générer le fichier `kube_config_cluster.yml`

### 4. Configurer kubectl

Après le déploiement, configurer `kubectl` pour utiliser le nouveau cluster :

**Option 1 : Utiliser le script helper (recommandé)**
```bash
cd ansible
source kubectl-config.sh
kubectl get nodes
kubectl get pods --all-namespaces
```

**Option 2 : Exporter manuellement KUBECONFIG**
```bash
export KUBECONFIG=$(pwd)/kube_config_cluster.yml
kubectl get nodes
kubectl get pods --all-namespaces
```

**Option 3 : Ajouter à votre shell profile (permanent)**
Ajoutez cette ligne à votre `~/.bashrc` ou `~/.zshrc` :
```bash
export KUBECONFIG=/Users/bka/project/perso/cbao/kubernets/ansible/kube_config_cluster.yml
```

**Option 4 : Utiliser le script pour exécuter des commandes directement**
```bash
cd ansible
./kubectl-config.sh kubectl get nodes
./kubectl-config.sh helm list --all-namespaces
```

### 5. Déployer les addons (optionnel)

Le projet inclut des playbooks pour déployer des addons Kubernetes :

- **Longhorn** : Solution de stockage persistant distribuée
- **cert-manager** : Gestion automatique des certificats TLS
- **MetalLB** : LoadBalancer pour clusters bare-metal

**Important** : Avant de déployer, modifiez `addons/metallb/config.yaml` pour définir votre plage d'adresses IP.

```bash
# Installer les prérequis (open-iscsi pour Longhorn)
ansible kubernetes -m shell -a "apt-get install -y open-iscsi nfs-common"

# Déployer les addons
ansible-playbook playbooks/deploy-addons.yml
```

Pour plus de détails, consultez [addons/README.md](addons/README.md).

## Configuration

### Modifier la version de Kubernetes

Éditer `group_vars/all.yml` ou `cluster.yml` pour changer la version :

```yaml
kubernetes_version: "v1.28.0-rancher2-1"
```

### Modifier la configuration du réseau

Éditer `cluster.yml` pour changer le plugin réseau (canal, flannel, calico, etc.) :

```yaml
network:
  plugin: canal
```

### Ajouter des nœuds

Ajouter de nouveaux nœuds dans `inventory/hosts.yml` et `cluster.yml`.

## Dépannage

### Vérifier la connectivité SSH

```bash
ansible kubernetes -m ping
```

### Vérifier les logs RKE

```bash
rke up --config cluster.yml --debug
```

### Réinitialiser le cluster

```bash
rke remove --config cluster.yml
```

Puis redéployer avec :

```bash
ansible-playbook playbooks/deploy-rke.yml
```

### Corriger les problèmes Longhorn

Si vous rencontrez des erreurs de volumes Longhorn (disks are unavailable, ReplicaSchedulingFailure) :

**Méthode rapide (recommandée) :**
```bash
cd ansible
./fix-longhorn.sh
```

**Méthode avec Ansible playbooks :**
```bash
# Étape 1 : Configurer les répertoires sur les nœuds
ansible-playbook playbooks/configure-longhorn-disks.yml

# Étape 2 : Configurer Longhorn via l'API Kubernetes
ansible-playbook playbooks/fix-longhorn-disks.yml
```

**Vérifier l'état :**
```bash
export KUBECONFIG=$(pwd)/kube_config_cluster.yml
kubectl get nodes.longhorn.io -n longhorn-system
kubectl get volumes -n longhorn-system
```

**Accéder à l'interface Longhorn :**
```bash
kubectl port-forward -n longhorn-system svc/longhorn-frontend 8080:80
# Puis ouvrez http://localhost:8080
```

kubec### Vérifier l'état des nœuds

```bash
ansible kubernetes -m shell -a "systemctl status docker"
ansible kubernetes -m shell -a "docker ps"
```

### Problème de compatibilité Docker API

Si vous rencontrez l'erreur `client version 1.41 is too old. Minimum supported API version is 1.44`, cela signifie que Docker sur les nœuds nécessite l'API 1.44+ alors que RKE v1.8.8 utilise l'API 1.41.

**Solution 1 : Installer Docker 23.0.x (recommandé)**

Installer Docker 23.0.x qui supporte l'API 1.41 et est compatible avec RKE v1.8.8 :

**Option A : Utiliser le playbook dédié (recommandé)**

```bash
ansible-playbook playbooks/downgrade-docker.yml
```

**Option B : Installation manuelle**

```bash
# Pour Debian/Ubuntu - d'abord lister les versions disponibles
ansible kubernetes -m shell -a "apt-cache madison docker-ce | grep '5:23.0'"

# Puis installer une version spécifique (remplacer VERSION par la version trouvée)
ansible kubernetes -m shell -a "apt-get install -y docker-ce=VERSION docker-ce-cli=VERSION"

# Pour RHEL/CentOS
ansible kubernetes -m shell -a "yum install -y docker-ce-23.0.* docker-ce-cli-23.0.*"
```

**Solution 2 : Mettre à jour RKE**

Utiliser une version plus récente de RKE qui supporte Docker API 1.44+ (si disponible).

**Vérifier la version Docker API**

```bash
ansible kubernetes -m shell -a "docker version --format '{{ \"{{\" }}.Server.APIVersion{{ \"}}\" }}'"
```

Ou plus simplement :
```bash
ansible kubernetes -m shell -a 'docker version --format "{{.Server.APIVersion}}"'
```

## Sécurité

⚠️ **Important** : Le fichier `vmkey` (clé privée SSH) ne doit **jamais** être commité dans le dépôt Git. Il est déjà exclu via `.gitignore`.

Pour une utilisation en production, considérez :
- Utiliser Ansible Vault pour chiffrer les secrets
- Utiliser un bastion host pour l'accès SSH
- Configurer des règles de pare-feu appropriées
- Activer les politiques de sécurité des pods Kubernetes

## Documentation

- [Documentation RKE](https://rancher.com/docs/rke/latest/en/)
- [Documentation Ansible](https://docs.ansible.com/)
- [Documentation Kubernetes](https://kubernetes.io/docs/)

## Support

En cas de problème, vérifier :
1. La connectivité réseau vers les nœuds
2. Les permissions SSH
3. Les logs Ansible avec `-vvv`
4. Les logs RKE avec `--debug`

