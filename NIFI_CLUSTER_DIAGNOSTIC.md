# Diagnostic du Cluster NiFi

## Résumé du problème

Dans l'UI NiFi, un seul nœud est visible alors que 3 pods sont en cours d'exécution. Chaque pod pense être le coordinateur du cluster et ne découvre pas les autres nœuds.

## Constatations

### ✅ Configuration correcte
- **FQDN unique** : Chaque pod a son FQDN unique correctement configuré
  - Pod 0: `nifi-platform-nifi-0.nifi-platform-nifi-headless.data-platform-integration.svc.cluster.local`
  - Pod 1: `nifi-platform-nifi-1.nifi-platform-nifi-headless.data-platform-integration.svc.cluster.local`
  - Pod 2: `nifi-platform-nifi-2.nifi-platform-nifi-headless.data-platform-integration.svc.cluster.local`
- **Cluster activé** : `nifi.cluster.is.node=true` sur tous les pods
- **ZooKeeper** : Configuration correcte (`nifi-platform-zookeeper:2181`)
- **DNS** : Le headless service résout bien les 3 pods (3 IPs différentes)

### ❌ Problèmes identifiés

1. **ZooKeeper** : Seuls les "leaders" sont présents, aucun nœud n'est enregistré sous `/nifi/cluster/nodes`
2. **Heartbeats** : Chaque pod envoie des heartbeats vers son propre FQDN au lieu de découvrir les autres nœuds
3. **Coordinateur** : Chaque pod pense être le Cluster Coordinator
4. **Découverte** : Les nœuds ne se découvrent pas mutuellement via ZooKeeper

## Logs pertinents

```
LeaderElectionNodeProtocolSender Determined that Cluster Coordinator is located at 
nifi-platform-nifi-0.nifi-platform-nifi-headless.data-platform-integration.svc.cluster.local:8082
```

Chaque pod voit son propre FQDN comme coordinateur.

## Causes possibles

1. **Découverte de cluster** : NiFi utilise ZooKeeper pour la découverte, mais les nœuds ne s'enregistrent pas correctement
2. **Élection du coordinateur** : L'élection du coordinateur via ZooKeeper ne fonctionne pas correctement
3. **Configuration manquante** : Il pourrait manquer une propriété de configuration pour la découverte de cluster

## Solutions à tester

### Solution 1 : Vérifier la configuration de découverte de cluster

NiFi devrait automatiquement découvrir les nœuds via ZooKeeper. Vérifier si une propriété de configuration est manquante.

### Solution 2 : Redémarrer les pods dans l'ordre

1. Arrêter tous les pods
2. Démarrer le pod 0 et attendre qu'il soit complètement démarré
3. Démarrer le pod 1 et attendre qu'il rejoigne le cluster
4. Démarrer le pod 2 et attendre qu'il rejoigne le cluster

### Solution 3 : Vérifier les logs de démarrage complets

Les nœuds devraient s'enregistrer dans ZooKeeper au démarrage. Vérifier les logs de démarrage pour voir si l'enregistrement échoue.

### Solution 4 : Vérifier la connectivité réseau

S'assurer que les pods peuvent communiquer entre eux sur le port 8082 (cluster protocol port).

## Commandes de diagnostic

```bash
# Exécuter le script de diagnostic
./diagnose-nifi-cluster.sh

# Vérifier l'état dans ZooKeeper
kubectl exec -n data-platform-integration nifi-platform-zookeeper-0 -- \
  /bin/sh -c 'echo "ls -R /nifi" | /apache-zookeeper-3.9.4-bin/bin/zkCli.sh'

# Vérifier la configuration de chaque pod
for pod in nifi-platform-nifi-0 nifi-platform-nifi-1 nifi-platform-nifi-2; do
  kubectl exec -n data-platform-integration $pod -- \
    grep "^nifi.cluster" /opt/nifi/nifi-current/conf/nifi.properties
done
```

## Prochaines étapes

1. Vérifier les logs de démarrage complets pour voir l'enregistrement dans ZooKeeper
2. Vérifier si les nœuds peuvent communiquer entre eux sur le port 8082
3. Tester un redémarrage séquentiel des pods
4. Vérifier la documentation NiFi pour la configuration de cluster avec ZooKeeper



kubectl exec -n data-platform-integration nifi-platform-zookeeper-0 -- /bin/sh -c '/apache-zookeeper-3.9.4-bin/bin/zkCli.sh <<EOF
ls -R /nifi
getAllChildrenNumber /nifi
quit
EOF
' 2>&1 | grep -v "INFO\|WARN\|DEBUG\|Connecting\|Client\|Welcome\|JLine\|WATCHER\|Using\|^$"