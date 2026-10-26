# Compléter une série déjà présente

La préparation d’un épisode propose aussi de compléter toutes les saisons et tous les épisodes documentés d’une série existante. L’option est cochée par défaut lorsqu’une proposition TMDB identifie le catalogue. Une proposition Wikipédia concordante bénéficie de la même option ; des titres, années ou identités contradictoires ne sont pas fusionnés.

La consultation ne modifie pas la base. La confirmation actualise les données externes avant la transaction, puis réutilise la série, les saisons et les épisodes existants. Les états et les métadonnées déjà renseignées restent conservés par la complétion. Les corrections explicites du formulaire de l’épisode suivent les règles habituelles de préparation.

Les nouveaux épisodes sont non enregistrés, non disponibles et non visionnés, avec une version IND. Aucun support physique, durée mesurée ou fichier n’est inventé. Les pays et genres renseignés sur la série sont hérités. Les durées de référence restent dans les liens catalogue.

Un désaccord de placement, de titre ou de lien TMDB annule toute la confirmation. Changer la série sélectionnée exige une nouvelle proposition. Une nouvelle confirmation du même catalogue réutilise les fiches ; elle ne crée pas de doublons.

Pour reprendre Esprits criminels, ouvrir la préparation de l’épisode déjà associé depuis video_encoder, consulter les sources, garder l’option « Compléter toutes les saisons et tous les épisodes documentés de cette série », puis confirmer. La fiche et l’association existantes sont réutilisées. Ne pas remettre un montage déjà en file une seconde fois.

L’option peut être décochée pour préparer seulement l’épisode demandé et éviter de consulter de nouveau toutes les saisons. Si aucune identité de catalogue exploitable n’est disponible, aucune complétion globale n’est annoncée.

Ce complément nécessite les lots précédents sur les titres originaux et la création des séries complètes. Il ne comporte ni migration ni modification de video_encoder. Déployer vidb après validation de `bin/check` et rouvrir la préparation pour obtenir une nouvelle proposition signée.
