# Actualisation automatique du suivi

Le bilan de la page d'accueil est recalculé en arrière-plan :

- après validation d'une transaction qui modifie un Record ou un VideoAsset ;
- toutes les quinze minutes, pour détecter les modifications sur disque ;
- au premier démarrage du service après installation.

Les transactions annulées ne déclenchent pas de demande. Plusieurs demandes
peuvent être regroupées dans un même scan. Une demande arrivée pendant un scan
est conservée pour un passage suivant. Les commandes utilisant update_all ou
update_columns contournent les callbacks ; le passage périodique les couvre.

Le lecteur /videos doit être monté à cet emplacement avec l'UUID
3430606f-92bb-4da4-aaf2-36a3460bc298. Les contrôles du montage entourent le scan
et la production du rapport. Un répertoire inaccessible ou un montage incorrect
interrompt le passage : le dernier journal valide est conservé. Une erreur
apparaît dans journalctl ; le passage périodique réessaie ensuite.

Les fichiers non confirmés modifiés depuis moins de 24 heures restent en
attente de stabilité, même si leur titre correspond à une fiche unique.
Les fichiers des espaces de travail de video_encoder restent exclus du calcul.
Les projets JSON sans copie finale ne prouvent aucune disponibilité.
La période de 24 heures est une précaution, pas une preuve que l'encodage est
terminé : l'import contrôlé vérifie à nouveau le fichier avant toute écriture.

Le suivi ne crée ni copie ni fiche et ne modifie aucun état de disponibilité.
La disparition d'un fichier reste une alerte, pas une suppression automatique.
Une nouvelle consultation de la page d'accueil lit le bilan actualisé ; une
page laissée ouverte n'est pas rafraîchie automatiquement.

## Installation sur Zeus

Après bin/check, commit, push et déploiement de cette version :

```bash
cd /home/pascal/code/Fofo92/vidb-clean
bash bin/install-reconciliation-refresh
systemctl list-timers vidb-reconciliation-refresh.timer
```

Les trois unités sont copiées dans /etc/systemd/system. Cette installation
n'est nécessaire qu'une fois, puis lors d'une modification des unités.
Elles exécutent toujours la release courante de vidb.

```bash
sudo journalctl -u vidb-reconciliation-refresh.service -n 50 --no-pager
sudo systemctl start vidb-reconciliation-refresh.service
```

Le journal et ses archives restent dans /srv/vidb/shared/reconciliation-followup.
Les 32 derniers rapports et bilans automatiques sont conservés dans
le sous-dossier automatic-history, soit environ huit heures de scans périodiques.
Le journal courant conserve les premières observations. Les archives historiques
créées par les commandes manuelles restent intactes à la racine du dossier.
Les demandes sont désactivées hors production, sauf si
VIDB_RECONCILIATION_REFRESH_REQUEST indique explicitement un fichier.
En production, conserver le chemin par défaut utilisé par l'unité path.

Le scan ne lance ni ffprobe ni appel TMDB et ne parcourt pas /commun.
Il ne remplace pas les rapports de comparaison ou de qualification spécialisés.
