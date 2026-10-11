# Rattachement des exports video_encoder

Après un export réussi depuis un projet enregistré, video_encoder écrit un compte
rendu `<chemin final>.video_encoder-export.json` à côté de la vidéo. Le chemin réel,
la taille, la date de modification, les pistes finales sondées par ffprobe, les
rôles audio sélectionnés et l'empreinte du projet sont conservés. Le projet peut
ensuite être archivé ; le compte rendu suffit au suivi.

Le suivi périodique de production importe ces exports sans attendre 24 heures :
le compte rendu atteste la fin de l'export et ffprobe contrôle à nouveau la copie.
L'identification doit désigner un seul épisode déjà qualifié, au même rang, dans
une saison et une série identifiées, avec titre concordant. Aucun rapprochement
par homonymie globale, aucune création automatique de fiche dans cette étape.

La copie reçoit le support HD (disque dur), la durée réelle et la version de
langue déterminée par les pistes finales et les rôles video_encoder. Une langue
non déterminable reste à qualifier. Seule la durée manquante de la fiche est
complétée ; ses titres, années, résumés et états vu sont conservés. Pays et genres
continuent d'être hérités selon les règles existantes. L'enrichissement TMDB et
la création des épisodes absents sont des étapes distinctes.

Les anciennes copies restent présentes ; un nouvel export est une autre copie.
Une réexécution n'ajoute aucun doublon. Un chemin déjà enregistré avec un autre
compte rendu reste à examiner, sans écrasement de son historique.

Résultats : `/srv/vidb/shared/reconciliation-followup/encoder-exports.json`.
Les erreurs et cas ambigus sont conservés avec `needs_review` et leur motif.

Pour les exports antérieurs, comme 9-1-1 S05 E01 et E02, ne pas fabriquer un
compte rendu de réussite. Collecter d'abord les projets et les pistes actuelles
pour préparer leur adoption contrôlée. Les anciens fichiers `_vf` restent distincts.

Déployer vidb et mettre à jour video_encoder. Les unités systemd existantes
utilisent la release courante ; aucune nouvelle unité ni migration nécessaire.
