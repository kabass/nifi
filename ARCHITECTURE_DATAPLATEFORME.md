# Architecture Dataplateforme Kubernetes On-Premise

## Table des matières

1. [Vue d'ensemble](#vue-densemble)
2. [Architecture globale](#architecture-globale)
3. [Composants de la plateforme](#composants-de-la-plateforme)
4. [Comparaison Nifi vs Airbyte](#comparaison-nifi-vs-airbyte)
5. [Stratégie de gouvernance](#stratégie-de-gouvernance)
6. [Sécurité et authentification](#sécurité-et-authentification)
7. [Monitoring et observabilité](#monitoring-et-observabilité)
8. [Gestion des logs](#gestion-des-logs)
9. [Backup et Disaster Recovery](#backup-et-disaster-recovery)
10. [Déploiement et opérations](#déploiement-et-opérations)
11. [Recommandations et bonnes pratiques](#recommandations-et-bonnes-pratiques)

---

## Vue d'ensemble

Cette document décrit l'architecture d'une dataplateforme moderne hébergée sur Kubernetes en environnement on-premise. La plateforme est conçue pour supporter l'ensemble du cycle de vie des données : ingestion, transformation, stockage, analyse et gouvernance.

### Objectifs

- **Scalabilité** : Architecture élastique basée sur Kubernetes
- **Fiabilité** : Haute disponibilité et résilience
- **Sécurité** : Authentification centralisée et contrôle d'accès granulaire
- **Observabilité** : Monitoring complet et traçabilité des données
- **Gouvernance** : Catalogue de données et lineage pour la traçabilité

### Principes d'architecture

- **Cloud-native** : Utilisation de conteneurs et orchestration Kubernetes
- **Microservices** : Composants découplés et indépendants
- **API-first** : Interfaces standardisées pour l'intégration
- **Data as Code** : Versioning et CI/CD pour les transformations
- **Self-service** : Accès contrôlé aux ressources pour les équipes

---

## Architecture globale

### Schéma d'architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster (On-Premise)              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │   Keycloak   │  │  Prometheus  │  │   Grafana    │         │
│  │  (Auth/SSO)  │  │  (Metrics)   │  │ (Dashboards) │         │
│  └──────────────┘  └──────────────┘  └──────────────┘         │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                    Ingress Controller                     │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │   Airflow    │  │ Nifi/Airbyte │  │     DBT      │         │
│  │(Orchestration)│  │ (Integration)│  │(Transformation)│       │
│  └──────────────┘  └──────────────┘  └──────────────┘         │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │    Trino     │  │    Spark     │  │  PostgreSQL  │         │
│  │ (SQL Engine) │  │(Processing)  │  │ (Metadata)   │         │
│  │              │  │              │  │  + OpenEBS   │         │
│  └──────────────┘  └──────────────┘  └──────────────┘         │
│         │                │                                      │
│         └────────┬───────┘                                      │
│                  │                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │   Apache     │  │    MINIO     │  │   OpenEBS    │         │
│  │   Iceberg    │  │  (Object     │  │  (Storage)   │         │
│  │ (Table Format)│  │   Storage)   │  │              │         │
│  └──────────────┘  └──────────────┘  └──────────────┘         │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │ Data Catalog │  │   Loki/ELK   │  │   Velero     │         │
│  │  (Lineage)   │  │   (Logs)     │  │  (Backup)    │         │
│  └──────────────┘  └──────────────┘  └──────────────┘         │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Namespaces Kubernetes recommandés

- `data-platform-core` : Composants centraux (Airflow, Keycloak)
- `data-platform-storage` : Stockage (MINIO, PostgreSQL, OpenEBS)
- `data-platform-integration` : Intégration (Nifi/Airbyte)
- `data-platform-processing` : Traitement (Spark, DBT, Trino)
- `data-platform-observability` : Monitoring (Prometheus, Grafana, Loki)
- `data-platform-governance` : Gouvernance (Data Catalog)

### Flux de données

**Parcours typique des données** :

1. **Ingestion** :
   - Nifi/Airbyte ingère les données depuis les sources
   - Données écrites dans MINIO au format Iceberg (via Spark)

2. **Transformation** :
   - Airflow orchestre les pipelines
   - Spark effectue les transformations complexes (ETL)
   - DBT exécute les transformations SQL via Trino
   - Résultats écrits dans tables Iceberg (schéma analytics)

3. **Accès et analyse** :
   - Trino permet l'accès SQL universel aux tables Iceberg
   - Requêtes ad-hoc par analystes via Trino
   - Outils BI connectés à Trino
   - Jointures entre différentes sources de données

4. **Gouvernance** :
   - Data Catalog découvre automatiquement les tables Iceberg
   - Lineage extrait depuis Airflow, Spark, DBT, Trino
   - Métadonnées enrichies et documentées

**Avantages de cette architecture** :
- **Séparation stockage/compute** : MINIO pour stockage, Trino/Spark pour traitement
- **Format ouvert** : Iceberg permet l'accès depuis multiples moteurs
- **Scalabilité** : Chaque composant scale indépendamment
- **Performance** : Optimisations Iceberg (partitioning, pruning, compaction)
- **Flexibilité** : Ajout facile de nouveaux moteurs de traitement

---

## Composants de la plateforme

### 1. Stockage : MINIO

**Rôle** : Stockage objet distribué compatible S3 pour tables Apache Iceberg

**Configuration** :
- **Déploiement** : StatefulSet avec volumes persistants
- **Réplication** : Mode distribué (4+ nodes) pour haute disponibilité
- **Stockage** : Volumes persistants Kubernetes (PV/PVC) via OpenEBS
- **Sécurité** : TLS/SSL, bucket policies, intégration Keycloak pour l'authentification

**Utilisation** :
- **Tables Iceberg** : Stockage principal des données analytiques (format Parquet)
- **Métadonnées Iceberg** : Fichiers de métadonnées et manifestes
- **Backup** : Backups et archives
- **Artefacts** : Modèles ML, fichiers intermédiaires

**Organisation** :
- Buckets séparés par environnement (dev, staging, prod)
- Structure de dossiers par domaine métier
- Lifecycle policies pour archivage automatique

**Ressources recommandées** :
- CPU : 2 cores par pod
- RAM : 4 Gi par pod
- Stockage : 50 Ti+ selon les besoins (données analytiques)

### 2. Orchestrateur : Apache Airflow

**Rôle** : Orchestration et planification des workflows de données

**Configuration** :
- **Déploiement** : Helm chart officiel Airflow
- **Composants** :
  - **Webserver** : Interface utilisateur (2+ replicas)
  - **Scheduler** : Planification des tâches (2+ replicas pour HA)
  - **Workers** : Exécution des tâches (autoscaling)
  - **PostgreSQL** : Métadonnées Airflow (dédié ou partagé)
- **Executor** : KubernetesExecutor pour isolation et scalabilité
- **Sécurité** : Intégration Keycloak (OAuth2/OIDC)

**Intégrations** :
- Connexion aux sources de données
- Déclenchement de jobs Spark
- Exécution de transformations DBT
- Gestion des pipelines Nifi/Airbyte

**Ressources recommandées** :
- Webserver : 1 CPU, 2 Gi RAM
- Scheduler : 2 CPU, 4 Gi RAM
- Workers : Autoscaling 2-20 pods (1 CPU, 2 Gi RAM par pod)

### 3. Intégration de données : Nifi vs Airbyte

Voir section [Comparaison Nifi vs Airbyte](#comparaison-nifi-vs-airbyte)

### 4. Monitoring : Prometheus + Grafana

**Prometheus** :
- **Rôle** : Collecte et stockage des métriques
- **Déploiement** : Prometheus Operator (CRD)
- **Scraping** : ServiceMonitor pour chaque composant
- **Rétention** : 30-90 jours selon les besoins
- **Stockage** : Volumes persistants (50+ Gi)

**Grafana** :
- **Rôle** : Visualisation et alerting
- **Déploiement** : StatefulSet avec volumes persistants
- **Authentification** : Intégration Keycloak (OAuth2)
- **Dashboards** :
  - Métriques Kubernetes (CPU, RAM, réseau)
  - Métriques Airflow (DAGs, tâches, exécutions)
  - Métriques Spark (jobs, executors)
  - Métriques PostgreSQL (requêtes, connexions)
  - Métriques MINIO (bande passante, stockage)

**Alerting** :
- AlertManager pour gestion des alertes
- Notifications : Email, Slack, PagerDuty
- Règles d'alerte pour :
  - Disponibilité des services
  - Utilisation des ressources
  - Erreurs dans les pipelines
  - Performance des requêtes

### 5. Identity Provider : Keycloak

**Rôle** : Authentification et autorisation centralisée (SSO)

**Configuration** :
- **Déploiement** : StatefulSet avec PostgreSQL pour la base de données
- **Protocoles** : OAuth2, OpenID Connect (OIDC), SAML
- **Intégrations** :
  - Airflow : OAuth2/OIDC
  - Grafana : OAuth2/OIDC
  - MINIO : Identity Provider
  - Data Catalog : OAuth2/OIDC

**Gestion des utilisateurs** :
- **Realms** : Séparation par environnement (dev, staging, prod)
- **Rôles** : Data Engineer, Data Analyst, Data Scientist, Admin
- **Groupes** : Organisation par équipe/projet
- **MFA** : Authentification multi-facteurs optionnelle

**Synchronisation** :
- LDAP/Active Directory pour utilisateurs existants
- Provisioning automatique des utilisateurs

### 6. Gestion des logs

**Stack recommandée** : Loki + Promtail (ou ELK Stack)

**Option 1 : Loki + Promtail (Cloud-native, léger)**

**Loki** :
- **Rôle** : Agrégation et stockage des logs
- **Déploiement** : StatefulSet avec stockage objet (MINIO) ou volumes
- **Avantages** : Intégration native avec Grafana, léger, efficace
- **Rétention** : 30-90 jours

**Promtail** :
- **Rôle** : Collecte des logs depuis les pods
- **Déploiement** : DaemonSet sur tous les nodes
- **Configuration** : Labels automatiques (namespace, pod, container)

**Option 2 : ELK Stack (Elasticsearch, Logstash, Kibana)**

**Elasticsearch** :
- **Rôle** : Indexation et recherche des logs
- **Déploiement** : StatefulSet avec volumes persistants
- **Ressources** : 8+ CPU, 16+ Gi RAM par node

**Logstash** :
- **Rôle** : Traitement et transformation des logs
- **Déploiement** : Deployment avec autoscaling

**Kibana** :
- **Rôle** : Visualisation des logs
- **Déploiement** : Deployment
- **Authentification** : Intégration Keycloak

**Recommandation** : Loki + Promtail pour une stack plus légère et cloud-native, ELK pour des besoins avancés de recherche et d'analyse.

### 7. Backup et Disaster Recovery

**Stratégie multi-niveaux** :

#### 7.1 Backup des données applicatives

**Velero** :
- **Rôle** : Backup et restauration Kubernetes
- **Fonctionnalités** :
  - Backup des ressources Kubernetes (PVC, ConfigMaps, Secrets)
  - Snapshot des volumes persistants
  - Backup vers stockage objet (MINIO ou externe)
- **Planification** : Backups quotidiens avec rétention 30 jours

**PostgreSQL** :
- **pg_dump** : Backups quotidiens via cron job dans Kubernetes
- **WAL archiving** : Archive continue des Write-Ahead Logs
- **Point-in-time recovery** : Restauration à un point précis
- **Stockage** : MINIO ou stockage externe

**MINIO** :
- **Réplication** : Réplication multi-sites pour DR
- **Versioning** : Conservation des versions d'objets
- **Lifecycle policies** : Transition vers stockage froid

#### 7.2 Disaster Recovery Plan

**RTO (Recovery Time Objective)** : 4 heures
**RPO (Recovery Point Objective)** : 1 heure

**Scénarios de récupération** :
1. **Perte d'un pod/service** : Auto-healing Kubernetes
2. **Perte d'un node** : Pods reschedulés automatiquement
3. **Perte d'un namespace** : Restauration depuis Velero
4. **Perte du cluster** : Restauration complète depuis backups

**Procédures** :
- Documentation des procédures de restauration
- Tests de restauration mensuels
- Documentation des dépendances entre services

### 8. Data Catalog et Lineage

**Options recommandées** :

#### Option 1 : Apache Atlas

**Avantages** :
- Open source, mature
- Support de nombreux connecteurs
- Lineage automatique pour certains outils
- API REST complète

**Configuration** :
- **Déploiement** : StatefulSet avec HBase/Solr pour le stockage
- **Intégrations** :
  - Airflow : Extraction des métadonnées de DAGs
  - Spark : Lineage des transformations Iceberg
  - DBT : Extraction depuis les modèles (via Trino)
  - Trino : Métadonnées des requêtes et tables
  - Iceberg : Extraction des métadonnées de tables (schémas, partitions)
  - PostgreSQL : Découverte automatique des schémas
- **Authentification** : Keycloak

#### Option 2 : DataHub (LinkedIn)

**Avantages** :
- Interface moderne et intuitive
- Lineage visuel avancé
- Support de nombreux systèmes
- Architecture microservices

**Configuration** :
- **Déploiement** : Helm chart officiel
- **Composants** : DataHub frontend, metadata service, ingestion framework
- **Intégrations** : 
  - Airflow : Métadonnées des DAGs et tâches
  - Spark : Lineage des jobs et transformations Iceberg
  - DBT : Extraction depuis les modèles (via Trino)
  - Trino : Métadonnées des requêtes et catalogues
  - Iceberg : Découverte automatique des tables et schémas
  - PostgreSQL : Métadonnées des schémas relationnels
  - MINIO : Métadonnées des buckets et objets

#### Option 3 : OpenMetadata

**Avantages** :
- Open source, architecture moderne
- API-first
- Support de nombreux connecteurs
- Interface utilisateur moderne

**Recommandation** : DataHub ou OpenMetadata pour une expérience utilisateur moderne, Apache Atlas pour une solution éprouvée.

### 9. Couche de données : Apache Iceberg

**Rôle** : Format de table open-source pour les données analytiques

**Avantages** :
- ✅ **ACID transactions** : Garanties transactionnelles complètes
- ✅ **Time travel** : Accès aux versions historiques des données
- ✅ **Schema evolution** : Évolution de schéma sans réécriture
- ✅ **Partitionnement** : Partitionnement intelligent et automatique
- ✅ **Performance** : Optimisations avancées (compaction, pruning)
- ✅ **Multi-moteur** : Compatible avec Spark, Trino, Flink
- ✅ **Open format** : Format ouvert basé sur Parquet

**Configuration** :
- **Stockage** : Tables Iceberg stockées dans MINIO (format S3)
- **Catalog** : Hive Metastore ou REST Catalog (optionnellement PostgreSQL pour métadonnées)
- **Organisation** :
  - `raw/` : Données brutes en format Iceberg
  - `staging/` : Données nettoyées
  - `analytics/` : Données transformées (DBT)
  - `ml/` : Données pour machine learning

**Gestion** :
- **Compaction** : Jobs Spark réguliers pour optimiser les fichiers
- **Expiration des snapshots** : Nettoyage automatique des anciennes versions
- **Monitoring** : Métriques sur la taille des tables, nombre de fichiers

**Intégrations** :
- **Spark** : Support natif pour lecture/écriture Iceberg
- **Trino** : Connecteur Iceberg pour requêtes SQL
- **DBT** : Via Trino pour transformations SQL
- **Data Catalog** : Extraction des métadonnées Iceberg

### 10. Moteur SQL universel : Trino

**Rôle** : Moteur de requête SQL distribué pour accès universel aux données

**Avantages** :
- ✅ **Accès universel** : Requêtes SQL sur multiples sources (Iceberg, PostgreSQL, MINIO, etc.)
- ✅ **Performance** : Moteur de requête haute performance
- ✅ **Fédération** : Jointures entre différentes sources de données
- ✅ **Standards SQL** : Support complet du standard SQL
- ✅ **Concurrent queries** : Gestion efficace des requêtes concurrentes
- ✅ **Ressource groups** : Isolation et gestion des ressources par utilisateur/équipe

**Configuration** :
- **Déploiement** : StatefulSet avec coordination (2+ coordinators, 4+ workers)
- **Catalog** : Configuration de catalogues pour :
  - **Iceberg** : Tables Iceberg dans MINIO
  - **PostgreSQL** : Métadonnées et données relationnelles
  - **MINIO** : Accès direct aux objets (via connector S3)
- **Authentification** : Intégration Keycloak (OAuth2/OIDC)
- **Authorization** : System-level et table-level permissions

**Ressources recommandées** :
- **Coordinator** : 4 CPU, 8 Gi RAM (2+ replicas pour HA)
- **Workers** : 8 CPU, 16 Gi RAM par worker (4-20 workers selon charge)
- **JVM** : Tuning JVM pour performance optimale

**Utilisation** :
- Requêtes SQL ad-hoc par analystes
- Intégration avec outils BI (Tableau, PowerBI, Superset)
- Exécution de transformations DBT
- Requêtes fédérées entre sources multiples

**Intégration Airflow** :
- TrinoOperator pour exécution de requêtes SQL
- Monitoring des requêtes via Trino UI

**Monitoring** :
- Métriques Prometheus (trino-exporter)
- Dashboard Grafana pour performance des requêtes
- Alertes sur requêtes lentes ou échecs

### 11. Transformation : DBT et Spark

#### DBT (Data Build Tool)

**Rôle** : Transformation SQL avec approche "Data as Code"

**Configuration** :
- **Déploiement** : Jobs Kubernetes (CronJob ou déclenchés par Airflow)
- **Adapter** : DBT-Trino (au lieu de DBT-PostgreSQL)
- **Profils** : Connexion à Trino pour accès aux tables Iceberg
- **Versioning** : Git pour les modèles DBT
- **CI/CD** : Tests automatiques des modèles
- **Documentation** : Génération automatique depuis les modèles

**Workflow** :
1. Airflow déclenche l'exécution DBT
2. DBT se connecte à Trino
3. DBT exécute les transformations SQL sur tables Iceberg
4. Résultats écrits dans nouvelles tables Iceberg (analytics schema)
5. Métadonnées envoyées au Data Catalog

**Avantages avec Trino + Iceberg** :
- Accès unifié à toutes les sources via Trino
- Transformations sur tables Iceberg (performances optimisées)
- Support des fonctionnalités Iceberg (time travel, schema evolution)
- Scalabilité pour grandes volumétries

**Ressources** : 2 CPU, 4 Gi RAM par exécution

**Exemple de profil DBT** :
```yaml
trino:
  target: prod
  outputs:
    prod:
      type: trino
      method: oauth
      host: trino.data-platform-processing.svc.cluster.local
      port: 8080
      schema: analytics
      catalog: iceberg
```

#### Apache Spark

**Rôle** : Traitement distribué de grandes volumétries et écriture Iceberg

**Configuration** :
- **Déploiement** : Spark Operator (Kubernetes)
- **Mode** : Native Kubernetes (pas de YARN)
- **Ressources** :
  - Driver : 2 CPU, 4 Gi RAM
  - Executors : Autoscaling 2-50 pods (2 CPU, 8 Gi RAM par executor)
- **Stockage** : Accès à MINIO (S3) pour tables Iceberg

**Utilisation** :
- Ingestion de données volumineuses vers Iceberg
- ETL complexes avec transformations Spark
- Préparation de données pour ML
- Agrégations complexes
- Traitement de streams (Spark Streaming) vers Iceberg
- Compaction et maintenance des tables Iceberg

**Intégration Iceberg** :
- **Spark 3.x** : Support natif Iceberg
- **Configuration** : Catalog Iceberg pointant vers MINIO
- **Écriture** : Création et mise à jour de tables Iceberg
- **Lecture** : Lecture optimisée avec predicate pushdown

**Intégration Airflow** :
- SparkKubernetesOperator pour déclencher les jobs
- Monitoring des jobs via Spark UI

### 12. Stockage et infrastructure : MINIO, PostgreSQL, OpenEBS

#### MINIO (Stockage objet)

**Rôle** : Stockage objet distribué compatible S3 pour tables Iceberg

**Configuration** :
- **Déploiement** : StatefulSet avec volumes persistants
- **Réplication** : Mode distribué (4+ nodes) pour haute disponibilité
- **Stockage** : Volumes persistants Kubernetes (PV/PVC) via OpenEBS
- **Sécurité** : TLS/SSL, bucket policies, intégration Keycloak pour l'authentification

**Organisation des buckets** :
- `iceberg-raw` : Tables Iceberg brutes
- `iceberg-staging` : Tables Iceberg nettoyées
- `iceberg-analytics` : Tables Iceberg transformées (DBT)
- `iceberg-ml` : Tables Iceberg pour ML
- `backups` : Backups et archives

**Performance** :
- Optimisation pour accès S3 depuis Spark et Trino
- Lifecycle policies pour archivage automatique
- Versioning activé pour récupération

#### PostgreSQL (Métadonnées et données relationnelles)

**Rôle** : Stockage des métadonnées et données relationnelles complémentaires

**Utilisation** :
- **Métadonnées** : Hive Metastore ou catalog Iceberg (optionnel)
- **Métadonnées Airflow** : Base de données Airflow
- **Métadonnées Trino** : Configuration des catalogues
- **Données relationnelles** : Données transactionnelles, référentiels
- **Métadonnées Keycloak** : Base de données Keycloak

**Configuration** :
- **Version** : PostgreSQL 14+
- **Déploiement** : StatefulSet avec volumes persistants
- **Haute disponibilité** : Patroni ou PostgreSQL Operator
- **Réplication** : Streaming replication (1 master, 2+ replicas)
- **Extensions** :
  - `pg_stat_statements` : Monitoring des requêtes
  - `pg_partman` : Partitionnement automatique
  - `timescaledb` : Pour données temporelles (optionnel)

**Schémas recommandés** :
- `airflow` : Métadonnées Airflow
- `keycloak` : Métadonnées Keycloak
- `trino` : Métadonnées Trino (si utilisé)
- `reference` : Données de référence et lookup tables
- `transactional` : Données transactionnelles (si nécessaire)

**Ressources** : 8 CPU, 16 Gi RAM pour le master
**Stockage** : 500 Gi+ selon les besoins (principalement métadonnées)

#### OpenEBS (Storage provisioner)

**Rôle** : Storage provisioner pour volumes persistants Kubernetes

**Avantages** :
- Stockage distribué
- Réplication locale
- Snapshot et clone
- Performance optimisée
- Intégration native Kubernetes

**StorageClasses** :
- `openebs-hostpath` : Pour développement/test
- `openebs-jiva` : Pour production (réplication)
- `openebs-cstor` : Pour haute performance (optionnel)

**Utilisation** :
- Volumes pour PostgreSQL
- Volumes pour MINIO (si nécessaire)
- Volumes pour autres StatefulSets

---

## Comparaison Nifi vs Airbyte

### Apache Nifi

**Avantages** :
- ✅ **Maturité** : Projet Apache mature et stable
- ✅ **Flexibilité** : Processors très nombreux (300+)
- ✅ **Flows visuels** : Interface graphique intuitive
- ✅ **Traitement en temps réel** : Streaming natif
- ✅ **Transformation** : Processors de transformation intégrés
- ✅ **Gouvernance** : Lineage automatique intégré
- ✅ **On-premise** : Parfaitement adapté aux environnements on-premise

**Inconvénients** :
- ❌ **Complexité** : Courbe d'apprentissage élevée
- ❌ **Ressources** : Consommation mémoire importante
- ❌ **Maintenance** : Configuration et maintenance plus complexes
- ❌ **Scalabilité** : Nécessite une architecture cluster pour la scalabilité

**Cas d'usage** :
- Ingestion de données en temps réel
- Transformation complexe pendant l'ingestion
- Intégration avec systèmes legacy
- Besoin de contrôle fin sur les flows

**Configuration Kubernetes** :
- **Déploiement** : StatefulSet avec volumes persistants
- **Composants** :
  - NiFi nodes (3+ pour HA)
  - ZooKeeper pour coordination
- **Ressources** : 4 CPU, 8 Gi RAM par node minimum
- **Stockage** : 100+ Gi pour flowfiles et provenance

### Airbyte

**Avantages** :
- ✅ **Simplicité** : Interface utilisateur moderne et intuitive
- ✅ **Connectors** : 300+ connectors pré-construits
- ✅ **Maintenance** : Moins de maintenance, mises à jour automatiques
- ✅ **Cloud-native** : Architecture microservices native Kubernetes
- ✅ **Normalization** : Normalisation automatique des données
- ✅ **API** : API REST complète pour l'automatisation
- ✅ **Open source** : Communauté active

**Inconvénients** :
- ❌ **Maturité** : Plus récent, moins mature que Nifi
- ❌ **Temps réel** : Principalement batch (streaming en développement)
- ❌ **Transformation** : Moins de transformation intégrée (repose sur DBT)
- ❌ **Flexibilité** : Moins de contrôle fin sur les processus

**Cas d'usage** :
- Ingestion batch de sources variées
- Réplication de données entre systèmes
- Équipes moins techniques
- Besoin de connectors prêts à l'emploi

**Configuration Kubernetes** :
- **Déploiement** : Helm chart officiel
- **Composants** :
  - Airbyte Server (API)
  - Airbyte Webapp
  - Airbyte Worker (exécution des syncs)
  - PostgreSQL (métadonnées)
- **Ressources** : 2 CPU, 4 Gi RAM par worker
- **Stockage** : Volumes pour cache temporaire

### Recommandation

**Pour cette architecture on-premise** :

**Choisir Airbyte si** :
- L'équipe privilégie la simplicité et la productivité
- Besoin principal d'ingestion batch
- Sources de données variées avec connectors disponibles
- Transformation gérée par DBT

**Choisir Nifi si** :
- Besoin de traitement en temps réel
- Transformation complexe pendant l'ingestion
- Contrôle fin nécessaire sur les flows
- Intégration avec systèmes legacy complexes

**Recommandation hybride** :
- **Airbyte** : Pour l'ingestion batch standard (80% des cas)
- **Nifi** : Pour les cas complexes et temps réel (20% des cas)

---

## Stratégie de gouvernance

### 1. Gestion des ressources

#### 1.1 Resource Quotas et Limits

**Namespaces** :
- Quotas CPU/RAM par namespace
- Limits par pod/container
- Requests garantis pour les services critiques

**Exemple de configuration** :
```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: data-platform-quota
  namespace: data-platform-processing
spec:
  hard:
    requests.cpu: "100"
    requests.memory: 200Gi
    limits.cpu: "200"
    limits.memory: 400Gi
    persistentvolumeclaims: "10"
```

#### 1.2 Autoscaling

**Horizontal Pod Autoscaler (HPA)** :
- Airflow workers : Basé sur CPU/mémoire
- Spark executors : Basé sur queue de jobs
- Trino workers : Basé sur nombre de requêtes actives
- Workers d'intégration : Basé sur nombre de syncs

**Vertical Pod Autoscaler (VPA)** :
- Ajustement automatique des requests/limits
- Recommandations pour optimisation

#### 1.3 Monitoring des ressources

**Dashboards Grafana** :
- Utilisation CPU/RAM par namespace
- Coûts estimés par équipe/projet
- Alertes sur utilisation excessive

### 2. Gestion d'accès

#### 2.1 RBAC (Role-Based Access Control)

**Rôles Kubernetes** :
- `data-engineer` : Accès complet aux namespaces de traitement
- `data-analyst` : Accès en lecture aux données, exécution de requêtes
- `data-scientist` : Accès aux données et ressources ML
- `platform-admin` : Accès administrateur complet

**Exemple de Role** :
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: data-analyst
  namespace: data-platform-processing
rules:
- apiGroups: [""]
  resources: ["pods", "jobs"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["sparkoperator.k8s.io"]
  resources: ["sparkapplications"]
  verbs: ["create", "get", "list"]
```

#### 2.2 Accès aux données

**Trino** :
- System-level permissions : Accès aux catalogues
- Table-level permissions : Accès aux tables Iceberg
- Resource groups : Isolation des ressources par utilisateur/équipe
- Intégration Keycloak pour authentification
- Policies par schéma/catalogue

**Iceberg** :
- Contrôle d'accès via Trino (table-level)
- Contrôle d'accès au niveau MINIO (bucket policies)
- Time travel permissions : Accès aux versions historiques

**PostgreSQL** :
- Utilisateurs par schéma/environnement
- Rôles : `readonly`, `readwrite`, `admin`
- Row-level security pour données sensibles

**MINIO** :
- Policies par bucket
- Accès via Keycloak
- Lifecycle policies pour archivage
- IAM policies pour tables Iceberg

**Airflow** :
- Rôles : Admin, User, Viewer, Op, Public
- Permissions granulaires par DAG
- Intégration Keycloak

#### 2.3 Secrets Management

**Vault ou Kubernetes Secrets** :
- Stockage sécurisé des credentials
- Rotation automatique des secrets
- Accès via ServiceAccounts

### 3. Qualité et traçabilité des données

#### 3.1 Data Quality

**Outils** :
- **Great Expectations** : Tests de qualité intégrés dans DBT
- **dbt tests** : Tests de cohérence et intégrité
- **Custom validators** : Validations métier spécifiques

**Processus** :
1. Tests automatiques dans les pipelines DBT
2. Alertes en cas d'échec
3. Blocage des données non conformes
4. Reporting de qualité dans le Data Catalog

#### 3.2 Lineage et traçabilité

**Data Catalog** :
- Lineage automatique depuis :
  - Airflow DAGs
  - DBT models
  - Spark jobs
  - Pipelines d'intégration
- Impact analysis : Impact des changements
- Documentation : Métadonnées enrichies

#### 3.3 Classification et étiquetage

**Tags** :
- Classification : Public, Internal, Confidential, Restricted
- Domaine métier : Finance, Marketing, Operations
- Propriétaire : Équipe responsable
- PII : Données personnelles identifiables

### 4. Politiques de rétention et lifecycle

#### 4.1 Rétention des données

**PostgreSQL** :
- Données brutes : 90 jours
- Données transformées : 365 jours
- Archivage vers MINIO après rétention

**MINIO** :
- Lifecycle policies :
  - Transition vers classe de stockage froid après 90 jours
  - Suppression après 2 ans (sauf données critiques)

#### 4.2 Archivage

**Processus** :
1. Identification des données à archiver
2. Export vers MINIO (format compressé)
3. Suppression des données source
4. Documentation dans le Data Catalog

### 5. Conformité et audit

#### 5.1 Audit logging

**Événements à logger** :
- Accès aux données sensibles
- Modifications de schémas
- Exécution de pipelines
- Changements de permissions

**Stockage** :
- Logs d'audit dans PostgreSQL dédié
- Rétention : 7 ans pour conformité
- Accès restreint (admin uniquement)

#### 5.2 Conformité réglementaire

**GDPR / RGPD** :
- Droit à l'oubli : Processus de suppression
- Portabilité des données : Export format standard
- Consentement : Traçabilité des consentements

**SOC 2 / ISO 27001** :
- Contrôles d'accès documentés
- Monitoring et alerting
- Procédures de backup et DR

---

## Sécurité et authentification

### 1. Authentification centralisée (Keycloak)

**Intégrations** :
- Tous les services exposés utilisent Keycloak
- SSO : Single Sign-On pour expérience utilisateur
- MFA : Optionnel pour accès sensibles

### 2. Chiffrement

**In transit** :
- TLS/SSL pour toutes les communications
- Certificats gérés par cert-manager
- Renouvellement automatique

**At rest** :
- Chiffrement des volumes (option Kubernetes)
- Chiffrement des backups
- Secrets chiffrés dans etcd

### 3. Network Policies

**Isolation réseau** :
- Policies par namespace
- Communication autorisée uniquement entre services nécessaires
- Blocage par défaut (deny-all)

**Exemple** :
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: airflow-network-policy
  namespace: data-platform-core
spec:
  podSelector:
    matchLabels:
      app: airflow
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: data-platform-observability
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: data-platform-storage
```

### 4. Pod Security Standards

**Standards** :
- Restricted : Pour la plupart des workloads
- Baseline : Pour workloads nécessitant des privilèges
- Privileged : Évité sauf cas exceptionnels

---

## Monitoring et observabilité

### 1. Métriques (Prometheus)

**Métriques collectées** :

**Infrastructure** :
- CPU, RAM, disque, réseau par node
- Utilisation des volumes persistants
- État des pods (running, pending, failed)

**Applications** :
- Airflow : DAGs success/failure rate, durée d'exécution
- Spark : Jobs duration, executors, throughput
- Trino : Requêtes actives, durée d'exécution, throughput, erreurs
- Iceberg : Nombre de tables, taille des tables, nombre de fichiers, snapshots
- PostgreSQL : Requêtes lentes, connexions, réplication lag
- MINIO : Bandwidth, stockage utilisé, erreurs, requêtes S3

**Métriques métier** :
- Volume de données ingérées
- Latence des pipelines
- Taux d'erreur par source
- Performance des requêtes SQL (Trino)
- Utilisation des tables Iceberg

### 2. Dashboards Grafana

**Dashboards principaux** :
1. **Infrastructure Overview** : État global du cluster
2. **Data Platform Health** : Santé des services data
3. **Pipeline Monitoring** : État des pipelines Airflow
4. **Trino Performance** : Requêtes SQL, performance, utilisation
5. **Iceberg Tables** : État des tables, taille, snapshots, compaction
6. **Data Quality** : Résultats des tests de qualité
7. **Cost Analysis** : Utilisation des ressources par équipe

### 3. Alerting

**Alertes critiques** :
- Service down (disponibilité < 99%)
- Erreurs répétées dans les pipelines
- Requêtes Trino lentes (> 5 min) ou échouées
- Utilisation disque > 80%
- Tables Iceberg avec trop de fichiers (nécessite compaction)
- Réplication PostgreSQL en retard
- Backup échoué

**Canaux de notification** :
- Email pour alertes non critiques
- Slack pour alertes importantes
- PagerDuty pour alertes critiques (24/7)

---

## Gestion des logs

### Architecture Loki + Promtail

**Promtail** (DaemonSet) :
- Collecte des logs depuis tous les pods
- Enrichissement avec labels (namespace, pod, container)
- Envoi vers Loki

**Loki** :
- Stockage des logs (MINIO backend ou volumes)
- Indexation par labels
- Requêtes LogQL

**Grafana** :
- Visualisation des logs
- Corrélation logs/métriques
- Alerting sur patterns de logs

### Logs critiques à monitorer

- Erreurs d'authentification
- Échecs de pipelines
- Erreurs de connexion base de données
- Accès refusés
- Performances dégradées

### Rétention

- Logs applicatifs : 30 jours
- Logs d'audit : 7 ans
- Logs d'erreur : 90 jours

---

## Backup et Disaster Recovery

### Stratégie de backup

#### 1. Backups Kubernetes (Velero)

**Fréquence** :
- Quotidien : Backups complets
- Horaire : Backups incrémentaux (optionnel)

**Ressources sauvegardées** :
- PVC (volumes persistants)
- ConfigMaps et Secrets
- Custom Resources (Airflow DAGs, SparkApplications)

**Stockage** :
- MINIO bucket dédié
- Ou stockage externe (S3 compatible)

#### 2. Backups PostgreSQL

**Méthode** :
- `pg_dump` : Backup complet quotidien
- WAL archiving : Archive continue pour PITR
- Réplication : Replicas pour haute disponibilité

**Rétention** :
- Backups quotidiens : 30 jours
- WAL archives : 7 jours
- Backups mensuels : 12 mois

#### 3. Backups MINIO

**Réplication** :
- Réplication multi-sites
- Versioning activé
- Lifecycle policies pour archivage

### Disaster Recovery

#### Scénarios et procédures

**Scénario 1 : Perte d'un service**
- **RTO** : < 1 heure
- **Procédure** : Redéploiement depuis Helm charts

**Scénario 2 : Perte d'un namespace**
- **RTO** : < 2 heures
- **Procédure** : Restauration Velero

**Scénario 3 : Perte du cluster**
- **RTO** : < 4 heures
- **Procédure** :
  1. Recréation du cluster Kubernetes
  2. Installation des opérateurs
  3. Restauration Velero
  4. Vérification des services

**Tests** :
- Tests de restauration mensuels
- Documentation des procédures
- Formation de l'équipe

---

## Déploiement et opérations

### 1. Infrastructure as Code

**Outils** :
- **Terraform** : Infrastructure Kubernetes (si applicable)
- **Helm** : Déploiement des applications
- **Kustomize** : Personnalisation par environnement

**Repositories** :
- `infrastructure/` : Définitions Terraform
- `helm-charts/` : Charts Helm personnalisés
- `kustomize/` : Overlays par environnement

### 2. CI/CD

**Pipeline** :
1. **Build** : Construction des images Docker
2. **Test** : Tests unitaires et d'intégration
3. **Deploy Dev** : Déploiement automatique en dev
4. **Deploy Staging** : Déploiement manuel après validation
5. **Deploy Prod** : Déploiement manuel avec approbation

**Outils** :
- GitLab CI/CD ou GitHub Actions
- ArgoCD pour GitOps (recommandé)

### 3. Gestion des environnements

**Environnements** :
- **Development** : Tests et développement
- **Staging** : Validation avant production
- **Production** : Environnement de production

**Isolation** :
- Namespaces Kubernetes séparés
- Clusters séparés (recommandé pour prod)

### 4. Maintenance

**Mises à jour** :
- Planification mensuelle des mises à jour
- Tests en staging avant production
- Window de maintenance communiquée

**Monitoring** :
- Health checks après mise à jour
- Rollback automatique en cas d'échec

---

## Recommandations et bonnes pratiques

### 1. Architecture

- **Haute disponibilité** : Au moins 2 replicas pour les services critiques
- **Ressources** : Définir requests et limits pour tous les pods
- **Stockage** : Utiliser StorageClasses avec réplication
- **Networking** : Network Policies pour isolation

### 2. Sécurité

- **Principle of least privilege** : Accès minimal nécessaire
- **Rotation des secrets** : Rotation régulière des credentials
- **Scanning** : Scan des images Docker pour vulnérabilités
- **Compliance** : Audit régulier des accès

### 3. Performance

- **Caching** : Cache pour requêtes fréquentes (Trino query result cache)
- **Partitionnement** : Partitionnement intelligent des tables Iceberg
- **Compaction** : Compaction régulière des tables Iceberg pour optimiser les performances
- **Pruning** : Utilisation des métadonnées Iceberg pour pruning automatique
- **Indexation** : Index appropriés sur les colonnes fréquemment interrogées (PostgreSQL)
- **Compression** : Compression Parquet optimisée pour tables Iceberg
- **Resource groups Trino** : Isolation et priorisation des requêtes par équipe

### 4. Coûts

- **Autoscaling** : Autoscaling pour optimiser les ressources
- **Ressources right-sizing** : Ajustement selon l'utilisation réelle
- **Lifecycle** : Archivage des données anciennes
- **Monitoring** : Tracking des coûts par équipe/projet

### 5. Documentation

- **Runbooks** : Procédures opérationnelles documentées
- **Architecture** : Diagrammes à jour
- **Onboarding** : Guide pour nouveaux utilisateurs
- **Troubleshooting** : Guide de résolution de problèmes

---

## Conclusion

Cette architecture fournit une dataplateforme moderne, scalable et sécurisée sur Kubernetes on-premise. Les composants choisis offrent un équilibre entre fonctionnalités, simplicité et coûts.

**Points clés** :
- ✅ Architecture cloud-native et scalable
- ✅ Couche de données moderne avec Apache Iceberg (ACID, time travel, schema evolution)
- ✅ Accès SQL universel via Trino (fédération de données)
- ✅ Transformation "Data as Code" avec DBT
- ✅ Sécurité et gouvernance intégrées
- ✅ Observabilité complète
- ✅ Haute disponibilité et résilience
- ✅ Stratégie de backup et DR

**Prochaines étapes** :
1. Validation de l'architecture avec les équipes
2. POC (Proof of Concept) sur un cluster de test
3. Déploiement progressif par environnement
4. Formation des équipes
5. Mise en place de la gouvernance

---

## Annexes

### A. Ressources recommandées par composant

| Composant | CPU | RAM | Stockage | Replicas |
|-----------|-----|-----|----------|----------|
| Airflow Webserver | 1 | 2 Gi | - | 2 |
| Airflow Scheduler | 2 | 4 Gi | - | 2 |
| Airflow Worker | 1 | 2 Gi | - | 2-20 (HPA) |
| Trino Coordinator | 4 | 8 Gi | - | 2+ |
| Trino Worker | 8 | 16 Gi | - | 4-20 (HPA) |
| PostgreSQL Master | 8 | 16 Gi | 500 Gi+ | 1 |
| PostgreSQL Replica | 4 | 8 Gi | 500 Gi+ | 2+ |
| MINIO | 2 | 4 Gi | 50 Ti+ | 4+ |
| Spark Driver | 2 | 4 Gi | - | - |
| Spark Executor | 2 | 8 Gi | - | 2-50 (HPA) |
| Prometheus | 4 | 8 Gi | 50 Gi | 1 |
| Grafana | 1 | 2 Gi | 10 Gi | 2 |
| Keycloak | 2 | 4 Gi | 20 Gi | 2 |
| Loki | 2 | 4 Gi | 100 Gi | 1 |
| Airbyte Worker | 2 | 4 Gi | 50 Gi | 2-10 (HPA) |
| Nifi Node | 4 | 8 Gi | 100 Gi | 3+ |

### B. Ports et endpoints

| Service | Port | Endpoint |
|---------|------|----------|
| Airflow | 8080 | `airflow.data-platform.local` |
| Trino | 8080 | `trino.data-platform.local` |
| Grafana | 3000 | `grafana.data-platform.local` |
| Keycloak | 8080 | `keycloak.data-platform.local` |
| PostgreSQL | 5432 | `postgresql.data-platform-storage.svc.cluster.local` |
| MINIO | 9000, 9001 | `minio.data-platform-storage.svc.cluster.local` |
| Prometheus | 9090 | `prometheus.data-platform-observability.svc.cluster.local` |
| DataHub | 8080 | `datahub.data-platform-governance.svc.cluster.local` |

### C. Commandes utiles

```bash
# Vérifier l'état des pods
kubectl get pods -A

# Logs d'un service
kubectl logs -f <pod-name> -n <namespace>

# Accès à Trino
kubectl port-forward svc/trino-coordinator 8080:8080 -n data-platform-processing
# Puis accès via: http://localhost:8080

# Accès à PostgreSQL
kubectl port-forward svc/postgresql 5432:5432 -n data-platform-storage

# Requête Trino depuis CLI
kubectl exec -it trino-coordinator-0 -n data-platform-processing -- \
  trino --server http://localhost:8080 --catalog iceberg --schema analytics

# Lister les tables Iceberg via Trino
kubectl exec -it trino-coordinator-0 -n data-platform-processing -- \
  trino --server http://localhost:8080 --execute "SHOW TABLES FROM iceberg.analytics"

# Backup Velero
velero backup create backup-$(date +%Y%m%d) --include-namespaces data-platform-core

# Restauration Velero
velero restore create --from-backup backup-20240101

# Compaction des tables Iceberg (via Spark)
kubectl create job --from=cronjob/spark-iceberg-compaction compaction-$(date +%Y%m%d) \
  -n data-platform-processing
```

---

**Document créé le** : 2024
**Version** : 1.0
**Auteur** : Équipe Data Platform

