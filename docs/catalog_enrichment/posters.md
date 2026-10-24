# Pochettes

Les vues de détail affichent une image compacte. Une saison peut avoir sa propre
pochette ; à défaut, saisons et épisodes affichent celle de leur série.
Les collections et films ont leur propre pochette. Aucune colonne dans les listes.

Le volet « Pochette » permet de téléverser une image JPEG, PNG ou WebP de 5 Mo
maximum, ou de récupérer l’image TMDB d’une identité déjà établie. Le téléversement
prime sur l’automatisme. Retirer une pochette désactive sa récupération automatique ;
un clic explicite sur « Récupérer depuis TMDB » peut la réactiver, ou une nouvelle
image peut être téléversée. Le repli vers la série reste actif.

## Identification automatique

L’import lit d’abord les identités déjà établies : liens d’épisodes TMDB pour
les séries et saisons, identifiants typés (`tmdb_series_id`, `tmdb_movie_id`,
`tmdb_collection_id`) et URL TMDB dans les preuves d’enrichissement. Les sources
imbriquées de `year_evidence`, `abstract_provenance` et `genre_provenance` sont
prises en compte sans réécrire ces preuves. Films et séries restent dans des
espaces d’identifiants distincts ; les contradictions bloquent la récupération.

Pour un film sans identité TMDB exploitable, l’import réutilise directement
`FilmSearchSnapshot` et `FilmIdentityComparison`, comme l’enrichissement existant :
titre concordant, proximité chronologique et résumé suffisamment commun, avec
un seul candidat étayé et une recherche complète. Un simple titre homonyme ne
suffit pas. Une contradiction entre identifiants enregistrés n’est jamais
contournée par une nouvelle recherche.

Les films encore de nature indéterminée ne sont recherchés que s’ils n’ont pas
d’enfants et possèdent un résumé. Les séries non identifiées et les autres cas
insuffisamment étayés restent en attente, sans demander une sélection de pochette.
L’identité utilisée est conservée dans la provenance de la pochette ; aucune
métadonnée, aucun état de visionnage ni aucun fichier vidéo n’est modifié.

## Import ponctuel

```sh
bin/rails runner script/fetch_record_posters.rb
bin/rails runner script/fetch_record_posters.rb --apply
bin/rails runner script/fetch_record_posters.rb --apply 15106
```

Sans `--apply`, aucun appel réseau ni écriture de base ou d’image : le bilan
sépare les identités prêtes (`ready`) et les films à identifier (`to_identify`).
Avec `--apply`, les images manquantes identifiées sont téléchargées ; les autres
sont conservées. Aucun téléchargement n’a lieu pendant l’affichage d’une fiche.
Les imports sont protégés par un verrou commun sous `tmp/poster-import.lock`.

Après déploiement, depuis le dépôt de développement sur Zeus :

```sh
bin/import-production-posters
bin/import-production-posters --apply
```

## Automatisation

Activer une fois le service après le déploiement :

```sh
bin/install-posters-refresh
```

Un premier passage est lancé en arrière-plan. Le service repasse environ toutes
les 30 minutes après la fin du passage précédent et après les redémarrages.
Il récupère les images des nouvelles identités sourcées et tente les films encore
non identifiés avec les règles existantes. Les images et choix manuels sont
conservés. Le verrou empêche le chevauchement avec un import manuel. Les encodages
restent indépendants.

```sh
sudo journalctl -u vidb-posters-refresh.service -n 30 --no-pager
sudo systemctl list-timers vidb-posters-refresh.timer
```

## Stockage et configuration

Le client emploie TMDB_READ_ACCESS_TOKEN ou TMDB_API_KEY. Les réponses API sont
mises en cache sous `tmp/poster-film-cache` et `tmp/poster-cache`. Les images sont
stockées par Active Storage sous `storage` (`/srv/vidb/shared/storage` en production),
à inclure dans les sauvegardes en plus de PostgreSQL. Les téléchargements sont
bornés et limités au serveur HTTPS image.tmdb.org, sans redirection suivie.
L’affichage ne requiert ni variantes, ni nouvelle gem d’imagerie.

Source : https://developer.themoviedb.org/docs/image-basics
Stockage : https://guides.rubyonrails.org/active_storage_overview.html
Ce produit utilise l’API TMDB sans être approuvé ni certifié par TMDB.
