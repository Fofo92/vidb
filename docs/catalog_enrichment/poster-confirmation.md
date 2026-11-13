# Pochettes de films : corroboration et confirmation

La récupération automatique conserve la comparaison d’identité stricte du catalogue.
Une corroboration supplémentaire est réservée au choix de pochette : titre distinctif
normalisé, année exacte, au moins quatre termes significatifs communs et recouvrement
lexical d’au moins 15 %. Un titre long d’au moins cinq termes distinctifs tolère une
variation chronologique d’un an. Un titre original local distinct ne doit pas être
contradictoire. Les nombres simples écrits en lettres, en chiffres et les chapitres
en chiffres romains sont normalisés pour cette recherche seulement.

La recherche doit rester complète et l’ensemble des références étayées doit être
unique. Les règles générales de `CatalogEnrichment::FilmIdentityComparison` ne sont
pas modifiées. Le cache de recherche des pochettes expire après six heures, au lieu
de conserver indéfiniment une ancienne réponse. Aucune année, aucun synopsis et aucun état de visionnage ne sont
changés pour faciliter une récupération.

Si la récupération automatique échoue, la page de comparaison montre la fiche locale
et jusqu’à douze propositions avec titre, date et présentation. Elle explique aussi
les recherches partielles, l’absence de synopsis et les références multiples.
Un lien TMDB de film peut être fourni directement, notamment lorsque le film est
absent des résultats. Une prévisualisation précède toujours la confirmation manuelle.

La confirmation est signée, limitée à quinze minutes et liée à la fiche ainsi qu’à
l’état de sa pochette. Une modification entre prévisualisation et confirmation
invalide le choix. Le téléchargement se fait avant le verrouillage ; la fiche et
la pochette sont revérifiées sous verrou avant l’enregistrement. Une pochette
existante n’est pas remplacée de force. La référence confirmée est conservée dans
la provenance de la pochette, sans mutation des métadonnées de la fiche.

Tests ciblés :

```sh
bin/rails test test/services/record_posters/film_poster_comparison_test.rb \
  test/services/record_posters/film_review_test.rb \
  test/services/record_posters/film_confirmation_test.rb \
  test/services/record_posters/film_target_test.rb \
  test/controllers/record_posters_controller_test.rb
```

Exécuter ensuite `bin/check` avant déploiement.
