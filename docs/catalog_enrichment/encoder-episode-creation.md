# Préparer un épisode avant encodage

L’identification examine les noms des sources et la destination pour détecter
`Sxx Exx`. Un épisode sans correspondance ouvre le formulaire dédié. Les anciens
liens vers le catalogue de films sont redirigés vers ce formulaire.

Le formulaire cherche une série locale qualifiée et consulte les sources
extérieures pour proposer les informations disponibles. Si la série est absente,
des propositions permettent de confirmer sa création et celle de son catalogue.
Une série existante peut aussi être complétée avec ses saisons et ses épisodes.
Les résultats et les champs manquants restent modifiables avant confirmation.

Les rangs ambigus et les identités ou découpages contradictoires demandent un
examen ; ils ne justifient pas de déplacer automatiquement une fiche existante.
Les états et métadonnées déjà renseignés sont préservés selon les règles de
préremplissage. Un épisode créé sans copie est non vu, non enregistré et
indisponible ; sa version reste IND tant qu’elle n’est pas qualifiée.

La confirmation prépare la fiche et associe le montage au moyen d’un lien signé.
Elle ne crée pas de copie physique et n’invente ni support ni durée mesurée.
Après validation, le parcours video_encoder reprend la destination, le contrôle
audio et, si demandé, la mise en file. La copie est importée après l’export réussi.

Pour les règles détaillées : [préremplissage](encoder-episode-enrichment.md),
[série absente](missing-series-preparation.md),
[série existante](existing-series-completion.md) et
[découpages d’épisodes](episode-edition-mapping.md).
