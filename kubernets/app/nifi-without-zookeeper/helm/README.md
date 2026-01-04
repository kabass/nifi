# Helm Chart pour Apache Nifi et Nifi Registry

Ce Helm chart déploie Apache Nifi et Nifi Registry en mode cluster sur Kubernetes avec authentification Keycloak.

## Fonctionnalités

- ✅ **Apache Nifi en mode cluster** : Déploiement haute disponibilité avec ZooKeeper
- ✅ **Autoscaling dynamique** : HorizontalPodAutoscaler pour ajuster automatiquement le nombre de nodes
- ✅ **Découverte automatique des nodes** : Utilisation du service headless Kubernetes pour la découverte dynamique lors du scaling
- ✅ **Nifi Registry** : Gestion de versions des flows Nifi
- ✅ **Authentification Keycloak** : Intégration OIDC pour l'authentification SSO
- ✅ **Stockage persistant** : Volumes persistants pour les repositories
- ✅ **Ingress** : Configuration d'ingress pour l'accès externe
- ✅ **Sécurité SSL/TLS** : Support des certificats SSL

## Prérequis

- Kubernetes 1.19+
- Helm 3.0+
- Cluster Kubernetes avec :
  - StorageClass configuré pour les volumes persistants
  - Ingress Controller (nginx, traefik, etc.)
  - Keycloak déployé et configuré (optionnel mais recommandé)

## Installation

### 1. Préparation de Keycloak

Avant de déployer Nifi et Nifi Registry, vous devez configurer les clients OIDC dans Keycloak :

#### Client Nifi
- Créer un client `nifi` dans le realm `data-platform`
- Type : `openid-connect`
- Accès standard activé
- URLs de redirection : `https://nifi.data-platform.local/nifi-api/access/oidc/callback`
- Créer un secret client et le noter

#### Client Nifi Registry
- Créer un client `nifi-registry` dans le realm `data-platform`
- Type : `openid-connect`
- Accès standard activé
- URLs de redirection : `https://nifi-registry.data-platform.local/nifi-registry-api/access/oidc/callback`
- Créer un secret client et le noter

#### Groupes
- Créer les groupes : `nifi-admin`, `nifi-user`, `nifi-registry-admin`, `nifi-registry-user`

### 2. Préparation des secrets

Créez les secrets nécessaires (ou utilisez les secrets Kubernetes existants) :

```bash
# Encoder les secrets en base64
echo -n "votre-secret-nifi" | base64
echo -n "votre-secret-nifi-registry" | base64
echo -n "votre-password-keystore" | base64
echo -n "votre-password-truststore" | base64
echo -n "votre-password-postgresql" | base64
```

### 3. Configuration values.yaml

Copiez et modifiez le fichier `values.yaml` selon vos besoins :

```yaml
# Exemple de configuration minimale
nifi:
  enabled: true
  cluster:
    nodeCount: 3
  keycloak:
    enabled: true
    url: "https://keycloak.data-platform.local/auth"
    realm: "data-platform"
    clientId: "nifi"
    clientSecret: "votre-secret"  # Ou via secret Kubernetes

nifiRegistry:
  enabled: true
  database:
    type: postgresql
    postgresql:
      host: "postgresql.data-platform-storage.svc.cluster.local"
      port: 5432
      database: "nifi_registry"
      username: "nifi_registry"
      password: "votre-password"  # Ou via secret Kubernetes
  keycloak:
    enabled: true
    url: "https://keycloak.data-platform.local/auth"
    realm: "data-platform"
    clientId: "nifi-registry"
    clientSecret: "votre-secret"  # Ou via secret Kubernetes
```

### 4. Installation

```bash
# Ajouter le namespace si nécessaire
kubectl create namespace data-platform-integration

# Installer le chart
helm install nifi-platform . \
  --namespace data-platform-integration \
  --values values.yaml

# Ou avec des valeurs personnalisées
helm install nifi-platform . \
  --namespace data-platform-integration \
  --set nifi.cluster.nodeCount=3 \
  --set nifi.keycloak.url="https://keycloak.example.com/auth"
```

### 5. Vérification

```bash
# Vérifier les pods
kubectl get pods -n data-platform-integration

# Vérifier les services
kubectl get svc -n data-platform-integration

# Vérifier l'autoscaler (si activé)
kubectl get hpa -n data-platform-integration
kubectl describe hpa -n data-platform-integration nifi-platform-nifi

# Vérifier les logs
kubectl logs -n data-platform-integration -l app.kubernetes.io/component=nifi
kubectl logs -n data-platform-integration -l app.kubernetes.io/component=nifi-registry
```

## Configuration

### Variables principales

#### Nifi

