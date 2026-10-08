# Poirot : numérotation locale et correspondances TMDB

Le fichier `poirot-local-tmdb-mapping.json` conserve les 70 correspondances et les 23 fiches candidates connues, avec leur état hiérarchique attendu. Il doit être conservé dans Git. Il ne représente pas encore une liaison appliquée en base.

Décisions confirmées par Pascal le 8 octobre 2026 :

- S03 E04 est L’Express de Plymouth : titre original The Plymouth Express. Le titre anglais du nom de fichier actuel désigne un autre épisode et doit être corrigé séparément.
- La saison 12 conserve l’ordre local : Les Pendules, Drame en trois actes, Le Crime d’Halloween, Le Crime de l’Orient-Express. Les numéros TMDB correspondants sont E04, E01, E02 et E03.
- Le titre Un, deux, trois... conserve ses trois points ; avec le séparateur de l’extension, le nom se termine par `trois....m4v`.

Les autres variantes de titres sont documentées par les titres locaux et originaux. Elles restent des propositions tant que le plan n’a pas été appliqué. Les titres existants ne sont pas écrasés par un titre TMDB. Le dossier de série et les extensions M4V restent inchangés avec ce lot.

## Plan en lecture seule

```sh
bin/rails runner script/plan_tmdb_episode_hierarchy.rb \
  doc/catalog_enrichment/poirot-local-tmdb-mapping.json \
  /srv/vidb/shared/tmdb-series-790-snapshot.json \
  /srv/vidb/shared/poirot-hierarchy-plan.json
```

Le plan interroge les fiches de la base courante. Il refuse une série différente et les correspondances TMDB périmées. Il signale les fiches modifiées, les collisions de titres, les épisodes déjà attachés ailleurs et les nouveaux candidats apparus depuis le diagnostic. Le résultat distingue `reuse_proposal`, `create_proposal` et `needs_review`.

Le diagnostic fourni conduit à 23 épisodes à réutiliser, 47 créations proposées, une saison existante à réutiliser et 12 saisons proposées. Ces nombres doivent être confirmés sur la base actuelle. Aucun record n’est créé ou déplacé, aucune copie n’est importée, aucun fichier n’est renommé. Les numéros de saison seuls ne suffisent pas à récupérer des saisons orphelines : elles nécessitent une identification spécifique.

Les résumés sont proposés ; les dates de diffusion et durées restent des références externes. Aucune année de production, langue de copie, disponibilité ou vérification éditoriale n’est déduite.

Étape suivante : application transactionnelle du plan, avec conservation des informations personnelles et enregistrement durable des identifiants externes associés aux fiches créées ou réutilisées. Ce script de préparation ne possède volontairement aucun mode `--apply`.
