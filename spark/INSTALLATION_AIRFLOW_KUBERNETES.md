# Installation d'Apache Airflow sur Kubernetes

Ce document décrit les étapes complètes pour installer et configurer Apache Airflow sur Kubernetes avec authentification Keycloak, KubernetesPodExecutor et un exemple de job Spark.

## Table des matières

1. [Architecture Airflow](#1-architecture-airflow)
2. [Installation avec Helm Chart](#2-installation-avec-helm-chart)
3. [Configuration Authentification et Autorisation avec Keycloak](#3-configuration-authentification-et-autorisation-avec-keycloak)
4. [Configuration du KubernetesPodExecutor](#4-configuration-du-kubernetespodexecutor)
5. [Exemple de Job Spark avec DAG Airflow](#5-exemple-de-job-spark-avec-dag-airflow)

---

## 1. Architecture Airflow

### 1.1 Vue d'ensemble

Apache Airflow est une plateforme d'orchestration de workflows qui permet de programmer, planifier et surveiller des pipelines de données. Sur Kubernetes, Airflow utilise une architecture distribuée avec plusieurs composants.

### 1.2 Composants principaux

#### **Webserver**
- **Rôle** : Interface web pour visualiser et gérer les DAGs
- **Déploiement** : Deployment avec 2+ replicas pour haute disponibilité
- **Port** : 8080 (par défaut)
- **Fonctionnalités** :
  - Visualisation des DAGs et de leur statut
  - Logs des tâches
  - Gestion des connexions et variables
  - Interface d'administration

#### **Scheduler**
- **Rôle** : Planifie et déclenche l'exécution des tâches
- **Déploiement** : Deployment avec 2+ replicas pour haute disponibilité
- **Fonctionnalités** :
  - Parsing des DAGs
  - Planification des tâches selon les dépendances
  - Gestion des pools de ressources
  - Monitoring de l'état des tâches

#### **Workers (avec KubernetesPodExecutor)**
- **Rôle** : Exécution des tâches dans des pods Kubernetes dédiés
- **Déploiement** : Pas de workers permanents, création dynamique de pods
- **Avantages** :
  - Isolation complète entre les tâches
  - Scalabilité automatique
  - Utilisation optimale des ressources
  - Pas de conflit de dépendances

#### **Metadata Database**
- **Rôle** : Stockage des métadonnées (DAGs, tâches, connexions, variables, etc.)
- **Base de données** : PostgreSQL (recommandé pour production)
- **Déploiement** : StatefulSet ou base de données externe

#### **Redis/Celery (optionnel)**
- **Rôle** : Message broker pour CeleryExecutor (non utilisé avec KubernetesPodExecutor)
- **Note** : Non nécessaire avec KubernetesPodExecutor

### 1.3 Architecture Kubernetes

```
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                        │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              Namespace: airflow                       │  │
│  │                                                       │  │
│  │  ┌──────────────┐  ┌──────────────┐                 │  │
│  │  │  Webserver   │  │  Scheduler   │                 │  │
│  │  │  (2 replicas)│  │  (2 replicas)│                 │  │
│  │  └──────┬───────┘  └──────┬───────┘                 │  │
│  │         │                 │                           │  │
│  │         └────────┬────────┘                           │  │
│  │                  │                                     │  │
│  │         ┌────────▼────────┐                          │  │
│  │         │  PostgreSQL     │                          │  │
│  │         │  (Metadata DB)  │                          │  │
│  │         └─────────────────┘                          │  │
│  │                                                       │  │
│  │  ┌──────────────────────────────────────────────┐   │  │
│  │  │  KubernetesPodExecutor                       │   │  │
│  │  │  (Création dynamique de pods pour chaque     │   │  │
│  │  │   tâche)                                      │   │  │
│  │  │                                               │   │  │
│  │  │  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐     │   │  │
│  │  │  │ Pod  │  │ Pod  │  │ Pod  │  │ Pod  │     │   │  │
│  │  │  │Task 1│  │Task 2│  │Task 3│  │Task 4│     │   │  │
│  │  │  └──────┘  └──────┘  └──────┘  └──────┘     │   │  │
│  │  └──────────────────────────────────────────────┘   │  │
│  │                                                       │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │         Namespace: keycloak (ou autre)               │  │
│  │                                                       │  │
│  │  ┌──────────────────────────────────────────────┐   │  │
│  │  │  Keycloak (OAuth2/OIDC Provider)              │   │  │
│  │  └──────────────────────────────────────────────┘   │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### 1.4 Flux d'exécution avec KubernetesPodExecutor

1. Le **Scheduler** parse les DAGs et identifie les tâches à exécuter
2. Pour chaque tâche, le Scheduler crée un **Pod Kubernetes** via l'API Kubernetes
3. Le Pod exécute la tâche avec l'image Docker spécifiée
4. Les logs sont collectés depuis le Pod
5. Le Pod est supprimé après l'exécution (succès ou échec)
6. Le **Webserver** affiche le statut et les logs

---

## 2. Installation avec Helm Chart

### 2.1 Prérequis

- Cluster Kubernetes fonctionnel (version 1.20+)
- `kubectl` configuré et connecté au cluster
- `helm` installé (version 3.0+)
- Accès administrateur au cluster
- Namespace créé pour Airflow

### 2.2 Ajout du repository Helm Airflow

Le chart Helm officiel d'Airflow est maintenu par la communauté Apache Airflow.

```bash
# Ajouter le repository Helm officiel Airflow
helm repo add apache-airflow https://airflow.apache.org
helm repo update

# Vérifier que le repository est ajouté
helm repo list
```

**Référence** : [https://airflow.apache.org/docs/helm-chart/stable/index.html](https://airflow.apache.org/docs/helm-chart/stable/index.html)

### 2.3 Création du namespace

```bash
# Créer le namespace pour Airflow
kubectl create namespace airflow

# Vérifier la création
kubectl get namespace airflow
```

### 2.4 Préparation des valeurs Helm

Créer un fichier `values-airflow.yaml` avec la configuration de base :

```yaml
# values-airflow.yaml
executor: "KubernetesExecutor"

# Configuration PostgreSQL (externe ou interne)
postgresql:
  enabled: true
  auth:
    username: airflow
    password: airflow
    database: airflow
  persistence:
    enabled: true
    size: 20Gi

# Configuration Redis (non nécessaire avec KubernetesExecutor)
redis:
  enabled: false

# Configuration Webserver
webserver:
  replicas: 2
  resources:
    requests:
      cpu: 500m
      memory: 1Gi
    limits:
      cpu: 1000m
      memory: 2Gi
  defaultAirflowRepository: apache/airflow
  defaultAirflowTag: "2.8.0"
  allowPodLaunching: true
  webserverConfig: |
    [webserver]
    base_url = http://localhost:8080
    default_timezone = UTC
    enable_proxy_fix = True
    expose_config = True
    secret_key = changeme-in-production

# Configuration Scheduler
scheduler:
  replicas: 2
  resources:
    requests:
      cpu: 500m
      memory: 1Gi
    limits:
      cpu: 2000m
      memory: 2Gi

# Configuration KubernetesExecutor
kubernetesExecutor:
  enabled: true
  # ServiceAccount pour les pods de tâches
  serviceAccount:
    create: true
    name: airflow-worker
  # Namespace où créer les pods de tâches
  namespace: airflow
  # Image par défaut pour les pods
  image:
    repository: apache/airflow
    tag: "2.8.0"
  # Ressources par défaut pour les pods
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: 1000m
      memory: 1Gi

# Configuration des logs
logs:
  persistence:
    enabled: true
    size: 10Gi

# Configuration des secrets (à personnaliser)
secret:
  # Générer avec: openssl rand -base64 32
  airflowSecretKey: "changeme-in-production-generate-secure-key"

# Configuration des variables d'environnement
env:
  - name: AIRFLOW__CORE__EXECUTOR
    value: "KubernetesExecutor"
  - name: AIRFLOW__KUBERNETES_EXECUTOR__NAMESPACE
    value: "airflow"
  - name: AIRFLOW__KUBERNETES_EXECUTOR__WORKER_CONTAINER_REPOSITORY
    value: "apache/airflow"
  - name: AIRFLOW__KUBERNETES_EXECUTOR__WORKER_CONTAINER_TAG
    value: "2.8.0"
  - name: AIRFLOW__KUBERNETES_EXECUTOR__DELETE_WORKER_PODS
    value: "true"
  - name: AIRFLOW__KUBERNETES_EXECUTOR__KUBE_CLIENT_REQUEST_ARGS
    value: '{"_request_timeout": [60, 360]}'
```

### 2.5 Installation avec Helm

```bash
# Installer Airflow avec le fichier de valeurs
helm install airflow apache-airflow/airflow \
  --namespace airflow \
  --values values-airflow.yaml \
  --version 1.0.0

# Vérifier l'installation
helm list -n airflow

# Vérifier les pods
kubectl get pods -n airflow

# Vérifier les services
kubectl get svc -n airflow
```

### 2.6 Accès au Webserver

#### Port-forward temporaire (pour test)

```bash
# Port-forward vers le webserver
kubectl port-forward svc/airflow-webserver 8080:8080 -n airflow

# Accéder à http://localhost:8080
# Identifiants par défaut : admin / admin
```

#### Configuration Ingress (production)

Créer un fichier `ingress-airflow.yaml` :

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: airflow-ingress
  namespace: airflow
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - airflow.example.com
      secretName: airflow-tls
  rules:
    - host: airflow.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: airflow-webserver
                port:
                  number: 8080
```

Appliquer l'ingress :

```bash
kubectl apply -f ingress-airflow.yaml
```

### 2.7 Vérification de l'installation

```bash
# Vérifier tous les composants
kubectl get all -n airflow

# Vérifier les logs du scheduler
kubectl logs -n airflow -l component=scheduler --tail=50

# Vérifier les logs du webserver
kubectl logs -n airflow -l component=webserver --tail=50

# Vérifier la connexion à la base de données
kubectl exec -n airflow -it airflow-postgresql-0 -- psql -U airflow -d airflow -c "SELECT COUNT(*) FROM dag;"
```

---

## 3. Configuration Authentification et Autorisation avec Keycloak

### 3.1 Prérequis Keycloak

- Keycloak déployé et accessible
- Realm configuré dans Keycloak
- Client OAuth2/OIDC créé pour Airflow

### 3.2 Configuration du Client dans Keycloak

1. **Accéder à Keycloak Admin Console**
2. **Sélectionner le Realm** (ex: `data-platform`)
3. **Créer un nouveau Client** :
   - Client ID : `airflow`
   - Client Protocol : `openid-connect`
   - Access Type : `confidential`
   - Valid Redirect URIs : `https://airflow.example.com/oauth2/callback`
   - Web Origins : `https://airflow.example.com`
4. **Récupérer les credentials** :
   - Client ID : `airflow`
   - Client Secret : (à copier depuis l'onglet Credentials)

### 3.3 Installation du plugin Airflow-Keycloak

Le plugin `airflow-auth-managers` ou `flask-appbuilder` doit être configuré pour utiliser Keycloak.

#### Option 1 : Utiliser Flask-AppBuilder avec OAuth2

Modifier `values-airflow.yaml` pour ajouter la configuration Keycloak :

```yaml
# Ajout dans values-airflow.yaml
webserver:
  webserverConfig: |
    [webserver]
    base_url = https://airflow.example.com
    default_timezone = UTC
    enable_proxy_fix = True
    expose_config = True
    secret_key = changeme-in-production
    
    [webserver_config]
    # Configuration Flask-AppBuilder pour OAuth2
    AUTH_TYPE = AUTH_OAUTH
    AUTH_ROLES_SYNC_AT_LOGIN = True
    AUTH_USER_REGISTRATION = True
    AUTH_USER_REGISTRATION_ROLE = "Public"
    
    # Configuration OAuth2 Keycloak
    OAUTH_PROVIDERS = [
        {
            'name': 'keycloak',
            'token_key': 'access_token',
            'icon': 'fa-key',
            'remote_app': {
                'client_id': 'airflow',
                'client_secret': 'YOUR_CLIENT_SECRET_HERE',
                'server_metadata_url': 'https://keycloak.example.com/realms/data-platform/.well-known/openid-configuration',
                'client_kwargs': {
                    'scope': 'openid email profile'
                },
                'access_token_url': 'https://keycloak.example.com/realms/data-platform/protocol/openid-connect/token',
                'authorize_url': 'https://keycloak.example.com/realms/data-platform/protocol/openid-connect/auth',
                'api_base_url': 'https://keycloak.example.com/realms/data-platform/protocol/openid-connect',
            }
        }
    ]
    
    # Mapping des rôles Keycloak vers Airflow
    AUTH_ROLES_MAPPING = {
        'admin': ['Admin'],
        'user': ['User'],
        'viewer': ['Viewer'],
        'public': ['Public']
    }

# Variables d'environnement supplémentaires
env:
  - name: AIRFLOW__API__AUTH_BACKENDS
    value: "airflow.api.auth.backend.basic_auth,airflow.api.auth.backend.session"
  - name: AIRFLOW__WEBSERVER__EXPOSE_CONFIG
    value: "True"
```

#### Option 2 : Utiliser un Secret Kubernetes pour le Client Secret

Créer un secret Kubernetes pour stocker le client secret :

```bash
# Créer le secret
kubectl create secret generic airflow-keycloak-secret \
  --from-literal=client-secret='YOUR_CLIENT_SECRET_HERE' \
  -n airflow
```

Modifier `values-airflow.yaml` pour référencer le secret :

```yaml
webserver:
  extraEnv:
    - name: KEYCLOAK_CLIENT_SECRET
      valueFrom:
        secretKeyRef:
          name: airflow-keycloak-secret
          key: client-secret
```

### 3.4 Configuration des Rôles Airflow

Les rôles Airflow doivent être mappés aux rôles Keycloak. Créer un script d'initialisation :

```python
# scripts/init_airflow_roles.py
from airflow import settings
from airflow.models import Role
from airflow.utils.db import create_session

roles = [
    {'name': 'Admin', 'description': 'Full access'},
    {'name': 'User', 'description': 'Standard user'},
    {'name': 'Viewer', 'description': 'Read-only access'},
    {'name': 'Public', 'description': 'Public access'},
]

with create_session() as session:
    for role_data in roles:
        role = session.query(Role).filter(Role.name == role_data['name']).first()
        if not role:
            role = Role(**role_data)
            session.add(role)
    session.commit()
```

### 3.5 Installation des dépendances Python

Ajouter les packages nécessaires dans `values-airflow.yaml` :

```yaml
# Configuration des images avec packages supplémentaires
images:
  airflow:
    repository: apache/airflow
    tag: "2.8.0"
    pullPolicy: IfNotPresent

# Installation de packages Python supplémentaires
airflow:
  extraPipPackages:
    - "flask-appbuilder[oauth]>=4.0.0"
    - "authlib>=1.0.0"
```

### 3.6 Mise à jour de l'installation Helm

```bash
# Mettre à jour l'installation avec la nouvelle configuration
helm upgrade airflow apache-airflow/airflow \
  --namespace airflow \
  --values values-airflow.yaml \
  --version 1.0.0

# Redémarrer les pods pour appliquer les changements
kubectl rollout restart deployment/airflow-webserver -n airflow
kubectl rollout restart deployment/airflow-scheduler -n airflow

# Vérifier les logs
kubectl logs -n airflow -l component=webserver --tail=100
```

### 3.7 Test de l'authentification

1. Accéder à `https://airflow.example.com`
2. Cliquer sur "Sign In with Keycloak"
3. S'authentifier avec les credentials Keycloak
4. Vérifier que l'utilisateur est redirigé vers Airflow avec les bons rôles

### 3.8 Configuration RBAC avancée

Pour une gestion fine des permissions, créer des rôles personnalisés dans Airflow :

```python
# DAG pour créer des rôles personnalisés
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.utils.dates import days_ago
from airflow.models import Role, Permission
from airflow.utils.db import create_session

def create_custom_roles():
    with create_session() as session:
        # Créer un rôle "Data Engineer"
        role = session.query(Role).filter(Role.name == 'Data Engineer').first()
        if not role:
            role = Role(name='Data Engineer')
            session.add(role)
        session.commit()

dag = DAG(
    'setup_airflow_roles',
    default_args={'owner': 'admin'},
    start_date=days_ago(1),
    schedule_interval=None,
    catchup=False
)

create_roles_task = PythonOperator(
    task_id='create_custom_roles',
    python_callable=create_custom_roles,
    dag=dag
)
```

---

## 4. Configuration du KubernetesPodExecutor

### 4.1 Vue d'ensemble

Le `KubernetesPodExecutor` permet d'exécuter chaque tâche Airflow dans un pod Kubernetes dédié. Cela offre :
- Isolation complète entre les tâches
- Scalabilité automatique
- Utilisation d'images Docker personnalisées
- Gestion fine des ressources

### 4.2 Configuration de base

Modifier `values-airflow.yaml` pour configurer KubernetesPodExecutor :

```yaml
# Configuration KubernetesExecutor
executor: "KubernetesExecutor"

kubernetesExecutor:
  enabled: true
  
  # ServiceAccount pour les pods de tâches
  serviceAccount:
    create: true
    name: airflow-worker
  
  # Namespace où créer les pods
  namespace: airflow
  
  # Image par défaut pour les pods
  image:
    repository: apache/airflow
    tag: "2.8.0"
  
  # Ressources par défaut
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: 1000m
      memory: 1Gi

# Variables d'environnement pour KubernetesExecutor
env:
  - name: AIRFLOW__CORE__EXECUTOR
    value: "KubernetesExecutor"
  - name: AIRFLOW__KUBERNETES_EXECUTOR__NAMESPACE
    value: "airflow"
  - name: AIRFLOW__KUBERNETES_EXECUTOR__WORKER_CONTAINER_REPOSITORY
    value: "apache/airflow"
  - name: AIRFLOW__KUBERNETES_EXECUTOR__WORKER_CONTAINER_TAG
    value: "2.8.0"
  - name: AIRFLOW__KUBERNETES_EXECUTOR__DELETE_WORKER_PODS
    value: "true"
  - name: AIRFLOW__KUBERNETES_EXECUTOR__DELETE_WORKER_PODS_ON_FAILURE
    value: "true"
  - name: AIRFLOW__KUBERNETES_EXECUTOR__KUBE_CLIENT_REQUEST_ARGS
    value: '{"_request_timeout": [60, 360]}'
  - name: AIRFLOW__KUBERNETES_EXECUTOR__WORKER_CONTAINER_REPOSITORY_PULL_POLICY
    value: "IfNotPresent"
  - name: AIRFLOW__KUBERNETES_EXECUTOR__RUN_AS_USER
    value: "50000"
  - name: AIRFLOW__KUBERNETES_EXECUTOR__FS_GROUP
    value: "50000"
```

### 4.3 Configuration du ServiceAccount

Le ServiceAccount doit avoir les permissions nécessaires pour créer des pods :

```yaml
# serviceaccount-airflow-worker.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: airflow-worker
  namespace: airflow
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: airflow-worker
  namespace: airflow
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["create", "get", "list", "watch", "delete", "patch"]
  - apiGroups: [""]
    resources: ["pods/log"]
    verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: airflow-worker
  namespace: airflow
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: airflow-worker
subjects:
  - kind: ServiceAccount
    name: airflow-worker
    namespace: airflow
```

Appliquer la configuration :

```bash
kubectl apply -f serviceaccount-airflow-worker.yaml
```

### 4.4 Configuration des connexions Airflow

Pour accéder à des services externes (MINIO, PostgreSQL, etc.), configurer les connexions dans Airflow :

```bash
# Via l'interface web : Admin > Connections
# Ou via CLI
kubectl exec -n airflow -it airflow-scheduler-0 -- airflow connections add \
  'minio_s3' \
  --conn-type 's3' \
  --conn-extra '{"aws_access_key_id": "minioadmin", "aws_secret_access_key": "minioadmin", "endpoint_url": "http://minio:9000"}'
```

### 4.5 Utilisation dans un DAG

Exemple de DAG utilisant KubernetesPodOperator :

```python
from airflow import DAG
from airflow.providers.cncf.kubernetes.operators.kubernetes_pod import KubernetesPodOperator
from airflow.utils.dates import days_ago
from kubernetes.client import models as k8s

default_args = {
    'owner': 'data-engineer',
    'depends_on_past': False,
    'start_date': days_ago(1),
    'email_on_failure': False,
    'email_on_retry': False,
}

dag = DAG(
    'example_kubernetes_pod',
    default_args=default_args,
    description='Exemple de DAG avec KubernetesPodOperator',
    schedule_interval='@daily',
    catchup=False,
)

# Tâche avec image personnalisée
task_with_custom_image = KubernetesPodOperator(
    task_id='task_with_custom_image',
    name='task-custom-image',
    namespace='airflow',
    image='python:3.9-slim',
    cmds=['python', '-c'],
    arguments=['print("Hello from Kubernetes Pod!")'],
    labels={'app': 'airflow'},
    get_logs=True,
    dag=dag,
)

# Tâche avec variables d'environnement
task_with_env = KubernetesPodOperator(
    task_id='task_with_env',
    name='task-env',
    namespace='airflow',
    image='python:3.9-slim',
    cmds=['python', '-c'],
    arguments=['import os; print(os.environ.get("MY_VAR", "Not set"))'],
    env_vars={
        'MY_VAR': 'my_value',
    },
    get_logs=True,
    dag=dag,
)

# Tâche avec ressources personnalisées
task_with_resources = KubernetesPodOperator(
    task_id='task_with_resources',
    name='task-resources',
    namespace='airflow',
    image='python:3.9-slim',
    cmds=['python', '-c'],
    arguments=['import time; time.sleep(10); print("Task completed")'],
    resources=k8s.V1ResourceRequirements(
        requests={'memory': '512Mi', 'cpu': '500m'},
        limits={'memory': '1Gi', 'cpu': '1000m'},
    ),
    get_logs=True,
    dag=dag,
)

task_with_custom_image >> task_with_env >> task_with_resources
```

### 4.6 Configuration avancée

#### Utilisation de ConfigMaps et Secrets

```python
from airflow import DAG
from airflow.providers.cncf.kubernetes.operators.kubernetes_pod import KubernetesPodOperator
from kubernetes.client import models as k8s

dag = DAG('example_with_configmap', ...)

task = KubernetesPodOperator(
    task_id='task_with_configmap',
    namespace='airflow',
    image='python:3.9-slim',
    cmds=['python', '-c'],
    arguments=['import os; print(os.environ.get("CONFIG_VAR"))'],
    configmaps=['my-configmap'],
    env_from=[
        k8s.V1EnvFromSource(
            config_map_ref=k8s.V1ConfigMapEnvSource(name='my-configmap')
        )
    ],
    dag=dag,
)
```

#### Utilisation de volumes persistants

```python
task_with_volume = KubernetesPodOperator(
    task_id='task_with_volume',
    namespace='airflow',
    image='python:3.9-slim',
    cmds=['python', '-c'],
    arguments=['import os; print(os.listdir("/data"))'],
    volumes=[
        k8s.V1Volume(
            name='data-volume',
            persistent_volume_claim=k8s.V1PersistentVolumeClaimVolumeSource(
                claim_name='my-pvc'
            )
        )
    ],
    volume_mounts=[
        k8s.V1VolumeMount(
            name='data-volume',
            mount_path='/data'
        )
    ],
    dag=dag,
)
```

---

## 5. Exemple de Job Spark avec DAG Airflow

### 5.1 Préparation de l'image Docker Spark

Créer un Dockerfile pour l'image Spark :

```dockerfile
# Dockerfile.spark
FROM apache/spark:3.5.0-scala2.12-java11-python3-ubuntu

# Installer les dépendances Python nécessaires
RUN pip install --no-cache-dir \
    pyspark==3.5.0 \
    boto3 \
    pandas \
    pyarrow

# Copier les scripts Spark
COPY spark-jobs/ /opt/spark/work-dir/

WORKDIR /opt/spark/work-dir

# Utilisateur non-root
USER spark
```

Créer le script Spark :

```python
# spark-jobs/process_data.py
from pyspark.sql import SparkSession
import sys
import os

def main():
    # Récupérer les arguments
    input_path = sys.argv[1] if len(sys.argv) > 1 else "/data/input"
    output_path = sys.argv[2] if len(sys.argv) > 2 else "/data/output"
    
    # Configuration MINIO (S3-compatible)
    minio_endpoint = os.getenv("MINIO_ENDPOINT", "http://minio:9000")
    minio_access_key = os.getenv("MINIO_ACCESS_KEY", "minioadmin")
    minio_secret_key = os.getenv("MINIO_SECRET_KEY", "minioadmin")
    
    # Créer la session Spark
    spark = SparkSession.builder \
        .appName("AirflowSparkJob") \
        .config("spark.hadoop.fs.s3a.endpoint", minio_endpoint) \
        .config("spark.hadoop.fs.s3a.access.key", minio_access_key) \
        .config("spark.hadoop.fs.s3a.secret.key", minio_secret_key) \
        .config("spark.hadoop.fs.s3a.path.style.access", "true") \
        .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem") \
        .config("spark.sql.warehouse.dir", "s3a://warehouse/") \
        .getOrCreate()
    
    try:
        # Lire les données
        print(f"Reading data from {input_path}")
        df = spark.read.parquet(input_path)
        
        # Afficher le schéma
        df.printSchema()
        print(f"Total rows: {df.count()}")
        
        # Transformation des données
        print("Processing data...")
        processed_df = df \
            .filter(df["status"] == "active") \
            .groupBy("category") \
            .agg({"amount": "sum", "id": "count"}) \
            .withColumnRenamed("sum(amount)", "total_amount") \
            .withColumnRenamed("count(id)", "record_count")
        
        # Écrire les résultats
        print(f"Writing results to {output_path}")
        processed_df.write \
            .mode("overwrite") \
            .parquet(output_path)
        
        print("Job completed successfully!")
        
    except Exception as e:
        print(f"Error: {str(e)}")
        raise
    finally:
        spark.stop()

if __name__ == "__main__":
    main()
```

Construire et pousser l'image :

```bash
# Construire l'image
docker build -f Dockerfile.spark -t my-registry/spark-airflow:3.5.0 .

# Pousser l'image vers le registry
docker push my-registry/spark-airflow:3.5.0
```

### 5.2 DAG Airflow pour le Job Spark

Créer le DAG Airflow :

```python
# dags/spark_job_dag.py
from airflow import DAG
from airflow.providers.cncf.kubernetes.operators.kubernetes_pod import KubernetesPodOperator
from airflow.utils.dates import days_ago
from datetime import datetime, timedelta
from kubernetes.client import models as k8s

# Arguments par défaut
default_args = {
    'owner': 'data-engineer',
    'depends_on_past': False,
    'start_date': days_ago(1),
    'email_on_failure': True,
    'email_on_retry': False,
    'retries': 2,
    'retry_delay': timedelta(minutes=5),
}

# Définition du DAG
dag = DAG(
    'spark_data_processing',
    default_args=default_args,
    description='DAG pour exécuter un job Spark de traitement de données',
    schedule_interval='@daily',
    catchup=False,
    tags=['spark', 'data-processing', 'etl'],
)

# Configuration des variables d'environnement pour MINIO
minio_env_vars = [
    k8s.V1EnvVar(name='MINIO_ENDPOINT', value='http://minio.data-platform-storage:9000'),
    k8s.V1EnvVar(name='MINIO_ACCESS_KEY', value='minioadmin'),
    k8s.V1EnvVar(name='MINIO_SECRET_KEY', value='minioadmin'),
    k8s.V1EnvVar(name='SPARK_MASTER', value='local[*]'),
]

# Tâche 1 : Validation des données d'entrée
validate_input = KubernetesPodOperator(
    task_id='validate_input_data',
    name='spark-validate-input',
    namespace='airflow',
    image='my-registry/spark-airflow:3.5.0',
    cmds=['python', '-c'],
    arguments=[
        '''
from pyspark.sql import SparkSession
import os

spark = SparkSession.builder.appName("ValidateInput").getOrCreate()
input_path = os.getenv("INPUT_PATH", "s3a://data-lake/raw/input/")
df = spark.read.parquet(input_path)
print(f"Input data count: {df.count()}")
print(f"Input schema: {df.schema}")
spark.stop()
        '''
    ],
    env_vars={
        'INPUT_PATH': 's3a://data-lake/raw/input/{{ ds }}',
        **{env.name: env.value for env in minio_env_vars}
    },
    resources=k8s.V1ResourceRequirements(
        requests={'memory': '1Gi', 'cpu': '500m'},
        limits={'memory': '2Gi', 'cpu': '1000m'},
    ),
    get_logs=True,
    dag=dag,
)

# Tâche 2 : Traitement principal avec Spark
process_data = KubernetesPodOperator(
    task_id='process_data_with_spark',
    name='spark-process-data',
    namespace='airflow',
    image='my-registry/spark-airflow:3.5.0',
    cmds=['python'],
    arguments=[
        '/opt/spark/work-dir/process_data.py',
        's3a://data-lake/raw/input/{{ ds }}',
        's3a://data-lake/processed/output/{{ ds }}',
    ],
    env_vars={
        **{env.name: env.value for env in minio_env_vars}
    },
    resources=k8s.V1ResourceRequirements(
        requests={'memory': '2Gi', 'cpu': '1000m'},
        limits={'memory': '4Gi', 'cpu': '2000m'},
    ),
    get_logs=True,
    dag=dag,
)

# Tâche 3 : Validation des données de sortie
validate_output = KubernetesPodOperator(
    task_id='validate_output_data',
    name='spark-validate-output',
    namespace='airflow',
    image='my-registry/spark-airflow:3.5.0',
    cmds=['python', '-c'],
    arguments=[
        '''
from pyspark.sql import SparkSession
import os

spark = SparkSession.builder.appName("ValidateOutput").getOrCreate()
output_path = os.getenv("OUTPUT_PATH", "s3a://data-lake/processed/output/")
df = spark.read.parquet(output_path)
print(f"Output data count: {df.count()}")
print(f"Output schema: {df.schema}")
df.show(10)
spark.stop()
        '''
    ],
    env_vars={
        'OUTPUT_PATH': 's3a://data-lake/processed/output/{{ ds }}',
        **{env.name: env.value for env in minio_env_vars}
    },
    resources=k8s.V1ResourceRequirements(
        requests={'memory': '1Gi', 'cpu': '500m'},
        limits={'memory': '2Gi', 'cpu': '1000m'},
    ),
    get_logs=True,
    dag=dag,
)

# Tâche 4 : Notification (optionnelle)
send_notification = KubernetesPodOperator(
    task_id='send_notification',
    name='send-notification',
    namespace='airflow',
    image='curlimages/curl:latest',
    cmds=['curl'],
    arguments=[
        '-X', 'POST',
        'https://hooks.slack.com/services/YOUR/WEBHOOK/URL',
        '-H', 'Content-Type: application/json',
        '-d', '{"text": "Spark job completed successfully for {{ ds }}"}',
    ],
    get_logs=True,
    dag=dag,
)

# Définir les dépendances
validate_input >> process_data >> validate_output >> send_notification
```

### 5.3 DAG avec SparkSubmitOperator (alternative)

Si vous préférez utiliser SparkSubmitOperator :

```python
# dags/spark_submit_dag.py
from airflow import DAG
from airflow.providers.apache.spark.operators.spark_submit import SparkSubmitOperator
from airflow.utils.dates import days_ago

default_args = {
    'owner': 'data-engineer',
    'depends_on_past': False,
    'start_date': days_ago(1),
}

dag = DAG(
    'spark_submit_job',
    default_args=default_args,
    schedule_interval='@daily',
    catchup=False,
)

spark_job = SparkSubmitOperator(
    task_id='spark_submit_task',
    application='/opt/spark/work-dir/process_data.py',
    name='spark-airflow-job',
    conn_id='spark_default',
    conf={
        'spark.hadoop.fs.s3a.endpoint': 'http://minio:9000',
        'spark.hadoop.fs.s3a.access.key': 'minioadmin',
        'spark.hadoop.fs.s3a.secret.key': 'minioadmin',
        'spark.hadoop.fs.s3a.path.style.access': 'true',
    },
    application_args=[
        's3a://data-lake/raw/input/{{ ds }}',
        's3a://data-lake/processed/output/{{ ds }}',
    ],
    dag=dag,
)
```

### 5.4 Déploiement du DAG

Copier le DAG dans le volume Airflow :

```bash
# Si vous utilisez un volume partagé
kubectl cp dags/spark_job_dag.py airflow/airflow-scheduler-0:/opt/airflow/dags/

# Ou via ConfigMap
kubectl create configmap spark-dag \
  --from-file=spark_job_dag.py=dags/spark_job_dag.py \
  -n airflow

# Modifier le deployment pour monter le ConfigMap
```

### 5.5 Vérification et monitoring

```bash
# Vérifier que le DAG est chargé
kubectl exec -n airflow -it airflow-scheduler-0 -- airflow dags list

# Vérifier les détails du DAG
kubectl exec -n airflow -it airflow-scheduler-0 -- airflow dags show spark_data_processing

# Déclencher manuellement une exécution
kubectl exec -n airflow -it airflow-scheduler-0 -- airflow dags trigger spark_data_processing

# Vérifier les pods créés pour les tâches
kubectl get pods -n airflow -l app=airflow

# Voir les logs d'une tâche spécifique
kubectl logs -n airflow spark-process-data-<pod-id>
```

### 5.6 Bonnes pratiques

1. **Gestion des ressources** : Définir des limites appropriées pour chaque tâche Spark
2. **Gestion des erreurs** : Implémenter des retries et des alertes
3. **Sécurité** : Utiliser des secrets Kubernetes pour les credentials
4. **Monitoring** : Intégrer avec Prometheus/Grafana pour le monitoring
5. **Logs** : Centraliser les logs avec Loki ou ELK
6. **Tests** : Tester les DAGs localement avant le déploiement

---

## 6. Résumé et Checklist

### Checklist d'installation

- [ ] Cluster Kubernetes fonctionnel
- [ ] Helm installé et configuré
- [ ] Repository Helm Airflow ajouté
- [ ] Namespace créé
- [ ] Fichier `values-airflow.yaml` configuré
- [ ] Airflow installé avec Helm
- [ ] ServiceAccount et RBAC configurés
- [ ] Keycloak configuré et intégré
- [ ] KubernetesPodExecutor configuré
- [ ] Images Docker Spark construites et poussées
- [ ] DAGs créés et déployés
- [ ] Tests d'exécution réussis
- [ ] Monitoring et alertes configurés

### Commandes utiles

```bash
# Mettre à jour Airflow
helm upgrade airflow apache-airflow/airflow \
  --namespace airflow \
  --values values-airflow.yaml

# Voir les logs
kubectl logs -n airflow -l component=scheduler --tail=100
kubectl logs -n airflow -l component=webserver --tail=100

# Redémarrer les composants
kubectl rollout restart deployment/airflow-webserver -n airflow
kubectl rollout restart deployment/airflow-scheduler -n airflow

# Accéder au shell Airflow
kubectl exec -n airflow -it airflow-scheduler-0 -- bash

# Lister les DAGs
kubectl exec -n airflow -it airflow-scheduler-0 -- airflow dags list

# Tester une connexion
kubectl exec -n airflow -it airflow-scheduler-0 -- airflow connections test minio_s3
```

---

## 7. Références

- [Documentation officielle Apache Airflow](https://airflow.apache.org/docs/)
- [Helm Chart Airflow](https://airflow.apache.org/docs/helm-chart/stable/index.html)
- [KubernetesPodExecutor](https://airflow.apache.org/docs/apache-airflow/stable/executor/kubernetes.html)
- [Flask-AppBuilder OAuth](https://flask-appbuilder.readthedocs.io/en/latest/security.html#authentication-oauth)
- [Apache Spark Documentation](https://spark.apache.org/docs/latest/)

---

**Date de création** : 2025-01-27  
**Auteur** : Documentation technique  
**Version** : 1.0


