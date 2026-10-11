# Compléter les copies liées de 9-1-1

La hiérarchie et les liens TMDB sont appliqués avant la préparation des copies.
Le script script/prepare_linked_episode_completion.rb lit la configuration,
le mapping sélectionné et l'inventaire du même passage du pilote. Il vérifie
les identifiants, les chemins, tailles, dates et liens, sans modifier la base.

La configuration retient États-Unis et Drame (TMDB 18) comme genre principal.
Le support HD désigne le disque dur, pas la résolution de l'image.
Les éventuelles métadonnées incompatibles présentes dans le catalogue bloquent
la prévisualisation au lieu d'être remplacées silencieusement.

script/complete_linked_episode_assets.rb utilise ensuite le moteur existant :
nouvelle observation technique de chaque copie, comparaison avec l'inventaire,
contrôle du volume et vérification finale avant écriture transactionnelle.
La prévisualisation ne modifie ni les états ni les associations.
Après sauvegarde, --apply confirme les copies et leurs durées mesurées.
Les qualifications linguistiques restent une étape séparée fondée sur les copies
finales et les preuves d'encodage. Aucune date de diffusion TMDB ne devient
une année de production.

Le traitement de Poirot reste compatible : les anciens lots sans identifiant
de genre explicite attendent toujours TMDB Crime (80).
