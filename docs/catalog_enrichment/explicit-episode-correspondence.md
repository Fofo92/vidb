# Correspondance explicite avec un épisode TMDB

Le champ d’URL accepte une série ou un épisode TMDB. Une URL de série conserve
la recherche avec les numéros locaux. Une URL d’épisode consulte directement
la fiche externe ; par exemple, vidb S12 E11 peut correspondre à TMDB S14 E02.

La proposition affiche les deux numérotations, la série TMDB et le lien de
l’épisode. Une case non cochée par défaut demande confirmation de l’identité.
Cette confirmation est aussi vérifiée côté serveur avant toute écriture.
Les coordonnées externes et l’identité de l’épisode viennent de la proposition
signée ; elles ne sont pas reprises de champs cachés modifiables.

Seule la fiche locale choisie est enrichie. Ses rangs et ceux de sa saison ne
changent pas. Aucune correspondance globale n’est déduite : la complétion de
toutes les saisons est désactivée pour cette proposition. Pour une nouvelle
série, seuls la série, la saison locale et cet épisode sont préparés.

La correspondance confirmée est conservée dans CatalogueEpisodeLink avec
une preuve explicit_episode_mapping et le lien consulté. Les recherches suivantes
réutilisent les coordonnées externes pour cet épisode local uniquement et
contrôlent son identité TMDB. Un lien existant différent n’est pas écrasé ; les
contraintes habituelles empêchent de lier un épisode externe à deux fiches.
L’écriture du lien reste dans la transaction de préparation et d’association.

Lorsqu’une requête réussit sans trouver l’épisode, un avertissement indique les
numéros demandés et invite à saisir une URL d’épisode. Wikipédia reste proposée.
Une indisponibilité du fournisseur conserve son avertissement habituel.

Les requêtes passent par le client TMDB authentifié et son cache, jamais par
un téléchargement de l’URL saisie. Les identifiants et coordonnées renvoyés
par TMDB sont contrôlés avant proposition.
