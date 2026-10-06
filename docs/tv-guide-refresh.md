# Actualisation quotidienne du guide TV

`bin/refresh-tv-guide` télécharge et valide le guide TNT XMLTV de xmltvfr.fr,
compare la période commune avec le dernier import réussi, puis importe le
nouvel instantané. Le fichier temporaire est effacé après exécution.

L’actualisation conserve les chaînes du catalogue TNT, sauf celles désactivées
dans vidb, ainsi que les chaînes supplémentaires explicitement reliées et
activées. Les favoris ne limitent pas l’import. Canal+ ne fait pas partie du
catalogue. Le filtrage intervient avant la lecture des horaires des programmes.

Une émission de durée nulle ou négative sur une chaîne retenue est écartée,
sans inventer d’heure de fin. Ses informations sont consignées dans le journal
et dans `source_metadata.download_filter` de l’import réussi. Les horodatages
illisibles sur une chaîne retenue et les documents XML malformés restent bloquants.
La comparaison avec l’ancien guide porte sur le même bouquet.

Un verrou empêche deux exécutions simultanées de `bin/refresh-tv-guide`.
Une alerte apparaît dans le guide si le dernier import réussi date de plus de
36 heures. Cet indicateur ne prétend pas identifier la cause d’un échec.

Le contrôle refuse un document vide, périmé, sans période commune, dont
l'horizon recule de plus de six heures ou dont une chaîne perd plus de
30 % des programmes dans la période commune.
Il affiche le nombre d'observations inchangées, modifiées ou disparues,
et les intentions vidb dont l'observation ne figure plus à l'identique.
Les programmations Kaffeine et les intentions vidb ne sont jamais modifiées
par cet import. Le guide courant reste le dernier import réussi si l'une
des étapes échoue.

Installer les unités sur Zeus après le déploiement du code :

```sh
sudo install -m 644 ops/systemd/vidb-tv-guide-refresh.service /etc/systemd/system/
sudo install -m 644 ops/systemd/vidb-tv-guide-refresh.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl start vidb-tv-guide-refresh.service
sudo journalctl -u vidb-tv-guide-refresh.service -n 80 --no-pager
sudo systemctl enable --now vidb-tv-guide-refresh.timer
systemctl list-timers vidb-tv-guide-refresh.timer
```

Le service utilise la release courante et la configuration de production.
Pour vérifier un échec : `systemctl status vidb-tv-guide-refresh.service`
et `journalctl -u vidb-tv-guide-refresh.service`.
Le timer fixe explicitement 05 h 00 dans le fuseau Europe/Paris.
`Persistent=true` rattrape une échéance manquée lorsque le timer est relancé ;
une échéance survenue pendant la veille est traitée au réveil. Il ne provoque
pas de réveil matériel du PC.

Il faut installer et activer ces unités une fois : le déploiement de la release
ne les installe pas automatiquement. Vérifier ensuite :

```sh
systemctl is-enabled vidb-tv-guide-refresh.timer
systemctl list-timers --all vidb-tv-guide-refresh.timer
```

Le service fait directement le téléchargement et l’import en production.
Il ne dépend pas du script `bin/update-xmltv` du prototype.
Après un échec, consulter le journal et relancer le service une fois la cause
corrigée. Les programmations Kaffeine existantes restent intactes.
