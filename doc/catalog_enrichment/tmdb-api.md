# Consultation TMDB et comparaison des épisodes

Ce premier accès est en lecture seule : aucune fiche, aucun état et aucun fichier vidéo n’est modifié. Un titre concordant reste une proposition, jamais une autorisation de rattachement. Les candidats issus du catalogue complet peuvent appartenir à une autre œuvre : ils restent à contrôler dans le contexte de la série.

## Configuration

Renseigner sur le serveur, dans `/etc/vidb/vidb.env`, une seule des variables suivantes :

- `TMDB_READ_ACCESS_TOKEN` : jeton « API Read Access Token » recommandé ;
- `TMDB_API_KEY` : clé API v3, également acceptée.

Le jeton est envoyé dans l’en-tête Authorization. La clé v3 est envoyée dans la requête HTTPS. Ne pas ajouter ces secrets au dépôt ni les transmettre dans un rapport. Les erreurs HTTP n’affichent pas les réponses ni les URL authentifiées. Les fichiers de cache ne contiennent que les réponses de catalogue.

## Exécution

Dans le contexte Rails approprié :

```sh
bin/rails runner script/tmdb_series_comparison.rb 790 \
  /srv/vidb/shared/video-asset-reconciliation-after-poirot.json \
  '/videos/Séries TV/_complet/Hercule Poirot (c - 70)'
```

La commande produit `tmp/tmdb-series-790-snapshot.json` et `tmp/tmdb-series-790-comparison.json`. Utiliser le contexte systemd de production habituel avec `EnvironmentFile=/etc/vidb/vidb.env` pour accéder à la bonne base et aux identifiants.

Les réponses sont conservées sous `tmp/tmdb-cache` et réutilisées jusqu’à une exécution avec `--refresh`. Le cache dépend de la release ; il n’est pas encore un historique durable des décisions. Une consultation partielle échouée peut conserver les requêtes réussies, mais ne produit pas de nouveau rapport complet. Les erreurs HTTP, dont 429, interrompent la commande sans modification du catalogue ; réessayer plus tard.

## Données et interprétation

- Titres et résumés en `fr-FR`, titres dans la langue originale de la série obtenus par une seconde consultation.
- Les épisodes spéciaux de saison 0 sont exclus de ce premier lot.
- `first_air_date` représente la première diffusion ; ce n’est pas une année de production.
- `reference_runtime_minutes` reste une durée externe ; elle ne remplace pas une mesure du fichier.
- Les titres sont comparés à travers toutes les saisons. Une concordance de numéro seule ne suffit jamais.
- La ponctuation reste significative, hormis l’unification des apostrophes typographiques et des espaces. Un titre inconnu ou un doublon reste à examiner.
- Aucune langue de copie, aucun genre ni pays n’est automatiquement attribué.

Ce module ne gère pas encore les images ou les recherches par titre. L’identifiant TMDB de la série est explicitement choisi, ici 790 pour Hercule Poirot.

## Vérifications

```sh
bundle exec ruby bin/rails test \
  test/services/catalog_enrichment/tmdb_client_test.rb \
  test/services/catalog_enrichment/tmdb_series_snapshot_test.rb \
  test/services/catalog_enrichment/tmdb_episode_comparison_test.rb
bin/check
```

Les tests utilisent des réponses simulées, sans clé et sans accès réseau.

Documentation officielle :

- https://developer.themoviedb.org/docs/authentication-application
- https://developer.themoviedb.org/reference/tv-series-details
- https://developer.themoviedb.org/reference/tv-season-details

Les données sont fournies par TMDB ; cette intégration n’est ni approuvée ni certifiée par TMDB. L’attribution dans les vues devra accompagner leur future mise en service.
