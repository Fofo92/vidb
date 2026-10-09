# Titres locaux et sélection du premier lot 9-1-1

Pascal confirme que les titres des épisodes S08 E01, E02, E03, E14 et E15
doivent être présentés sans les suffixes narratifs (1), (2) ou (3).
La configuration du pilote fixe ces cinq décisions par identifiant TMDB.
Les titres complets de TMDB et l'identifiant sont conservés dans la preuve du lien.
Une modification ultérieure des titres externes suspend cette décision pour revue.

Les titres français et originaux locaux peuvent ainsi différer des titres
externes complets, sans modifier l'identité ou la numérotation de l'épisode.
Les fiches nouvelles reçoivent les titres locaux. Le moteur existant ne
réécrit pas automatiquement les titres de fiches déjà présentes.

Le script prepare_selected_tmdb_hierarchy.rb repart de mapping.json et
snapshot.json d'un passage du pilote, puis consulte le catalogue actuel.
Il prépare uniquement les épisodes sans blocage et dont la saison est sans
blocage. Les exceptions sont conservées dans selection-report.json.
La préparation ne modifie aucune fiche, copie ni qualification.

Après examen du bilan et sauvegarde, utiliser le moteur existant
script/apply_tmdb_episode_hierarchy.rb avec mapping.json, snapshot.json et
hierarchy-plan.json du dossier sélectionné, d'abord sans --apply.
Ce moteur revalide le plan dans une transaction verrouillée avant l'écriture.
La création de fiches ne confirme pas la disponibilité des copies sur disque.
