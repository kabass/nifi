# Plan de déploiement Helm Nifi (composant par composant)

Ce dossier décrit l’ordre de déploiement logique du chart `kubernets/app/nifi/helm` et les commandes Helm associées. Adapter les valeurs via `values.yaml`/`values-*.yaml` ou `--set`.

## 0. Prérequis généraux
- Namespace cible : `data-platform-integration` (par défaut `global.namespace`).
- Ingress controller (ex. nginx), StorageClass (ex. `longhorn`), metrics-server (pour HPA).
- Accès aux images `apache/nifi`, `apache/nifi-registry`, `zookeeper`.

## 1. Préparer les secrets (optionnel selon `secrets.*`)
- Si `secrets.keycloak.create=false` ou `secrets.database.create=false`, créer les secrets avant Helm :
  - `nifi-platform-keycloak` : `nifi-client-secret`, `nifi-registry-client-secret`.
  - `nifi-platform-database` : `postgresql-password` (si PostgreSQL pour Registry).
  - `nifi-platform-ssl` si SSL activé (`secrets.ssl.*`).
- Sinon, renseigner les valeurs encodées base64 dans `values.yaml` (`secrets.*.create=true`).
- **Test rapide** :
```bash
kubectl get secret nifi-platform-keycloak -n data-platform-integration
kubectl get secret nifi-platform-database -n data-platform-integration
kubectl get secret nifi-platform-ssl -n data-platform-integration
```

## 2. ServiceAccount / RBAC
Templates : `serviceaccount.yaml`, `rbac.yaml`.
- Ajuster `serviceAccount.create/name/annotations` si SA existant.
- Laisser `rbac.create=true` pour générer les rôles/rolebindings nécessaires.
- **Test rapide** :
```bash
kubectl get sa -n data-platform-integration | grep nifi-platform
kubectl get role,rolebinding -n data-platform-integration | grep nifi-platform
```

## 3. ZooKeeper (interne ou externe)
Template : `zookeeper-statefulset.yaml`.
- Choisir interne (`nifi.cluster.zookeeper.enabled=true`) ou externe (`external.enabled=true` + `connectionString`).
- Ressources/stockage : `nifi.cluster.zookeeper.resources`, `storageClassName`, `storage.size`.
- Commande d’installation partielle (dry-run recommandé) :
```bash
helm upgrade --install nifi-platform /Users/bka/project/perso/cbao/kubernets/app/nifi/helm \
  -n data-platform-integration \
  -f values.yaml \
  --set nifi.cluster.zookeeper.enabled=true \
  --dry-run
```
- **Tests rapides (interne)** :
```bash
kubectl get sts -n data-platform-integration | grep zookeeper
kubectl get pods -n data-platform-integration -l app.kubernetes.io/component=zookeeper -w
kubectl get pvc -n data-platform-integration -l app.kubernetes.io/component=zookeeper
kubectl exec -n data-platform-integration -it <zk-pod> -- zkServer.sh status
```
- **Test cohérence lecture/écriture inter-nœuds (interne)** :
```bash
# 1) Choisir deux pods ZK, ex. zk0 et zk1
POD0=$(kubectl get pods -n data-platform-integration -l app.kubernetes.io/component=zookeeper -o jsonpath='{.items[0].metadata.name}')
POD1=$(kubectl get pods -n data-platform-integration -l app.kubernetes.io/component=zookeeper -o jsonpath='{.items[1].metadata.name}')

# 2) Écrire une donnée depuis POD0
kubectl exec -n data-platform-integration -it $POD0 -- zkCli.sh create /demo-nifi "hello"
kubectl exec -n data-platform-integration -it $POD0 -- zkCli.sh get /demo-nifi

# 3) Lire depuis POD1 (doit renvoyer "hello")
kubectl exec -n data-platform-integration -it $POD1 -- zkCli.sh get /demo-nifi

# 4) Nettoyer (optionnel)
kubectl exec -n data-platform-integration -it $POD0 -- zkCli.sh delete /demo-nifi
```

## 4. Configs Nifi (ConfigMaps + Entrypoint)
Templates : `nifi-configmap.yaml`, `nifi-entrypoint-script.yaml`.
- Vérifier/adapter `nifi.properties.*`, ports (`web.http/https`), JVM (`nifi.jvm.*`), sécurité (`nifi.security.*`).
- Ajuster éventuels args additionnels via `nifi.jvm.additionalJavaArgs`.
- **Test rapide** :
```bash
kubectl get configmap -n data-platform-integration | grep nifi-platform
kubectl describe configmap -n data-platform-integration nifi-platform-nifi-config
```

