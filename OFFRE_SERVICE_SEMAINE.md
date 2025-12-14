# Offre de Service - Data Plateforme (1 semaine)

**Client** : CBAO  
**Projet** : Revue d'architecture et mise en place des composants clés  
**Date** : Décembre 2024  
**Durée** : 1 semaine (5 jours ouvrés)

**Consultant** : Bassirou KA  
**Sociétés** : Tecsen France / Back Consulting Sénégal  
**Email** : ka.bassirou@gmail.com  
**Téléphone** : +33 6 34 24 79 25  

---

## Table des matières

1. [Contexte et objectifs](#contexte-et-objectifs)
2. [Périmètre de la prestation](#périmètre-de-la-prestation)
3. [Détail des prestations](#détail-des-prestations)
4. [Planification](#planification)
5. [Chiffrage](#chiffrage)
6. [Modalités d'intervention](#modalités-dintervention)
7. [Livrables](#livrables)
8. [Conditions générales](#conditions-générales)

---

## Contexte et objectifs

### Contexte

La CBAO souhaite accélérer la mise en place de sa dataplateforme en se concentrant sur les composants essentiels pour l'intégration et l'orchestration des données.

### Objectifs de la semaine

- ✅ **Revue et challenge de l'architecture** : Validation et optimisation de l'architecture proposée
- ✅ **Mise en place d'Apache Nifi** : Déploiement et configuration opérationnelle pour l'intégration de données
- ⭐ **Nice to have** : Mise en place d'Apache Airflow pour l'orchestration
- ⭐ **Nice to have** : Mise en place de Trino pour l'accès SQL universel

---

## Périmètre de la prestation

### Prestations incluses

✅ **Revue et challenge de l'architecture de la data plateforme**
- Analyse critique de l'architecture documentée
- Identification des points d'amélioration et optimisations
- Validation des choix technologiques
- Recommandations de mise en œuvre

✅ **Mise en place d'Apache Nifi**
- Déploiement sur Kubernetes (cluster HA)
- Configuration des processors et flows de base
- Intégration avec les systèmes existants
- Documentation et formation

### Prestations optionnelles (Nice to have)

⭐ **Mise en place d'Apache Airflow** (si temps disponible)
- Déploiement sur Kubernetes
- Configuration KubernetesExecutor
- Intégration avec Nifi
- Exemples de DAGs

⭐ **Mise en place de Trino** (si temps disponible)
- Déploiement coordinateur + workers
- Configuration des catalogues
- Intégration avec les sources de données
- Tests de requêtes

---

## Détail des prestations

### Jour 1 : Revue et Challenge de l'Architecture

**Durée** : 1 jour-homme  
**Modalité** : 100% présentiel

#### Activités

1. **Analyse approfondie de l'architecture existante**
   - Revue complète de la documentation d'architecture
   - Analyse des composants et de leurs interactions
   - Identification des points critiques et risques potentiels
   - Évaluation de la scalabilité et de la résilience

2. **Challenge architectural**
   - Validation des choix technologiques (Nifi, Airflow, Trino, Iceberg, etc.)
   - Identification des alternatives et comparaisons
   - Optimisations pour l'environnement on-premise Kubernetes
   - Recommandations de sizing et ressources

3. **Planification de la mise en œuvre**
   - Priorisation des composants à déployer
   - Stratégie de déploiement par phases
   - Identification des dépendances entre composants
   - Plan de tests et validation

**Livrables** :
- Document de revue d'architecture (10-15 pages)
- Diagrammes d'architecture mis à jour
- Plan de déploiement détaillé
- Matrice de risques et mitigation
- Recommandations de sizing

---

### Jour 2-3 : Mise en place d'Apache Nifi

**Durée** : 2 jours-hommes  
**Modalité** : 100% présentiel

#### Activités

1. **Préparation de l'environnement**
   - Configuration des namespaces Kubernetes
   - Vérification des prérequis (stockage, réseau, ressources)
   - Configuration des secrets et credentials

2. **Déploiement d'Apache Nifi**
   - Déploiement en mode cluster (3+ nodes pour HA)
   - Configuration de ZooKeeper pour la coordination
   - Configuration des volumes persistants pour les flowfiles
   - Configuration de la provenance (audit trail)

3. **Configuration et intégration**
   - Configuration des processors essentiels
   - Création de flows d'ingestion de base
   - Intégration avec les sources de données existantes
   - Configuration de la sécurité (authentification, autorisation)
   - Intégration avec MINIO (S3) pour le stockage

4. **Tests et validation**
   - Tests de flows d'ingestion
   - Tests de performance et scalabilité
   - Validation de la haute disponibilité
   - Tests de récupération après panne

**Livrables** :
- Apache Nifi opérationnel en cluster HA
- Manifests Kubernetes / Helm charts pour Nifi
- Configuration ZooKeeper
- Exemples de flows Nifi documentés
- Documentation de configuration et d'utilisation
- Guide de bonnes pratiques

---

### Jour 4 : Mise en place d'Apache Airflow (Nice to have)

**Durée** : 1 jour-homme  
**Modalité** : 100% présentiel  
**Condition** : Si temps disponible après Nifi

#### Activités

1. **Déploiement d'Apache Airflow**
   - Déploiement via Helm chart officiel
   - Configuration KubernetesExecutor
   - Configuration des composants (webserver, scheduler, workers)
   - Configuration de la base de données PostgreSQL

2. **Configuration et intégration**
   - Intégration avec Keycloak pour l'authentification (si disponible)
   - Configuration des connexions aux sources de données
   - Intégration avec Nifi (déclenchement de flows)
   - Configuration des variables et connexions

3. **Exemples et documentation**
   - Création d'exemples de DAGs
   - DAG d'orchestration d'un flow Nifi
   - Documentation d'utilisation
   - Guide de création de DAGs

**Livrables** :
- Apache Airflow opérationnel
- Configuration KubernetesExecutor
- Exemples de DAGs (orchestration Nifi)
- Documentation de configuration
- Guide d'utilisation

---

### Jour 5 : Mise en place de Trino (Nice to have)

**Durée** : 1 jour-homme  
**Modalité** : 100% présentiel  
**Condition** : Si temps disponible après Airflow

#### Activités

1. **Déploiement de Trino**
   - Déploiement du coordinateur (HA avec 2+ replicas)
   - Déploiement des workers (4+ workers)
   - Configuration des ressources (CPU, RAM)

2. **Configuration des catalogues**
   - Configuration du catalogue Iceberg (MINIO)
   - Configuration du catalogue PostgreSQL
   - Configuration du catalogue MINIO (S3)
   - Tests de connexion aux sources

3. **Intégration et tests**
   - Intégration avec Keycloak pour l'authentification (si disponible)
   - Tests de requêtes SQL sur tables Iceberg
   - Tests de requêtes fédérées (jointures entre sources)
   - Configuration des resource groups pour isolation

**Livrables** :
- Trino opérationnel (coordinateur + workers)
- Configuration des catalogues
- Exemples de requêtes SQL documentées
- Documentation de configuration
- Guide d'utilisation pour les analystes

---

## Planification

### Planning sur 1 semaine (5 jours ouvrés)

| Jour | Activité | Durée | Statut |
|------|----------|-------|--------|
| **Lundi** | Revue et Challenge de l'Architecture | 1 JH | ✅ Obligatoire |
| **Mardi** | Mise en place Apache Nifi (Partie 1) | 1 JH | ✅ Obligatoire |
| **Mercredi** | Mise en place Apache Nifi (Partie 2) | 1 JH | ✅ Obligatoire |
| **Jeudi** | Mise en place Apache Airflow | 1 JH | ⭐ Nice to have |
| **Vendredi** | Mise en place Trino | 1 JH | ⭐ Nice to have |

### Priorisation

**Si le temps est limité** :
1. ✅ **Priorité 1** : Revue d'architecture (Jour 1)
2. ✅ **Priorité 2** : Mise en place Nifi (Jours 2-3)
3. ⭐ **Priorité 3** : Airflow (Jour 4) - si temps disponible
4. ⭐ **Priorité 4** : Trino (Jour 5) - si temps disponible

**Note** : Les composants "Nice to have" seront déployés selon le temps disponible. Si le déploiement de Nifi prend plus de temps que prévu, Airflow et Trino pourront être reportés à une phase ultérieure.

---

## Chiffrage

### Répartition des jours-hommes

| Phase | Prestation | Durée (JH) | Type |
|-------|------------|------------|------|
| Jour 1 | Revue et Challenge de l'Architecture | 1 | Forfait |
| Jours 2-3 | Mise en place Apache Nifi | 2 | Forfait |
| Jour 4 | Mise en place Apache Airflow (Nice to have) | 1 | Forfait |
| Jour 5 | Mise en place Trino (Nice to have) | 1 | Forfait |
| **TOTAL** | | **5 JH** | |

### Détail du chiffrage

| Phase | Description | JH | Tarif unitaire | Montant HT |
|-------|-------------|-----|----------------|------------|
| Jour 1 | Revue et Challenge de l'Architecture | 1 | 350 000 FCFA | 350 000 FCFA |
| Jours 2-3 | Mise en place Apache Nifi | 2 | 350 000 FCFA | 700 000 FCFA |
| Jour 4 | Mise en place Apache Airflow (Nice to have) | 1 | 350 000 FCFA | 350 000 FCFA |
| Jour 5 | Mise en place Trino (Nice to have) | 1 | 350 000 FCFA | 350 000 FCFA |
| **TOTAL HT** | | **5** | | **1 750 000 FCFA** |
| **TVA (20%)** | | | | 350 000 FCFA |
| **TOTAL TTC** | | | | **2 100 000 FCFA** |

### Options de facturation

**Option 1 : Forfait complet (recommandé)**
- Montant forfaitaire pour les 5 jours : **2 100 000 FCFA TTC**
- Facturation : 50% à la commande, 50% à la livraison

**Option 2 : Forfait minimum + Régie**
- Forfait minimum (Jours 1-3) : **1 260 000 FCFA TTC** (3 JH)
- Régie pour Jours 4-5 : **840 000 FCFA TTC** (2 JH) - si réalisés
- Facturation : 50% à la commande, 50% selon avancement

**Recommandation** : Option 1 (forfait complet) pour garantir la disponibilité complète de la semaine.

---

## Modalités d'intervention

### Répartition présentiel / distanciel

**Modalité** : **100% présentiel** à Dakar

- **Durée** : 1 semaine complète (5 jours ouvrés)
- **Lieu** : Sur site client à Dakar
- **Horaires** : 8h-17h (adaptable selon besoins)

### Organisation du travail

**Présentiel à Dakar** :
- Travail en collaboration avec l'équipe Data Engineer
- Accès direct au cluster Kubernetes
- Sessions de formation et transfert de compétences
- Points d'avancement quotidiens

**Communication** :
- Point d'avancement quotidien (15-30 min)
- Documentation en temps réel
- Support technique pendant la semaine

### Prérequis pour l'intervention

**Infrastructure** :
- ✅ Cluster Kubernetes opérationnel et accessible
- ✅ Accès administrateur au cluster
- ✅ Stockage persistant disponible (OpenEBS ou équivalent)
- ✅ Réseau configuré (ingress controller)
- ✅ Accès internet pour téléchargement d'images Docker

**Équipe** :
- ✅ Équipe Data Engineer disponible (2-3 personnes)
- ✅ Accès aux environnements de développement/staging
- ✅ Accès aux sources de données pour tests

**Outils** :
- ✅ Accès Git pour versioning
- ✅ Outils de communication (Teams/Slack)
- ✅ Accès à la documentation existante
- ✅ Accès VPN si nécessaire

---

## Livrables

### Jour 1 : Revue d'Architecture

- ✅ **Document de revue d'architecture** (10-15 pages)
  - Analyse critique de l'architecture existante
  - Points d'amélioration identifiés
  - Recommandations de mise en œuvre
  - Plan de déploiement détaillé
  - Matrice de risques et mitigation

- ✅ **Diagrammes d'architecture mis à jour**
  - Architecture globale
  - Architecture détaillée par composant
  - Flux de données

### Jours 2-3 : Apache Nifi

- ✅ **Apache Nifi opérationnel**
  - Cluster HA (3+ nodes)
  - Configuration ZooKeeper
  - Flows d'ingestion de base fonctionnels

- ✅ **Manifests Kubernetes / Helm charts**
  - Configuration complète pour déploiement
  - Documentation de déploiement

- ✅ **Documentation technique**
  - Guide de configuration
  - Guide d'utilisation
  - Exemples de flows documentés
  - Guide de bonnes pratiques

### Jour 4 : Apache Airflow (Nice to have)

- ✅ **Apache Airflow opérationnel**
  - Configuration KubernetesExecutor
  - Intégration avec Nifi

- ✅ **Exemples de DAGs**
  - DAG d'orchestration d'un flow Nifi
  - Documentation des DAGs

- ✅ **Documentation**
  - Guide de configuration
  - Guide de création de DAGs

### Jour 5 : Trino (Nice to have)

- ✅ **Trino opérationnel**
  - Coordinateur + workers déployés
  - Catalogues configurés

- ✅ **Documentation**
  - Guide de configuration
  - Guide d'utilisation pour analystes
  - Exemples de requêtes SQL

### Livrables transversaux

- ✅ **Documentation technique complète**
- ✅ **Architecture as Code** (Helm charts, manifests Kubernetes)
- ✅ **Guide de troubleshooting**
- ✅ **Rapport de synthèse de la semaine**

---

## Conditions générales

### Prérequis

**Infrastructure** :
- Cluster Kubernetes opérationnel avec accès administrateur
- Stockage persistant disponible (OpenEBS ou équivalent)
- Réseau configuré (ingress controller)
- Accès internet pour téléchargement d'images Docker

**Équipe** :
- Équipe Data Engineer disponible (2-3 personnes)
- Accès aux environnements de développement/staging
- Accès aux sources de données pour tests

**Outils** :
- Accès Git pour versioning
- Outils de communication (Teams/Slack)
- Accès à la documentation existante

### Gestion des risques

**Risques identifiés** :

1. **Complexité du déploiement Nifi**
   - *Mitigation* : Expérience confirmée, documentation détaillée, temps alloué suffisant

2. **Temps insuffisant pour les composants "Nice to have"**
   - *Mitigation* : Priorisation claire, report possible en phase ultérieure

3. **Problèmes d'accès au cluster**
   - *Mitigation* : Vérification des prérequis avant l'intervention

4. **Compatibilité des composants**
   - *Mitigation* : Versions validées, tests en environnement de développement

### Propriété intellectuelle

- Les livrables (code, configurations, documentation) sont la propriété du client
- Le consultant conserve le droit d'utiliser les connaissances acquises (sans divulguer d'informations confidentielles)

### Confidentialité

- Engagement de confidentialité sur les informations du client
- Respect de la réglementation applicable sur les données

### Conditions de facturation

**Option 1 : Forfait complet (recommandé)**
- 50% à la commande
- 50% à la livraison (fin de semaine)

**Option 2 : Forfait minimum + Régie**
- 50% à la commande (forfait minimum)
- 50% selon avancement (régie)

### Support post-intervention

- **Support inclus** : 2 semaines de support à distance après l'intervention
- **Support étendu** : Possibilité de support supplémentaire en régie

---

## Profil du consultant

**Consultant** : Bassirou KA  
**Sociétés** : 
- Tecsen France
- Back Consulting Sénégal

**Architecte Data Ops** avec :
- 14 ans d'expérience en architecture de données
- Expertise Kubernetes et cloud-native
- Expérience confirmée sur Apache Nifi, Airflow, Trino, Iceberg
- Certifications Kubernetes (CKA) et autres cloud
- Certification ISO-27001
- CV en pièce jointe

---

**Contact** : Bassirou KA  
**Sociétés** : Tecsen France / Back Consulting Sénégal  
**Email** : ka.bassirou@gmail.com  
**Téléphone** : +33 6 34 24 79 25

