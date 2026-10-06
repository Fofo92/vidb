# Premier lot strict hors Europe — 7 octobre 2026

61 candidats : 27 correspondances de titre exact et 34 épisodes avec contexte,
numérotation et titre concordants. Les fiches sont déjà qualifiées comme vidéos
autonomes ou épisodes. Les six copies Europe sont exclues de ce lot.

Les fichiers concurrents d'une même fiche, les espaces de travail et huit fichiers
modifiés dans les dernières 24 heures ont été exclus. Ce délai ne prouve pas
qu'un encodage est terminé : les fichiers sont également contrôlés avant import.

Le manifeste contient les chemins, tailles, dates et identités candidates issus
du rapport de production. L'import refait le rapprochement contre le catalogue
actuel ; un nouveau homonyme ou une hiérarchie différente bloque le lot.
Les fiches et leurs ancêtres sont verrouillés pendant la transaction.

Chaque fichier doit être régulier, conserver sa taille et sa date observées, et
appartenir au volume UUID attendu. ffprobe relève à nouveau durée et pistes.
Les identités techniques sont contrôlées pendant l'observation et juste avant
les écritures. Ce contrôle n'est pas une empreinte cryptographique et ne constitue
pas un verrou empêchant un autre processus de modifier un fichier ensuite.

HD est rattaché aux copies du volume /videos déjà identifié. Aucune VF, VO ou
autre version linguistique n'est déduite automatiquement. Les qualifications
existantes et les confirmations antérieures sont conservées.

Le lot est atomique et peut être relancé sans créer de doublons pour les mêmes
fiches et chemins. Une copie présente concurrente bloque tout le lot. Une copie
supprimée conserve son historique ; un nouveau fichier au même chemin constitue
une nouvelle copie. Aucune absence n'est interprétée comme une suppression.

Les marqueurs enregistré/disponible des vidéos suivent les callbacks VideoAsset
existants. Les autres données éditoriales, les états vu/vérifié et les hiérarchies
ne sont pas modifiés. La file durable de rapprochement reste un chantier séparé.

```sh
bundle exec ruby bin/rails runner script/import_video_asset_batch.rb doc/catalog_enrichment/strict-batch-2026-10-07.json
```

L'aperçu sans écriture est enregistré dans tmp/video-asset-batch-preview.json.
Ajouter --apply pour importer, après contrôles et déploiement. Le compte rendu
est alors enregistré dans tmp/video-asset-batch-applied.json. En production,
utiliser le contexte systemd habituel ; les aperçus et comptes rendus sont
remplacés à chaque exécution et doivent être copiés si leur historique est utile.