| Variable | Description | Défaut |
|----------|-------------|--------|
| `nifi.enabled` | Activer Nifi | `true` |
| `nifi.cluster.nodeCount` | Nombre de nodes Nifi (si autoscaling désactivé) | `3` |
| `nifi.cluster.autoscaling.enabled` | Activer l'autoscaling horizontal | `false` |
| `nifi.cluster.autoscaling.minReplicas` | Nombre minimum de replicas | `3` |
| `nifi.cluster.autoscaling.maxReplicas` | Nombre maximum de replicas | `10` |
| `nifi.cluster.autoscaling.targetCPUUtilizationPercentage` | Cible d'utilisation CPU (%) | `70` |
| `nifi.cluster.autoscaling.targetMemoryUtilizationPercentage` | Cible d'utilisation mémoire (%) | `80` |
| `nifi.image.repository` | Image Docker | `apache/nifi` |
| `nifi.image.tag` | Version | `1.23.2` |
| `nifi.resources.requests.cpu` | CPU request | `2000m` |
| `nifi.resources.requests.memory` | Mémoire request | `4Gi` |
| `nifi.storage.size` | Taille du stockage | `50Gi` |
| `nifi.keycloak.enabled` | Activer Keycloak | `true` |
| `nifi.keycloak.url` | URL Keycloak | `https://keycloak.data-platform.local/auth` |
| `nifi.keycloak.realm` | Realm Keycloak | `data-platform` |
| `nifi.keycloak.clientId` | Client ID | `nifi` |

#### Nifi Registry

| Variable | Description | Défaut |
|----------|-------------|--------|
| `nifiRegistry.enabled` | Activer Nifi Registry | `true` |
| `nifiRegistry.replicas` | Nombre de replicas | `2` |
| `nifiRegistry.database.type` | Type de base de données | `postgresql` |
| `nifiRegistry.database.postgresql.host` | Host PostgreSQL | `postgresql.data-platform-storage.svc.cluster.local` |
| `nifiRegistry.keycloak.enabled` | Activer Keycloak | `true` |

#### ZooKeeper

| Variable | Description | Défaut |
|----------|-------------|--------|
| `nifi.cluster.zookeeper.enabled` | Activer ZooKeeper interne | `true` |
| `nifi.cluster.zookeeper.replicas` | Nombre de replicas ZooKeeper | `3` |
| `nifi.cluster.zookeeper.external.enabled` | Utiliser ZooKeeper externe | `false` |
| `nifi.cluster.zookeeper.external.connectionString` | Connection string ZooKeeper externe | `zookeeper:2181` |

### Activation de l'autoscaling

Pour activer l'autoscaling horizontal des pods Nifi :

```yaml
nifi:
  cluster:
    autoscaling:
      enabled: true
      minReplicas: 3
      maxReplicas: 10
      targetCPUUtilizationPercentage: 70
      targetMemoryUtilizationPercentage: 80
      behavior:
        scaleDown:
          stabilizationWindowSeconds: 300
          policies:
          - type: Percent
            value: 50
            periodSeconds: 60
        scaleUp:
          stabilizationWindowSeconds: 0
          policies:
          - type: Percent
            value: 100
            periodSeconds: 60
          - type: Pods
            value: 2
            periodSeconds: 60
          selectPolicy: Max
```

**Note** : Quand l'autoscaling est activé, le nombre initial de replicas sera `minReplicas` au lieu de `nodeCount`.

### Utilisation de ZooKeeper externe

Si vous avez déjà un cluster ZooKeeper, vous pouvez désactiver le ZooKeeper interne :

```yaml
nifi:
  cluster:
    zookeeper:
      enabled: false
      external:
        enabled: true
        connectionString: "zookeeper-external:2181"
```

### Configuration de la base de données Nifi Registry

#### PostgreSQL (recommandé pour la production)

```yaml
nifiRegistry:
  database:
    type: postgresql
    postgresql:
      host: "postgresql.example.com"
      port: 5432
      database: "nifi_registry"
      username: "nifi_registry"
      password: "password"
      ssl: false
```

#### H2 (pour développement/test)

```yaml
nifiRegistry:
  database:
    type: h2
    h2:
      dataDir: "./database"
```

### Gestion des secrets

#### Option 1 : Créer les secrets manuellement

```bash
kubectl create secret generic nifi-platform-keycloak \
  --from-literal=nifi-client-secret="votre-secret-nifi" \
  --from-literal=nifi-registry-client-secret="votre-secret-nifi-registry" \
  -n data-platform-integration

kubectl create secret generic nifi-platform-database \
  --from-literal=postgresql-password="votre-password" \
  -n data-platform-integration
```

Puis dans `values.yaml` :

```yaml
secrets:
  keycloak:
    create: false  # Les secrets existent déjà
  database:
    create: false  # Les secrets existent déjà
```

#### Option 2 : Laisser Helm créer les secrets

Dans `values.yaml`, encodez les secrets en base64 :

