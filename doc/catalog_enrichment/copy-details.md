# Supports et versions linguistiques des copies

Le support et la version linguistique appartiennent à chaque VideoAsset.
Ils sont optionnels : les anciennes copies restent sans qualification jusqu'à confirmation.
Les associations historiques Record.media et Record.language_version restent conservées.
Une VF héritée de la fiche ne devient pas automatiquement une VF confirmée pour sa copie.

Le relevé technique conserve les pistes, leurs métadonnées, la durée précise,
le montage et l'UUID du système de fichiers. L'UUID identifie un volume, pas
nécessairement un disque physique ; /dev/sdc1 reste une observation ponctuelle.
Les langues déclarées dans les fichiers restent distinctes de VF/VO/VM/VOST/VMST.
Une langue und ne permet aucune déduction de version linguistique.

Le pilote Europe confirme HD et VF avec la provenance Pascal, le 7 octobre 2026.
L'observation technique est renouvelée lors de chaque exécution.
Le contrôle vérifie les identifiants de copie et de fiche, le chemin, la taille,
le statut présent et l'UUID attendu. Les six modifications sont transactionnelles.
Ce contrôle n'est pas une comparaison cryptographique du contenu des fichiers.
Une erreur ou une qualification contradictoire bloque tout le lot ; aucun fichier
n'est déplacé et aucune copie n'est déclarée supprimée par cet outil.

Après migration :

```sh
bundle exec ruby bin/rails runner script/complete_confirmed_copy_details.rb doc/catalog_enrichment/europe-confirmed-copy-details.json
```

Ajouter --apply pour enregistrer le lot. En production utiliser le contexte systemd
habituel (vidb, EnvironmentFile, BUNDLE_PATH). Les pistes restent consultables
dans le détail de la copie ; les épisodes sans qualification restent explicitement inconnus.
