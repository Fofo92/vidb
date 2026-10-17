# Propositions documentées de classement

`CatalogEnrichment::ReviewedClassificationProposal` prépare une proposition sans écriture.
La catégorie de rangement distingue les films et les documentaires ; `record_kind`
continue de décrire la structure de la fiche, par exemple une vidéo autonome.
Le support HD reste un support physique, sans rôle dans cette distinction.

Les films conservent `VideoAssets::RelocationPathBuilder` : un ou deux genres,
tri alphabétique, titre français, titre original éventuel, année et préfixe vu.
Une proposition documentaire requiert le genre Documentaire et choisit directement
la branche `/videos/Documentaires`, avec la même convention de nom de fichier.
Elle ne produit jamais `/videos/Films/Documentaire`.

La justification et au moins une source HTTPS sont obligatoires. Ces liens
constituent la trace d'une recherche déjà faite ; le composant ne vérifie pas
l'identité d'un film ni le contenu de la source et ne fait aucun appel réseau.
L'appelant doit avoir vérifié l'identité, la pertinence des sources et leur date.

Les genres proposés sont comparés au référentiel fourni. Une référence absente
donne `missing_genre_reference` ; ce statut ne signifie ni modification manuelle
de la fiche, ni besoin d'arbitrage éditorial. Aucun genre n'est créé implicitement.
Les changements de métadonnées et les préconditions de destination sont rapportés
séparément par l'orchestrateur.

La proposition n'autorise jamais un déplacement. Avant toute application, il reste
à protéger durablement la provenance des genres et les corrections manuelles,
à contrôler à nouveau les métadonnées sous verrou, puis à utiliser un exécuteur
entre répertoires sur le même volume avec refus atomique d'écrasement et journal.
L'extension d'exécution n'est pas livrée par ce composant.

Les règles s'appliquent aux futurs enrichissements aussi bien qu'à l'assainissement.
Une recherche documentaire complémentaire est distincte d'une décision manuelle :
seuls les choix encore réellement ambigus après recherche demandent un arbitrage.
