# Catalogue complet et possession physique des DVD

Depuis une proposition TMDB de série dans Scanner un DVD, choisir
« Compléter toute la série et inventorier ce coffret ». Pour une édition déjà
associée, choisir « Compléter le catalogue de cette série » et confirmer la
proposition correspondant à la fiche existante.

Le service réutilise TmdbSeriesSnapshot, SeriesCreation et
SeriesCatalogueCompletion pour créer les saisons, y compris les spéciaux, et
les épisodes documentés par TMDB. Les titres originaux, dates et résumés des
épisodes utilisent le parcours existant. Les résumés absents de la série et des
saisons sont également complétés. Les résumés édités manuellement et les genres
ou pays déjà renseignés sont conservés. Les conflits de placement ou d'identité
annulent la transaction. Une relance ne doit pas dupliquer le catalogue.

La présence au catalogue ne vaut pas possession : DvdContent relie uniquement
les œuvres cochées à l'édition EAN. Une œuvre peut appartenir à plusieurs éditions.
La version linguistique, les langues audio et les sous-titres appartiennent à
chaque lien. Ces informations sont renseignées après vérification de la pochette
ou du disque ; TMDB ne permet pas de déduire les pistes d'une édition précise.
Décocher une œuvre retire seulement son lien à ce coffret.

Les possessions physiques apparaissent sur les fiches dans « DVD possédés ».
Elles ne créent pas de VideoAsset, ne modifient pas les états des fichiers vidéo
et ne remplacent pas les versions des copies numériques existantes.

## Vérification sur Zeus

Après migration, exécuter bin/check. Les tests dvd_series_import_test.rb
couvrent le catalogue neutre, les résumés, la possession partielle,
l'idempotence, le refus d'un épisode hors série et le retrait limité à une édition.

Avec le coffret Code Quantum saison 2, compléter la série, vérifier le catalogue,
cocher les seuls épisodes de cette édition et renseigner les langues connues.
Rescanner l'EAN pour retrouver la sélection ; les autres épisodes doivent rester
sans possession DVD. Vérifier également qu'une copie numérique existante reste
inchangée.
