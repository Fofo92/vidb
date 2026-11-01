# Affichettes des collections à partir des films enfants

## Exécution en production

Après déploiement, depuis le dépôt vidb :

```sh
bin/import-production-collection-posters
bin/import-production-collection-posters --apply
```

Les commandes parcourent **toutes** les collections ; aucun recensement manuel
n'est nécessaire. Pour un essai limité, ajouter des identifiants de fiches vidb,
par exemple `69 17370`. L'option `--refresh` relit les données depuis TMDB au lieu
d'utiliser le cache ; elle peut s'employer en aperçu comme en application.
Le script peut aussi être lancé avec `bin/rails runner script/import_collection_posters.rb`.

L'aperçu effectue des lectures TMDB et remplit un cache technique, sans modifier
les fiches, les associations de collection ni les pochettes. Il n'utilise pas de
recherche par titre pour identifier les films : seuls leurs identifiants TMDB
conservés dans les preuves existantes sont exploités.

## Conditions d'association automatique

Une référence de collection explicitement conservée est réutilisée. Sinon :

- Tous les enfants directs sont des films feuilles identifiés sans contradiction.
- Au moins deux identifiants de films distincts sont connus.
- Chacun appartient à la même collection TMDB.
- Le catalogue de cette collection confirme la présence de tous ces films.
- Un titre local concorde avec le titre TMDB, après normalisation des accents,
  de la ponctuation et des mots « collection », « saga », « intégrale ».

Une collection peut être incomplète sur disque : il n'est pas nécessaire de
posséder tous les films de la franchise. Une identité insuffisante, un seul film,
des appartenances mixtes, des sous-collections ou un titre personnel différent
produisent un cas `review`, sans écriture. Il ne faut pas appliquer manuellement
un identifiant issu d'une simple ressemblance de titre sans vérifier la collection.

## Bilan et reprise

La sortie contient une ligne JSON par collection, puis un résumé des compteurs :

- `ready` : correspondance inférée applicable, dans l'aperçu ;
- `identified` : référence déjà conservée ;
- `preserved` : image existante ou choix manuel protégé ;
- `review` : raison détaillée et, si disponible, identifiant TMDB proposé ;
- `associated` : référence conservée côté pochette ; `poster` donne ensuite
  `attached`, `absent` ou `preserved` ;
- `changed` : changement entre planification et application, sans écriture ;
- `error` / compteur `errors` : échec à examiner puis relancer.

En application, chaque plan est recalculé sous verrou de fiche. La source de
pochette est vérifiée sous verrou distinct pour préserver une image personnelle
ajoutée entre-temps. L'identifiant de collection, les films ayant servi de preuves
et la version de la règle sont inscrits dans la source de pochette avant le
téléchargement. Le bilan d'application contient également les films utilisés. Après
récupération réussie, le mécanisme existant conserve la référence TMDB de l'image.
En cas d'échec de téléchargement, l'association reste disponible pour une reprise.

Les exécutions sont sérialisées avec les autres imports de pochettes au moyen du
verrou `poster-import.lock`. Une relance conserve les images déjà attachées.

Aucun champ éditorial de `Record` n'est sauvegardé par ce traitement. Aucun enfant
n'est déplacé, aucune liaison de projet n'est modifiée et aucun fichier d'encodage
ou tâche video_encoder n'est ouvert. Aucune migration ni nouveau timer n'est
nécessaire : l'association explicite retrouvée est exploitable par le récupérateur
habituel d'affichettes. Le bilan global se lance à la demande ; les cas ambigus ne
sont jamais appliqués automatiquement.
