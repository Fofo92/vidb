# Épisodes déjà acquis dans le guide

La consultation du guide ne dépend plus exclusivement de confirmations
manuelles liées à une ancienne programmation Kaffeine.

## Preuves affichées

- **Déjà acquis — disponible** : une copie complète est déclarée présente
  dans la vidéothèque vidb, y compris un export encodé dont la capture a disparu.
- **Déjà acquis — indisponible** : une acquisition complète est conservée dans
  l’historique des copies, mais sa couverture présente est incomplète ou absente.
- **Déjà enregistré — catalogue** : la fiche indique un enregistrement, sans
  copie suivie permettant d’en déduire la disponibilité actuelle.
- **Capture présente — à vérifier** ou **Source en quarantaine** : un fichier
  source non vide est trouvé. Cela ne prouve ni la fin de la capture ni la
  réussite d’un encodage. Ces indications ne constituent pas une confirmation.
- **Déjà enregistré (vérifié)** : la confirmation manuelle d’un ancien
  enregistrement est conservée même sans programmation Kaffeine restante.
  Retirer explicitement cette confirmation retire cette preuve.

Une copie de la vidéothèque est prioritaire sur une source brute. Le guide
utilise l’état des copies connu de vidb, sans vérifier de nouveau les volumes
ni lancer ffprobe. La synchronisation habituelle des copies reste nécessaire.
Les parties sont évaluées avec VideoAssets::PartCoverage ; les doublons d’une
même partie ne complètent pas un épisode. Les états des séries et saisons
ne sont pas utilisés comme preuve pour leurs épisodes.

## Identité et ambiguïtés

Les numéros xmltv_ns sont convertis de base zéro vers les numéros locaux.
Les accents, la casse et la ponctuation des noms sont normalisés. Le suffixe
« - Saison N » du guide est accepté s’il ne contredit pas le numéro XMLTV.
Seules les hiérarchies qualifiées série/saison/épisode sont rapprochées.
Les homonymes, saisons et rangs d’épisode multiples ne sont pas fusionnés.
Un sous-titre d’épisode fourni par le guide doit correspondre au titre français
ou original de la fiche ou au titre explicite du fichier source.

La première version utilise la numérotation locale ; elle n’infère pas une
équivalence entre des numérotations différentes. Un fichier sans numérotation
explicite, vide, symbolique ou portant plusieurs numéros n’est pas confirmé.
Les enregistrements vérifiés conservent leur mécanisme historique distinct.

## Sources et coût de consultation

Les répertoires suivants sont inspectés récursivement en lecture seule :

- captures : `/commun/to_be_cut` par défaut ;
- quarantaine : `/commun/Quarantaine` par défaut.

Les extensions `.m2t`, `.mts` et `.ts` sont acceptées, sans distinction de casse.
Les noms « Série - S12 E11 - Titre » et « Série - Saison 12, épisode 11 - Titre »
sont reconnus. Un résultat n’est pas déduit du seul nom d’un répertoire.

Les variables `VIDB_TV_CAPTURE_ROOTS` et `VIDB_TV_QUARANTINE_ROOTS` remplacent
ces listes par des chemins absolus séparés par `:`. Une valeur vide désactive
la recherche correspondante. Ajouter explicitement les autres volumes de
quarantaine s’ils sont utilisés ; les chemins doivent être lisibles par vidb.
Un répertoire absent ou inaccessible ne constitue pas une preuve d’acquisition.

L’inventaire léger est mis en cache une minute : un déplacement de source peut
donc apparaître avec ce délai. Aucun fichier vidéo n’est ouvert ni analysé.
Les requêtes de catalogue et les fichiers sont regroupés par page, sans
recherche par fichier pour chaque programme. Les programmes sans numéro
d’épisode ne déclenchent pas ces recherches.

## Effets

Aucune écriture en base, modification de fichier ou programmation Kaffeine
n’est effectuée par la détection. La rediffusion reste programmable. La fiche
vidb ou le chemin de la source est présenté dans le détail de l’indication.
