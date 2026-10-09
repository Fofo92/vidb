# Convention des années

Cible : première diffusion originale pour les épisodes; première sortie originale
pour les films. L’année de production reste une convention distincte.

Affichage compact : Diff. / Prod. / ? / Mixte. Les plages des saisons et séries
sont calculées sur les années connues des feuilles; elles ne garantissent pas
la présence d’une année pour chaque épisode. Une plage de conventions différentes
porte Mixte. Les anciennes saisies restent unknown, sans réinterprétation.

records.year_basis : unknown, first_release, production.
year_evidence contient la source; year_history conserve chaque ancienne valeur,
qualification et preuve lors d’un changement effectué via le modèle Rails.
Une modification manuelle de l’année seule retire l’ancienne qualification.
Les écritures SQL directes ou update_columns contournent ces protections.

Le script script/complete_linked_episode_years.rb utilise uniquement les dates
first_air_date déjà conservées dans les liens TMDB des descendants du parent
explicitement choisi. Il ne cherche pas de nouveaux liens et ne modifie pas
les durées, langues ou états. Sans date, l’année actuelle est conservée.
Une date invalide annule tout le lot. Les dates sont des références du catalogue
externe, pas des dates d’enregistrement ni de diffusion française.

Usage : bin/rails runner script/complete_linked_episode_years.rb ROOT_ID OUTPUT.json [--apply]
Prévisualiser, sauvegarder la base, puis appliquer. Le script est idempotent.
Commencer avec 7335 (9-1-1), puis traiter les autres séries par lots explicites.
L’import automatique de nouvelles dates et l’harmonisation des films restent à
étendre; aucune série autre que celle désignée n’est harmonisée implicitement.
