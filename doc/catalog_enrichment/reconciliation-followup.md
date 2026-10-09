# Suivi durable des rapprochements — première étape

Le journal conserve l'état du dernier rapprochement dans un répertoire partagé
entre les releases. Chaque rapport source est archivé par son empreinte SHA-256.
Relancer le même rapport actualise les confirmations à partir des copies présentes
en base, sans créer ni modifier de VideoAsset ou Record.

## États

- `confirmed` : copie présente en base, taille identique et observation technique
  au moins aussi récente que la modification déclarée dans l'inventaire.
- `confirmed_copy_changed` : copie connue dont la taille ou la date demande
  une nouvelle observation technique.
- `candidate` : proposition unique du rapprochement, à traiter par un lot contrôlé.
- `needs_review` : rapprochement ambigu, absent ou bloqué.

`new_paths` indique les nouveaux chemins ; `absent_since_previous` signale les
chemins absents par rapport au scan précédent. Une absence ne déclare jamais une
copie supprimée. Un déplacement apparaît comme un nouveau chemin et une absence ;
aucun rapprochement de déplacement n'est déduit de la taille seule.

Le rapprochement reste fondé sur un inventaire historique, sans contrôle disque
actuel. Il ne prouve pas qu'un encodage est terminé : les lots d'import conservent
leurs vérifications de stabilité, de taille et de date avant application.

## Utilisation

Générer d'abord un rapport avec `script/video_asset_reconciliation.rb`, puis :

```sh
bin/rails runner script/update_reconciliation_followup.rb REPORT.json DIRECTORY
```

En production, utiliser `/srv/vidb/shared/reconciliation-followup` comme DIRECTORY,
avec l'utilisateur vidb et les variables du service. Le journal est `current.json`.
Le premier passage crée une base de comparaison : tous les chemins sont nouveaux.
Les scans suivants doivent avoir exactement les mêmes racines. Les inventaires
antérieurs au dernier scan sont refusés. Un verrou empêche les écritures simultanées
et le journal est remplacé atomiquement.

## Suite de la feuille de route

Ajouter une file en base pour les décisions humaines, motifs d'exclusion et reprises
après déplacement ; présenter les groupes par série dans une vue ; relier les lots
appliqués et leurs preuves ; intégrer les nouveaux exports stabilisés ; automatiser
les scans et le suivi une fois le comportement vérifié. Cette première étape ne
déclenche aucune correction automatique ni tâche planifiée.
