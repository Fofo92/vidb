# URL explicite de série TMDB

La préparation d’un épisode accepte une URL de série TMDB facultative.
L’identifiant extrait remplace la recherche TMDB par titre et les associations
existantes pour cette consultation. Wikipédia reste consultée normalement.
La saison et l’épisode restent ceux du formulaire ; une URL d’épisode est refusée
pour éviter un conflit entre deux numérotations.

Pour une série locale, les propositions restent associées à cette série.
Pour une série absente, le parcours existant de proposition de création est utilisé.
L’URL est conservée lors du choix d’une série locale. Une URL invalide affiche
un avertissement sans recherche de remplacement. Seul l’identifiant est transmis
au client TMDB habituel ; aucune requête n’est faite vers l’URL saisie.

La consultation ne crée aucune fiche : la confirmation habituelle reste requise.
Une URL directe ne garantit pas que TMDB possède l’épisode demandé ni que sa
numérotation correspond à l’édition locale.
