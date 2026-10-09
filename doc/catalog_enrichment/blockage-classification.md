# Classification des motifs de blocage

Le rapport est produit depuis le journal durable actuel, sans modification de la
base ou des fichiers. Les compteurs représentent des fichiers, pas un nombre de
fiches à saisir ni un nombre d'interventions humaines.

Les groupes associent une catégorie et un répertoire. Les dossiers Saison XX
sont regroupés au niveau de leur série. Les autres fichiers sont regroupés par
leur dossier parent : ce regroupement est une aide de navigation, pas une preuve
d'identité. Chaque groupe contient tous les chemins, jusqu'à trois exemples et
les identifiants des fiches candidates.

Les fichiers de corbeille et les espaces de travail video_encoder sont classés
hors périmètre. Ils restent dans le journal et le total brut, mais ne représentent
pas des copies finales à importer. Une copie confirmée prime sur un conflit de
titre du rapprochement historique.

Les fiches reconnues sans enfants, les fiches placées sous un autre parent et
les types de fiches incompatibles ont des catégories distinctes. Les saisons
et épisodes manquants peuvent souvent être traités par comparaison extérieure
et lots contrôlés. Une proposition unique n'autorise pas son application.
Les conflits de titres et numéros demandent des preuves complémentaires, parfois
une vérification humaine. Aucun compteur ne prétend mesurer automatiquement le
nombre final d'interventions nécessaires.

```sh
bin/rails runner script/classify_reconciliation_blockages.rb FOLLOWUP.json OUTPUT.json
```

Pour la production, lire `/srv/vidb/shared/reconciliation-followup/current.json`
et écrire `/srv/vidb/shared/reconciliation-blockages.json`. Regénérer ce rapport
après chaque actualisation du journal. Les absences du dernier scan restent un
avertissement distinct : elles ne prouvent pas une suppression.
