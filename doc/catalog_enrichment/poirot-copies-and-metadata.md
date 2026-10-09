# Poirot : copies mesurées, pays et genre principal

Le lot `poirot-confirmed-completion.json` identifie les 70 fichiers issus de l’inventaire après rangement, leurs tailles, dates et correspondances TMDB. Les identifiants externes sont maintenant reliés à des fiches en base : le rattachement se fait par cette correspondance confirmée et non par une comparaison approximative des noms de fichiers.

Le pays retenu est le pays d’origine GB (Royaume-Uni), distinct de la liste TMDB des partenaires de production GB/US. Le genre majeur est Policier, choisi à partir de Crime. Drame et Mystère ne sont pas ajoutés. Les dictionnaires doivent contenir une seule entrée correspondante ; aucune entrée n’est créée automatiquement. Une attribution existante contradictoire bloque le lot au lieu d’être écrasée.

Les pays et le genre sont attribués à la série, ses saisons et ses épisodes dans une transaction commune avec les copies. Les années, dates de visionnage, vérifications et résumés sont conservés.

Les fichiers sont fraîchement observés par ffprobe et findmnt. Le support disque HD et l’UUID du volume sont vérifiés. La taille et la date doivent toujours correspondre à l’inventaire ; toute variation bloque le lot. Les fichiers récents sont refusés. L’identité est contrôlée une dernière fois avant importation.

Les durées réelles sont enregistrées sur les copies et deviennent prioritaires dans les vues existantes. La durée historique du catalogue reste une référence de contrôle et n’est pas remplacée. La mesure en secondes est conservée pour la provenance. Les langues restent non qualifiées si aucune qualification de copie n’existe déjà ; aucune VF n’est déduite de l’origine britannique ou d’une absence de sous-titres.

Une copie présente déclenche les règles habituelles enregistré/disponible sur son épisode ; les états des parents restent une synthèse des feuilles. Une nouvelle copie n’affecte pas les états vu ou fiche vérifiée.

Le script fonctionne par défaut en prévisualisation. Ajouter `--apply` après sauvegarde PostgreSQL pour écrire. Tous les changements de métadonnées et copies sont annulés si une validation tardive échoue. Une réexécution réutilise la même copie ; une copie existante à un autre chemin ou un support différent nécessite un examen séparé.

```sh
bin/rails runner script/complete_linked_episode_assets.rb \
  doc/catalog_enrichment/poirot-confirmed-completion.json \
  /srv/vidb/shared/tmdb-series-790-snapshot.json \
  /srv/vidb/shared/poirot-completion-preview.json
```

Résultat attendu : 70 copies proposées et 84 fiches pour le pays/genre. Le nom du dossier série, les extensions et les titres dans les noms de fichiers restent inchangés. L’origine et les pistes des copies relèvent de contrôles distincts.
