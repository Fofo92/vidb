# Documentation de l’enrichissement du catalogue

## Parcours courants

- [Identifier un projet video_encoder](encoder-project-identification.md)
- [Préparer un épisode](encoder-episode-creation.md) et
  [compléter ses métadonnées](encoder-episode-enrichment.md)
- [Créer une série absente](missing-series-preparation.md) ou
  [compléter une série existante](existing-series-completion.md)
- [Faire correspondre les découpages d’épisodes](episode-edition-mapping.md)
- [Choisir les résumés](synopsis-preference.md) et les
  [genres policiers](catalogue-police-genres.md)
- [Séries et saisons](container-metadata.md) ; [collections de films](film-collections.md)
- [Suivre la réconciliation](reconciliation-followup.md) et
  [examiner les propositions](consolidation-review.md)
- [Importer les exports terminés](video-encoder-completed-exports.md) ; [pochettes](posters.md)

## Documents et données

La base vidb fait référence pour les fiches, les copies et les correspondances externes. Les documents de ce dossier expliquent les mécanismes et les décisions utiles. Les descriptions de pilotes sont historiques ; leurs anciens plans ne doivent pas être rejoués.

Les seules configurations réutilisables versionnées sont dans data/catalog_enrichment. Les instantanés, aperçus et résultats intermédiaires vont dans tmp/ ou /tmp, puis sont supprimés après vérification du résultat.

Un JSON n’est conservé durablement que s’il apporte une information utile absente de la base, ou une configuration encore employée. Documenter son rôle et les conditions de son retrait. Le déplacement dans un dossier d’archives ne justifie pas sa conservation.

Le nettoyage du 11 octobre 2026 retire les dix manifestes dont les résultats ont été contrôlés en production et l’ancien lanceur Europe lié à un répertoire d’audit particulier. Il ne modifie ni la base ni les vidéos ni les sauvegardes PostgreSQL.

Les journaux automatiques actifs de /srv/vidb/shared sont des données de fonctionnement ; ils ne font pas partie de ce nettoyage.