## 5. StatefulSet Nifi
Template : `nifi-statefulset.yaml`.
- Taille du cluster : `nifi.cluster.nodeCount` ou HPA (voir étape 8).
- Ressources : `nifi.resources.*`; stockage : `nifi.storage.*` (+ `stateSize`).
- Affinités/taints : `nifi.nodeSelector`, `tolerations`, `affinity`.
- Commande :
```bash
helm upgrade --install nifi-platform /Users/bka/project/perso/cbao/kubernets/app/nifi/helm \
  -n data-platform-integration \
  -f values.yaml
```
- **Tests rapides** :
```bash
kubectl get sts -n data-platform-integration | grep nifi
kubectl get pods -n data-platform-integration -l app.kubernetes.io/component=nifi -w
kubectl get pvc -n data-platform-integration -l app.kubernetes.io/component=nifi
kubectl logs -n data-platform-integration -l app.kubernetes.io/component=nifi --tail=50
```
- **Vérifier que le cluster a le bon nombre de nœuds** :
```bash
# Nombre attendu (sans HPA) : values nifi.cluster.nodeCount
EXPECTED=3   # ajuster à la valeur configurée
kubectl get pods -n data-platform-integration -l app.kubernetes.io/component=nifi \
  --no-headers | wc -l

# Avec HPA : vérifier HPA + comparer réplicas courants
kubectl get hpa -n data-platform-integration nifi-platform-nifi
kubectl get sts -n data-platform-integration nifi-platform-nifi -o jsonpath='{.status.replicas}{"\n"}'
kubectl get pods -n data-platform-integration -l app.kubernetes.io/component=nifi --no-headers

# Vérifier la vue cluster depuis un pod Nifi
POD=$(kubectl get pods -n data-platform-integration -l app.kubernetes.io/component=nifi -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n data-platform-integration -it $POD -- bash -lc "cat /opt/nifi/nifi-current/conf/cluster.json || ls /opt/nifi/nifi-current/conf"
```

## 6. Services Nifi
Template : `nifi-services.yaml`.
- Service headless pour découverte (`ClusterIP: None`) + service principal (`nifi.service.*`).
- `service.type` (ClusterIP/NodePort/LoadBalancer), `service.port` (8080 par défaut).
- **Tests rapides** :
```bash
kubectl get svc -n data-platform-integration | grep nifi
kubectl get endpoints -n data-platform-integration nifi-platform-nifi-headless
```

## 7. Ingress Nifi
Template : `nifi-ingress.yaml`.
- Activer via `nifi.ingress.enabled=true`; classe `nifi.ingress.className` (ex. `nginx`).
- Ajouter annotations TLS/issuer si besoin (`nifi.ingress.annotations`, secret TLS via `cert-manager`).
- **Tests rapides** :
```bash
kubectl get ing -n data-platform-integration | grep nifi
kubectl describe ing -n data-platform-integration nifi-platform-nifi
kubectl get secret -n data-platform-integration nifi-platform-nifi-tls || true
```

## 8. Autoscaling (HPA)
Template : `nifi-hpa.yaml`.
- Activer `nifi.cluster.autoscaling.enabled=true`; définir `minReplicas`, `maxReplicas`, cibles CPU/mémoire, `behavior`.
- Metrics-server requis. Lorsqu’activé, `minReplicas` remplace `nodeCount`.
- **Tests rapides** :
```bash
kubectl get hpa -n data-platform-integration | grep nifi
kubectl describe hpa -n data-platform-integration nifi-platform-nifi
kubectl top pods -n data-platform-integration -l app.kubernetes.io/component=nifi
```

## 9. Nifi Registry
Templates : `nifi-registry-configmap.yaml`, `nifi-registry-deployment.yaml`, `nifi-registry-service.yaml`, `nifi-registry-ingress.yaml`.
- Réplicas : `nifiRegistry.replicas`.
- Base : `nifiRegistry.database.type` (`h2` en dev, `postgresql` en prod) + secrets associés.
- Auth : `nifiRegistry.keycloak.*` si SSO.
- Ingress : `nifiRegistry.ingress.*` (annotations cert-manager déjà prévues).
- **Tests rapides** :
```bash
kubectl get deploy -n data-platform-integration | grep nifi-registry
kubectl get pods -n data-platform-integration -l app.kubernetes.io/component=nifi-registry -w
kubectl logs -n data-platform-integration -l app.kubernetes.io/component=nifi-registry --tail=50
kubectl get svc -n data-platform-integration | grep nifi-registry
kubectl get ing -n data-platform-integration | grep nifi-registry
```

## 10. Ingress/Services Registry
- Service : `nifiRegistry.service.port` (18080).
- Ingress TLS : `nifiRegistry.ingress.tls[].secretName/hosts`.
- **Tests rapides** :
```bash
kubectl describe ing -n data-platform-integration nifi-platform-nifi-registry
kubectl get secret -n data-platform-integration nifi-registry-tls || true
```

## 11. Observabilité et vérifications
- Pods : `kubectl get pods -n data-platform-integration`.
- Services/Ingress : `kubectl get svc,ing -n data-platform-integration`.
- HPA : `kubectl get hpa -n data-platform-integration`.
- Logs : `kubectl logs -n data-platform-integration -l app.kubernetes.io/component=nifi`.

## 12. Promotion dev → prod (exemple)
- Dev : `helm upgrade --install nifi-platform ... -f values-dev.yaml`.
- Prod : `helm upgrade --install nifi-platform ... -f values-prod.yaml`.
- Ajuster secrets/ingress/ressources avant promotion.

## 13. Désinstallation (attention aux données)
```bash
helm uninstall nifi-platform -n data-platform-integration
# Optionnel : supprimer les PVC après sauvegarde
kubectl delete pvc -n data-platform-integration -l app.kubernetes.io/name=nifi-platform
```

## Résumé d’ordre recommandé
1) Secrets (si non gérés par Helm)  
2) ServiceAccount/RBAC  
3) ZooKeeper (ou déclarer l’externe)  
4) ConfigMaps/Entrypoint Nifi  
5) StatefulSet Nifi + Services  
6) Ingress Nifi  
7) HPA Nifi (si activé)  
8) Nifi Registry (deployment + service)  
9) Ingress Registry  
10) Vérifications / Observabilité

