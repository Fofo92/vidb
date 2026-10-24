# Pochettes

Les vues de détail affichent une image compacte. Une saison peut avoir sa propre
pochette ; à défaut, saisons et épisodes affichent celle de leur série.
Les collections et films ont leur propre pochette. Aucune colonne dans les listes.

Le volet « Pochette » permet de téléverser une image JPEG, PNG ou WebP de 5 Mo
maximum, ou de récupérer l’image TMDB d’une identité déjà établie. Le téléversement
prime sur l’automatisme. Retirer une pochette désactive sa récupération automatique ;
un clic explicite sur « Récupérer depuis TMDB » peut la réactiver, ou une nouvelle image peut être téléversée. Le repli vers la série reste actif.

## Import initial et périodique

```sh
bin/rails runner script/fetch_record_posters.rb
bin/rails runner script/fetch_record_posters.rb --apply
# Une série et ses saisons peuvent être sélectionnées par leurs identifiants :
bin/rails runner script/fetch_record_posters.rb --apply 15106
```

Sans `--apply`, aucun appel réseau, ni écriture de base ou d’image. Avec `--apply`,
les images manquantes identifiées sont téléchargées, les autres sont conservées.
Ce script peut être relancé après un enrichissement du catalogue. Il ne fait
aucune recherche par homonymie, aucune modification des fiches ni des vidéos.
Aucun téléchargement n’a lieu pendant l’affichage d’une fiche.

Les séries sont identifiées par leurs liens d’épisodes TMDB et/ou un identifiant
`tmdb_series_id` ou une URL TMDB de série dans `year_evidence` ; les contradictions bloquent la récupération.
Une saison exige une correspondance externe univoque de ses épisodes. Films et
collections exigent respectivement `tmdb_movie_id` et `tmdb_collection_id` explicites (ou une URL TMDB du même type).
Une identité manquante se traite par téléversement, sans inventer de correspondance.
Les identifiants peuvent être ajoutés par un enrichissement ultérieur contrôlé.

Le client emploie les variables TMDB_READ_ACCESS_TOKEN ou TMDB_API_KEY existantes.
Les métadonnées API sont mises en cache sous `tmp/poster-cache`. Les images sont
stockées par Active Storage sous `storage` (`/srv/vidb/shared/storage` en production),
à inclure dans les sauvegardes en plus de PostgreSQL. Les téléchargements sont
bornés et limités au serveur HTTPS image.tmdb.org, sans redirection suivie.
L’affichage ne requiert ni traitement de variantes, ni nouvelle gem d’imagerie.

Source : https://developer.themoviedb.org/docs/image-basics
Stockage : https://guides.rubyonrails.org/active_storage_overview.html
Ce produit utilise l’API TMDB sans être approuvé ni certifié par TMDB.

Après le déploiement, depuis le dépôt de développement sur Zeus :

```sh
bin/import-production-posters
bin/import-production-posters --apply
```

Ce lanceur exécute le script de la release courante avec le compte et l’environnement
de production habituels. Il n’arrête pas les encodages et peut être relancé sans doublon.
