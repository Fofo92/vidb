# Actualisation quotidienne du guide TV

`bin/refresh-tv-guide` télécharge et valide le guide TNT XMLTV de xmltvfr.fr,
compare la période commune avec le dernier import réussi, puis importe le
nouvel instantané. Le fichier temporaire est effacé après exécution.

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
Le serveur doit conserver son fuseau horaire Europe/Paris pour l'exécution
quotidienne à 05 h 00 heure locale.
