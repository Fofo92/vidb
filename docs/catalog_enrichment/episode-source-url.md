# URL explicite de série TMDB

La préparation d’un épisode accepte une URL de série ou d’épisode TMDB facultative.
L’identifiant extrait remplace la recherche TMDB par titre et les associations
existantes pour cette consultation. Wikipédia reste consultée normalement.
Une URL de série utilise la saison et l’épisode du formulaire. Une URL d’épisode
consulte ses coordonnées externes et demande une confirmation de correspondance ;
les numéros locaux restent ceux du formulaire. Voir explicit-episode-correspondence.md.

Pour une série locale, les propositions restent associées à cette série.
Pour une série absente, le parcours existant de proposition de création est utilisé.
L’URL est conservée lors du choix d’une série locale. Une URL invalide affiche
un avertissement sans recherche de remplacement. Seul l’identifiant est transmis
au client TMDB habituel ; aucune requête n’est faite vers l’URL saisie.

La consultation ne crée aucune fiche : la confirmation habituelle reste requise.
Une URL directe ne garantit pas que TMDB possède l’épisode demandé ni que sa
numérotation correspond à l’édition locale.