```yaml
secrets:
  keycloak:
    create: true
    nifiClientSecret: "base64-encoded-secret"
    nifiRegistryClientSecret: "base64-encoded-secret"
  database:
    create: true
    postgresqlPassword: "base64-encoded-password"
```

## Intégration Nifi ↔ Nifi Registry

Après le déploiement, configurez Nifi pour se connecter à Nifi Registry :

1. Accédez à l'interface Nifi : `https://nifi.data-platform.local`
2. Allez dans **Controller Settings** → **Registry Clients**
3. Cliquez sur **+** pour ajouter un nouveau client
4. Configurez :
   - **Name** : `Nifi Registry`
   - **URL** : `http://nifi-platform-nifi-registry:18080`
   - **Description** : `Nifi Registry for versioning`

## Mise à jour

```bash
# Mettre à jour le chart
helm upgrade nifi-platform . \
  --namespace data-platform-integration \
  --values values.yaml

# Vérifier le statut
helm status nifi-platform -n data-platform-integration
```

## Désinstallation

```bash
helm uninstall nifi-platform -n data-platform-integration

# Supprimer les PVCs si nécessaire (ATTENTION : perte de données)
kubectl delete pvc -n data-platform-integration -l app.kubernetes.io/name=nifi-platform
```

## Troubleshooting

### Vérifier l'autoscaler

```bash
# Voir le statut de l'autoscaler
kubectl get hpa -n data-platform-integration

# Voir les détails de l'autoscaler
kubectl describe hpa -n data-platform-integration nifi-platform-nifi

# Voir les événements de scaling
kubectl get events -n data-platform-integration --field-selector involvedObject.name=nifi-platform-nifi

# Vérifier les métriques utilisées par l'autoscaler
kubectl top pods -n data-platform-integration -l app.kubernetes.io/component=nifi
```

**Note** : L'autoscaler nécessite que le metrics-server soit installé dans le cluster Kubernetes.

### Découverte automatique des nodes lors du scaling

Le chart utilise un mécanisme de découverte automatique des nodes Nifi lors des opérations de scale out/in :

1. **Service Headless** : Chaque pod Nifi utilise le service headless Kubernetes pour obtenir son propre FQDN
   - Format : `<pod-name>.<headless-service>.<namespace>.svc.cluster.local`
   - Exemple : `nifi-platform-nifi-0.nifi-platform-nifi-headless.data-platform-integration.svc.cluster.local`

2. **Script d'entrypoint** : Un script d'entrypoint personnalisé :
   - Détecte automatiquement le nom du pod et le namespace
   - Génère dynamiquement l'adresse du cluster node pour chaque pod
   - Met à jour `nifi.properties` avec les valeurs correctes avant le démarrage
   - Vérifie que ZooKeeper est disponible

3. **Découverte via ZooKeeper** : Une fois démarrés, les nodes Nifi :
   - S'enregistrent automatiquement dans ZooKeeper avec leur identité unique
   - Découvrent les autres nodes via ZooKeeper
   - Formant ainsi un cluster dynamique qui s'adapte automatiquement aux changements de scale

**Avantages** :
- ✅ Pas de configuration manuelle nécessaire lors du scaling
- ✅ Chaque pod utilise automatiquement son propre FQDN unique
- ✅ Compatible avec l'autoscaling horizontal (HPA)
- ✅ Les nouveaux nodes rejoignent automatiquement le cluster via ZooKeeper

### Les pods Nifi ne démarrent pas

```bash
# Vérifier les logs
kubectl logs -n data-platform-integration <pod-name>

# Vérifier les événements
kubectl describe pod -n data-platform-integration <pod-name>

# Vérifier la connexion ZooKeeper
kubectl exec -it -n data-platform-integration <nifi-pod> -- nc -zv <zookeeper-service> 2181
```

### Problèmes d'authentification Keycloak

1. Vérifier que Keycloak est accessible depuis les pods Nifi
2. Vérifier les URLs de redirection dans Keycloak
3. Vérifier les secrets client dans les secrets Kubernetes
4. Vérifier les logs Nifi pour les erreurs OIDC

### Problèmes de connexion à la base de données

```bash
# Tester la connexion PostgreSQL depuis un pod
kubectl run -it --rm debug --image=postgres:14 --restart=Never -- \
  psql -h postgresql.data-platform-storage.svc.cluster.local -U nifi_registry -d nifi_registry
```

### Problèmes de stockage

```bash
# Vérifier les PVCs
kubectl get pvc -n data-platform-integration

# Vérifier les PVs
kubectl get pv

# Vérifier les événements de stockage
kubectl describe pvc -n data-platform-integration <pvc-name>
```

## Support

Pour toute question ou problème, contactez :
- Email : ka.bassirou@gmail.com
- Consultant : Bassirou KA

## Licence

Ce chart est fourni tel quel pour le déploiement d'Apache Nifi et Nifi Registry.

# nifi
