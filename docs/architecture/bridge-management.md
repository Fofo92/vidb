# Gestion commune des passerelles

`bin/bridges` rassemble l’administration, sans fusionner les autorisations ni
les protocoles des passerelles existantes. Il s’exécute **comme Pascal**, pas
avec sudo. Les seules étapes privilégiées appellent explicitement sudo.

## Périmètre

| Composant | Installation | Diagnostic sans mutation |
| --- | --- | --- |
| `encoder-project` | Commande existante, secret conservé | Concordance du secret, du compte et de l’URL côté serveur/client |
| `kaffeine` | Programme restreint et sudoers existants | Lecture `ListProgramSchedule` depuis le compte vidb |
| `copy-trash` | Installateur existant, code copié et autorisation dédiée | Requête `health` depuis vidb : volume et base de file en lecture seule |
| `quarantine` | Seulement si demandé explicitement | État du timer, prochain passage et résultat du service |
| `relocation` | Aucune installation globale | Rappel des workers ponctuels liés à un plan |

Les workers root de renommage ne deviennent pas un service permanent. Aucun
diagnostic ne lance de renommage, suppression, balayage de quarantaine,
enregistrement Kaffeine ou démarrage de worker. La santé de la corbeille ouvre
SQLite avec `readonly: true`, sans créer son registre ni migrer la base.

## Configuration commune

Depuis le dépôt vidb-clean, après application des patches de suppression de copie
**et du correctif d’accès aux releases de son installateur** :

```sh
bin/bridges configure --encoder-root ../video_encoder \
  --ruby "$(rbenv which ruby)" --url https://zeus.fodiman.fr
```

Le fichier privé `~/.config/vidb/bridges.json` (ou sous `XDG_CONFIG_HOME`) contient
uniquement propriétaire, dépôt video_encoder, Ruby, URL, chemin de release et
identifiant de compte optionnel. Il n’ajoute ni token ni mot de passe. Le fichier
est écrit atomiquement en mode 0600. Ajouter `--user-id N` si le compte vidb doit
être précisé. Ajouter `--deployed-code CHEMIN` pour une autre installation.
Ce dernier chemin n’est pas résolu avec les droits Pascal.

Le paramétrage commun pilote les installateurs. Les consommateurs existants
gardent leurs formats : `~/.config/video_encoder/vidb.json`,
`/srv/vidb/shared/encoder-bridge/server.json` et les variables serveur.
Les secrets existants restent à leurs emplacements, sans duplication dans
bridges.json ni dans les sorties. La commande de liaison de projet conserve
le token serveur existant ; elle ne le renouvelle pas sur une réinstallation.
Les anciennes commandes d’installation restent utilisables.

## Installation après vérification et déploiement

Le nouveau `health` doit être déployé avant d’actualiser la passerelle de
corbeille. Après `bin/check`, commit et déploiement habituel de vidb :

```sh
bin/bridges install
bin/bridges install --apply
sudo -v
bin/bridges check
```

La première commande n’affiche qu’un plan. `--apply` installe les trois passerelles
permanentes. On peut cibler `bin/bridges install copy-trash --apply`,
`kaffeine` ou `encoder-project`. L’installation s’arrête à la première erreur ;
les étapes précédentes ne sont pas annulées. Une nouvelle installation peut
les reprendre ; il n’y a pas de retour arrière automatique sur les fichiers
d’installation.

Les seules variables synchronisées dans `/etc/vidb/vidb.env` sont celles des
passerelles installées : `VIDB_KAFFEINE_BRIDGE`, `VIDB_KAFFEINE_USER` et
`VIDB_COPY_TRASH_USER`. Le reste du fichier est conservé, sans affichage des
secrets ; écriture atomique, propriétaire et mode conservés. Une installation
partielle laisse les variables de l’autre passerelle intactes.
Si ces valeurs changent, la commande indique de redémarrer **uniquement vidb** :

```sh
sudo systemctl restart vidb
bin/bridges check
```

L’outil ne redémarre aucun service automatiquement, ne relance pas video_encoder
et ne modifie pas ses projets, tâches ou sorties. Le timer de quarantaine
existant n’est pas réinstallé par `install --apply`.
Pour installer ce timer volontairement, la commande séparée reste disponible :

```sh
bin/bridges install quarantine --apply
```

Cette dernière délègue à l’installateur video_encoder existant : aperçu puis
activation du timer persistant, dont un passage manqué peut être rattrapé. Ce
n’est pas une commande de diagnostic ; elle garde le comportement de cet
installateur. La session utilisateur et son environnement Ruby doivent être
disponibles, comme pour son appel direct.

## Diagnostic

`bin/bridges check` utilise `sudo -n` : il ne demande pas de mot de passe et ne
change rien si l’accès manque. Faire `sudo -v` auparavant dans ce cas. Le rapport
continue après une erreur afin de présenter tous les composants. Code de sortie
0 si tous les contrôles réussissent, 1 sinon. Sortie exploitable :

```sh
bin/bridges check --json
```

La comparaison des identifiants est faite dans un petit processus privilégié
qui ne renvoie que son succès. Les erreurs capturées des sous-processus ne sont
pas reproduites, car elles pourraient contenir des identifiants. Le contrôle
de l’environnement ne lit dans les sorties que les trois variables publiques
ci-dessus et les compare aussi à celles chargées par le processus principal
vidb. Il signale donc un redémarrage vidb encore nécessaire.

Les contrôles Kaffeine et corbeille empruntent réellement la chaîne
`vidb → sudo → pascal`. Kaffeine doit être ouvert dans sa session utilisateur.
Un ancien pont de corbeille ne connaissant pas `health` nécessite la
réinstallation après déploiement. Le contrôle de liaison vérifie les fichiers
d’identifiants ; il ne prétend pas tester une identification HTTPS complète.
Le timer peut être actif avec un dernier passage en erreur : ce cas est signalé.
La commande ne lance jamais le service pour essayer de corriger son état.

## Tests

`test/python/test_bridges.py` est exécuté par
`test/services/bridge_management_test.rb`, donc par le `bin/check` Rails habituel.
Les tests emploient des fichiers temporaires et simulent les commandes
privilégiées. Ils vérifient notamment l’absence de mutation du diagnostic,
l’exclusion du timer de l’installation générale, la conservation des secrets,
la configuration partielle et la détection d’un environnement pas encore chargé.
