# Pilote d'intégration des encodages : 9-1-1

Ce premier passage consulte TMDB automatiquement avec le jeton déjà configuré
et prépare les correspondances entre fichiers, épisodes et fiches. Il ne crée
aucune fiche, aucun lien externe ni copie. Aucun fichier vidéo n'est modifié.

La fiche locale sélectionnée est 7335 ; l'identité externe sélectionnée est
TMDB 75219. Le programme vérifie en direct le titre, la nature et la position
de la fiche ainsi que le titre original retourné par l'API.
Il reste strictement dans le dossier 9-1-1 ; Lone Star est hors périmètre.

Un numéro seul ne suffit pas. Un titre français ou original doit correspondre
à un épisode unique de TMDB, dont saison et numéro correspondent au fichier.
Les contradictions, titres absents et identités ambiguës restent dans le rapport.
Les copies multiples d'un même numéro sont signalées séparément et ne produisent
pas automatiquement de correspondance unique.

Un fichier modifié depuis moins de 24 heures attend sa stabilité. Les fichiers
de travail de video_encoder sont exclus. Un JSON sans MKV final est compté
comme projet sans copie, jamais comme épisode disponible.
Ce passage n'affirme pas qu'un fichier stable a terminé son export : cette preuve
sera contrôlée lors de l'import des copies et de la connexion avec l'encodeur.

Les données sont conservées dans un nouveau sous-dossier run-* à chaque lancement :
snapshot.json, inventory.json, mapping.json, hierarchy-plan.json et pilot-report.json.
Le cache TMDB reste à l'extérieur des releases ; ce premier passage le renouvelle.
Les dates de première diffusion et durées externes restent des références :
elles ne deviennent ni années de production ni durées mesurées.

## Exécution

```text
bin/rails runner script/prepare_encoding_series_pilot.rb \
  doc/catalog_enrichment/nine-one-one-encoding-pilot.json \
  /srv/vidb/shared/encoding-pilots/9-1-1
```

Utiliser l'utilisateur vidb et l'environnement de production comme pour les
autres runners, afin de bénéficier du jeton TMDB et du catalogue réel.

## Étapes suivantes

1. Examiner le bilan initial et appliquer les correspondances sûres avec
   TmdbHierarchyApplication, le mécanisme transactionnel existant.
2. Observer les copies finales et importer leurs caractéristiques et langues.
3. Relier les exports réussis de video_encoder à une file durable et idempotente.
4. Activer la consultation externe périodique ciblée, avec expiration du cache,
   puis les écritures automatiques seulement pour les identités déjà établies.

Le présent patch automatise la consultation et la préparation d'un passage.
Il n'active pas encore de traitement périodique ni d'import automatique.
