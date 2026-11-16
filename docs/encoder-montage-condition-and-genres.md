# Préparation des montages et import des copies

## Genres d’une vidéo autonome

Le formulaire de complément affiche les genres déjà effectifs sur la fiche.
Les suggestions externes ne remplacent pas la sélection enregistrée.
La case « Modifier les genres » active la sélection et autorise explicitement
sa correction, y compris pour une sélection protégée précédemment validée.
Sans cette case, le serveur conserve les genres existants, même si une requête
transmet d’autres valeurs. Le maximum reste de deux genres.

## État du montage terminé

Le reçu video_encoder peut contenir `copy_condition`, une déclaration manuelle
de complétude, détérioration, portion conservée et note. `ExportCondition`
valide cette déclaration et la transforme en `VideoAsset.condition_details`
avec sa provenance et les sources signalées. L’import intervient seulement
après les vérifications existantes du fichier et du reçu.

La déclaration concerne uniquement la copie nouvellement créée. Elle ne modifie
ni les autres copies ni leur qualification manuelle. Les déplacements de copies
existantes conservent leurs conditions déjà enregistrées. Une déclaration invalide
bloque l’import et fait annuler sa transaction ; elle ne devient jamais une copie
déclarée complète par défaut. Les anciens reçus sans déclaration restent compatibles.

Aucune migration n’est nécessaire : le correctif utilise `condition_details`
et les associations de genres existantes.
