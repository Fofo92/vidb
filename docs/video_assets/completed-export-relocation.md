# Suivi des exports déplacés ou renommés

Le scan automatique utilise le reçu `.video_encoder-export.json` mis à jour par
video_encoder. Après les contrôles habituels du fichier final et de la fiche,
un reçu portant `previous_output_path` peut actualiser une copie déjà inscrite.
La ligne VideoAsset conserve son identifiant, son support, sa langue, sa durée,
ses annotations techniques et son historique. Les métadonnées de la fiche et son
état de visionnage ne sont pas modifiés. Le statut de la copie redevient `present`
et les indicateurs de disponibilité de sa fiche sont recalculés normalement.

Le rapprochement exige une ancienne copie unique, la même fiche, la même taille
et les mêmes informations d’export, sauf les chemins déplacés. L’empreinte du
projet peut changer lors de la normalisation des références sources si son
identité `project_id` est conservée ; sans identité, l’empreinte doit rester
identique. Les autres preuves du reçu restent comparées, dont date d’export,
date de fichier, pistes et durée lorsqu’elles sont présentes.

L’ancien chemin doit avoir disparu. Un fichier ou même un lien symbolique encore
présent est traité comme une seconde copie : l’import normal crée sa propre
ligne, sans déplacer la première. Une erreur de lecture n’est pas assimilée à
une absence. Une ancienne copie supprimée, un reçu divergent ou plusieurs copies
possibles conduisent au résultat `needs_review` du scan, sans fusion automatique.

Plusieurs renommages avant le prochain scan sont pris en compte en recherchant
une copie unique de la même fiche portant les mêmes preuves d’export. Chaque
déplacement reconnu ajoute un événement `relocation_history` avec les chemins,
l’ancien statut et le reçu précédent. Le reçu courant et le chemin du projet
sont conservés dans `video_encoder_export`. Une nouvelle lecture du même reçu
est idempotente et ne rajoute pas d’événement.

Ce traitement est intégré à CompletedExportImport, dans sa transaction et sous
son verrou existant ; il ne nécessite pas de nouveau timer ou de migration.
Il ne déplace aucun fichier et ne fusionne pas les doublons déjà enregistrés.
Les vidéos sans reçu ne sont pas reconnues comme déplacées par cette voie.
