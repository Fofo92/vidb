# Corroboration des genres déjà présents

La limite de deux genres porte sur la sélection locale. Une source peut en
lister davantage sans invalider automatiquement cette sélection. Lorsque
chacun des un ou deux genres déjà présents est positivement corroboré, vidb
peut les conserver : il n’importe pas les autres genres et ne tronque aucune
liste externe pour fabriquer un classement.

ExistingGenreConcordance est une décision pure réutilisable par un job ou une
interface. La collecte conserve l’état local, les genres externes, leur source,
les genres non retenus et les réserves documentées. Un identifiant TMDB provient
de l’identité déjà qualifiée et non d’une nouvelle recherche approximative.

Les réserves spécifiques (biographie, espionnage, documentaire, source primaire
contradictoire) priment sur les étiquettes génériques concordantes. Les codes
inconnus ne prouvent jamais un genre local manquant. Téléfilm décrit un support,
et n’invalide pas à lui seul un genre Drame ou Policier positivement établi.
Une indication documentaire entraîne un examen de catégorie distinct.

Ce composant ne sauvegarde aucun Record ou VideoAsset et ne renomme aucun
fichier. Les corrections proposées restent distinctes de la corroboration des
choix existants. La future application devra protéger les décisions manuelles
et enregistrer leur provenance ; une nouvelle source ne peut les remplacer
automatiquement. La file de décisions dans l’interface reste à construire.

Le premier manifeste couvre les 50 copies restées après les 97 renommages. Les
services et tests vivent dans Git ; collecte et preuves sont conservées sous
Rails.root/tmp/genre-evidence. Les fichiers de transfert sous /tmp sont jetables.

Le statut needs_review signifie recherche ou examen complémentaire ; il ne
constitue pas une demande automatique d’arbitrage humain. Les propositions
étayées, les recherches incomplètes et les désaccords réellement indécidables
devront être distingués dans l’orchestrateur et la future file d’interface.
Seuls ces derniers demandent une décision de l’utilisateur.
