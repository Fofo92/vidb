# Application du plan Poirot

La migration crée `catalogue_episode_links` : chaque fiche d’épisode garde son identifiant TMDB, les numéros locaux et externes, et les références de provenance. La base impose une identité externe unique et une liaison unique par fiche et fournisseur. Le plan, la correspondance et le snapshot sont des entrées distinctes.

## Comportement

Le script fonctionne en prévisualisation par défaut. `--apply` applique le lot dans une transaction PostgreSQL. Les tables records et catalogue_episode_links sont verrouillées pendant le contrôle et l’application pour éviter des modifications concurrentes du catalogue. Les consultations restent possibles ; les écritures concurrentes attendent brièvement.

Le plan est recalculé contre la base et doit être identique au plan fourni. Une modification de titre, de classement, un doublon nouveau ou une liaison externe partielle bloque toute application. Une erreur tardive restaure les qualifications, placements, créations et liaisons.

- Série et saisons sont qualifiées comme telles. Les épisodes existants sont reclassés sous leurs saisons, avec conservation des titres, dates, durées et informations personnelles. Un résumé TMDB est ajouté uniquement si le résumé existant est vide.
- Les nouveaux épisodes reçoivent leurs titres et un résumé TMDB, non vérifié. Leur année de production et leur durée restent vides ; les références TMDB sont conservées séparément dans les liaisons externes.
- Les nouveaux records héritent de la version linguistique de catalogue, des pays et genres du parent série. Cette compatibilité avec le modèle actuel ne confirme pas les pistes audio de leurs copies.
- Les nouveaux épisodes ont des états enregistré/disponible/vu inconnus et une fiche non vérifiée. Aucune copie n’est importée, aucun fichier disque n’est déplacé ou renommé.
- Une réexécution exacte reconnaît les liaisons et la hiérarchie déjà présentes sans créer de doublons ni remplacer les modifications éditoriales ultérieures.

Résultat attendu pour Poirot : 12 saisons et 47 épisodes créés, 23 épisodes réutilisés et 70 liaisons externes. La saison 4 existante est conservée. L’ordre local de saison 12 reste inchangé.

## Exécution dans le contexte production habituel

```sh
bin/rails runner script/apply_tmdb_episode_hierarchy.rb \
  doc/catalog_enrichment/poirot-local-tmdb-mapping.json \
  /srv/vidb/shared/tmdb-series-790-snapshot.json \
  /srv/vidb/shared/poirot-hierarchy-plan.json \
  /srv/vidb/shared/poirot-hierarchy-preview.json
```

Après sauvegarde PostgreSQL, reprendre la même commande avec un fichier de sortie `poirot-hierarchy-applied.json` et l’argument final `--apply`. Si la sortie JSON échoue après la validation de la transaction, relancer le script : la base conserve les liaisons et la réexécution est reconnue.

Les titres anglais et la ponctuation incorrects dans deux noms de fichiers restent à corriger séparément. Une nouvelle réconciliation suivra l’application avant toute importation des copies.
