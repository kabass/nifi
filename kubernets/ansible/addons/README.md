# Addons Kubernetes

Ce répertoire contient les manifests et configurations pour déployer les addons suivants dans le cluster Kubernetes :

- **Longhorn** : Solution de stockage persistant distribuée
- **cert-manager** : Gestion automatique des certificats TLS
- **MetalLB** : LoadBalancer pour clusters bare-metal

## Structure

```
addons/
├── longhorn/
│   └── namespace.yaml
├── cert-manager/
│   └── namespace.yaml
├── metallb/
│   ├── namespace.yaml
│   └── config.yaml
└── README.md
```

## Prérequis

1. Cluster Kubernetes déployé et fonctionnel
2. Fichier `kube_config_cluster.yml` généré par RKE
3. **Helm** installé sur la machine de déploiement (version 3.x)
   - macOS : `brew install helm`
   - Linux : Le playbook installera Helm automatiquement si nécessaire
4. Collections Ansible installées :
   ```bash
   ansible-galaxy collection install -r requirements.yml
   ```

## Déploiement

### Déployer tous les addons

```bash
cd /Users/bka/project/perso/cbao/kubernets/ansible
ansible-playbook playbooks/deploy-addons.yml
```

Le playbook déploie les addons via **Helm** dans l'ordre suivant :
1. **Longhorn** (via Helm chart) - pour créer la StorageClass
2. **cert-manager** (via Helm chart) - utilise Longhorn pour le stockage
3. **MetalLB** (via Helm chart) - pour l'exposition des services

**Avantages de l'installation via Helm :**
- Gestion simplifiée des versions
- Mises à jour facilitées
- Configuration via values
- Rollback possible

### Configuration MetalLB

Avant de déployer, modifiez le fichier `addons/metallb/config.yaml` pour définir la plage d'adresses IP que MetalLB utilisera :

```yaml
spec:
  addresses:
  - 192.168.1.240-192.168.1.250  # Modifiez selon votre réseau
```

### Versions

Les versions par défaut sont définies dans `playbooks/deploy-addons.yml` :
- Longhorn: `1.6.1` (Helm chart)
- cert-manager: `1.14.4` (Helm chart)
- MetalLB: `0.14.5` (Helm chart)

Pour modifier les versions, éditez les variables dans le playbook :
```yaml
longhorn_version: "1.6.1"
cert_manager_version: "1.14.4"
metallb_version: "0.14.5"
```

## Vérification

### Vérifier le statut des pods

```bash
kubectl --kubeconfig=kube_config_cluster.yml get pods --all-namespaces | grep -E 'longhorn|cert-manager|metallb'
```

### Vérifier la StorageClass Longhorn

```bash
kubectl --kubeconfig=kube_config_cluster.yml get storageclass longhorn
```

### Vérifier les releases Helm

```bash
helm list --all-namespaces --kubeconfig kube_config_cluster.yml
```

### Vérifier la configuration MetalLB

```bash
kubectl --kubeconfig=kube_config_cluster.yml get ipaddresspool -n metallb-system
kubectl --kubeconfig=kube_config_cluster.yml get l2advertisement -n metallb-system
```

## Utilisation

### Utiliser Longhorn comme StorageClass

Dans vos PersistentVolumeClaims, spécifiez :

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
spec:
  storageClassName: longhorn
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
```

### Utiliser cert-manager

Créez un ClusterIssuer pour Let's Encrypt :

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
```

### Utiliser MetalLB

Créez un service de type LoadBalancer :

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 8080
  selector:
    app: my-app
```

MetalLB attribuera automatiquement une adresse IP de la plage configurée.

## Interface Longhorn

Pour accéder à l'interface web de Longhorn, créez un ingress ou utilisez port-forward :

```bash
kubectl --kubeconfig=kube_config_cluster.yml port-forward -n longhorn-system svc/longhorn-frontend 8080:80
```

Puis accédez à http://localhost:8080

## Dépannage

### Longhorn ne démarre pas

Vérifiez que les nœuds ont les prérequis :
- open-iscsi installé
- NFS client installé (optionnel)

```bash
ansible kubernetes -m shell -a "apt-get install -y open-iscsi nfs-common"
```

### cert-manager ne démarre pas

Vérifiez que les CRDs sont installées :

```bash
kubectl --kubeconfig=kube_config_cluster.yml get crds | grep cert-manager
```

### MetalLB n'attribue pas d'IP

Vérifiez :
1. La configuration du pool d'adresses IP
2. Que les adresses IP sont disponibles sur le réseau
3. Les logs des pods MetalLB :

```bash
kubectl --kubeconfig=kube_config_cluster.yml logs -n metallb-system -l app=metallb
```

## Références

- [Documentation Longhorn](https://longhorn.io/docs/)
- [Documentation cert-manager](https://cert-manager.io/docs/)
- [Documentation MetalLB](https://metallb.universe.tf/)

