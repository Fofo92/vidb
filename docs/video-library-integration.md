# Intégration de la vidéothèque physique

**Statut :** proposition consolidée du 15 octobre 2026 — à relire avant intégration au dépôt

**Historique :** cadrage initial et inventaire du 4 octobre 2026 ; décisions fonctionnelles complémentaires du 15 octobre 2026.

**Référence examinée :** `Fofo92/vidb`, commit `ab46825`.

**Portée :** articulation entre `vidb`, `video_encoder` et la vidéothèque exposée par MiniDLNA

Ce document complète [le modèle de domaine](domain-model.md) et [le cycle de vie des médias](media-lifecycle.md). Il consigne les décisions déjà partagées, les faits observés pendant l'inventaire et les questions qui doivent rester ouvertes. Il ne constitue pas encore une spécification de schéma de base de données.

## Objectif

`vidb` doit devenir la mémoire durable des œuvres connues, qu'un encodage soit actuellement présent, qu'il ait été supprimé volontairement ou qu'aucun fichier n'ait jamais existé. La structure physique reste parallèlement une interface utilisateur : elle doit être intelligible directement sur un téléviseur par l'intermédiaire de MiniDLNA.

L'identité d'une œuvre ne doit donc plus dépendre du nom ou de l'emplacement mutable de son fichier, mais `vidb` doit rester capable de proposer et de contrôler un classement physique lisible.

`vidb` doit assurer une réconciliation continue entre l'identité éditoriale des œuvres, leurs matérialisations et l'organisation physique des fichiers. `/videos` est aussi une interface de consultation autonome, notamment sur téléviseur via MiniDLNA : ses chemins doivent rester intelligibles sans accès à `vidb`.

Une modification éditoriale **validée**, automatiquement lorsque la preuve est suffisante ou manuellement dans les cas sensibles, peut conduire à un renommage ou à un déplacement physique automatique, à condition que la cohérence disque/base soit préservée. Inversement, un déplacement réalisé hors de `vidb` doit pouvoir être détecté, rapproché de la copie existante et répercuté dans la base après contrôle de l'identité. En cas d'incertitude, créer un dossier de validation, jamais une correction silencieuse.

## Répartition des responsabilités

### `video_encoder`

`video_encoder` reste propriétaire du travail d'encodage :

- choix manuel de lancer un encodage aujourd'hui ;
- préparation et validation des coupures ;
- création du projet JSON ;
- production du fichier encodé, actuellement en MKV ;
- éventuellement, à l'avenir, surveillance d'un répertoire et génération automatique de propositions de coupure.

Une automatisation future ne change pas cette frontière : la file de travail et l'exécution de l'encodage appartiennent à `video_encoder`. `vidb` ne demande pas et ne lance pas d'encodage dans la première étape d'intégration.

### `vidb`

`vidb` est propriétaire de la connaissance et du rapprochement :

- conserver les œuvres, y compris celles qui n'ont aucun fichier présent ;
- repérer les captures qui arrivent dans `/commun/to_be_cut` ;
- conserver séparément les faits observés et l'identification acceptée ;
- proposer une œuvre et, si possible, un épisode candidat ;
- importer les informations utiles du projet JSON ;
- identifier le fichier encodé correspondant ;
- proposer son nom et son emplacement canoniques dans `/videos` ;
- contrôler la cohérence entre catalogue, projets et fichiers physiques.

Au 4 octobre, le transfert automatique du MKV vers son emplacement final restait une décision différée. La cible du 15 octobre inclut des opérations physiques sûres, sans en fixer encore le composant d'exécution. La proposition de destination relève de `vidb`; l'acteur qui réalise effectivement le déplacement devra être explicite et rendre l'opération sûre, répétable et traçable.

## Concepts à distinguer

| Concept | Rôle | Identité durable |
|---|---|---|
| `Record` | Œuvre connue : film, série, saison, épisode, documentaire, etc. | Oui |
| `CapturedFile` | Fichier source brut, par exemple un M2T dans `/commun/to_be_cut` | Oui, indépendamment de son identification |
| `VideoProject` | Projet JSON produit par `video_encoder`, reliant notamment source et résultat | Oui |
| `VideoAsset` | Exemplaire encodé présent, ou trace d'un exemplaire encodé puis supprimé | Oui |

Dans le cadrage du 4 octobre, la situation cible ordinaire était **zéro ou un `VideoAsset` présent par `Record`** (hypothèse historique, assouplie le 15 octobre). Deux exemplaires peuvent coexister temporairement pendant le remplacement d'un ancien encodage, mais l'historisation de toutes les générations successives n'est pas un objectif en soi.

Un `VideoAsset` supprimé conserve la mémoire qu'un encodage a existé et a été retiré volontairement. Il est notamment nécessaire pour migrer les marqueurs TXT historiques.

L'objectif métier est **une œuvre identifiée, associée à zéro, une ou plusieurs matérialisations** : fichier MKV, DVD conservé en bibliothèque, autre support, voire plusieurs versions encodées. Il ne faut pas confondre deux supports légitimes, deux versions différentes d'une œuvre et deux fichiers numériques redondants.

L'hypothèse de travail est de faire porter l'identité éditoriale par `Record`, les copies numériques par `VideoAsset`, et d'examiner les associations de supports déjà existantes avant toute évolution de schéma. Une œuvre sur DVD et sur disque ne justifie pas à elle seule deux fiches `Record`. Des fiches historiques potentiellement équivalentes doivent être rapprochées avec prudence ; leur fusion n'est jamais implicite.

**Précision sur l'ancien texte :** la règle « zéro ou un `VideoAsset` présent par `Record` » demeure une situation courante souhaitable pour les copies numériques ordinaires, **pas une contrainte absolue du modèle**. Des versions ou exemplaires numériques multiples peuvent exister et nécessiter une comparaison.

## Sources, faits et décisions

La connaissance ne provient pas d'une source unique. Chaque source est autoritative pour certains faits seulement :

| Source | Faits qu'elle peut établir | Limites |
|---|---|---|
| `Record` | identité éditoriale, hiérarchie, mémoire de visionnage et vérification manuelle | les champs historiques incomplets ne décrivent pas nécessairement l'état physique actuel |
| inventaire du disque | présence, chemin, taille, dates et caractéristiques techniques d'un fichier | un nom ne suffit pas toujours à identifier l'œuvre |
| projet JSON `video_encoder` | source utilisée, projet de montage, destination prévue et lien entre capture et résultat | le projet peut précéder le résultat ou lui survivre |
| marqueur TXT historique | existence passée d'un encodage visionné puis supprimé | ne fournit plus les caractéristiques techniques du fichier disparu |
| XMLTV, guide et `Tv::RecordingIntent` | observation d'une diffusion et intention de l'enregistrer | titre et numérotation d'épisode peuvent être erronés |
| nom historique du fichier | indices de titre, de langue et de classement | conventions variables et artefacts de renommage |
| source externe telle que TMDB | métadonnées éditoriales et candidats possibles | ne peut pas identifier seule une capture ambiguë |

Le rapprochement doit conserver quatre niveaux distincts :

1. **fait observé**, conservé avec sa source ;
2. **assertion historique**, dont la précision peut être limitée ;
3. **inférence ou candidat**, assorti d'un niveau de confiance ;
4. **décision acceptée**, éventuellement après validation humaine.

Une contradiction entre sources doit être signalée et résolue explicitement. Elle ne doit pas entraîner de correction silencieuse d'un fait observé.

## Interprétation des états historiques

Les booléens de `Record` ont été renseignés progressivement. Leur valeur dépend donc de l'état de vérification de la fiche :

- sur une fiche vérifiée, les valeurs positives et négatives peuvent être considérées comme des assertions relues ;
- sur une fiche non vérifiée, une valeur `true` reste une assertion partielle utile ;
- sur une fiche non vérifiée, une valeur `false` peut signifier « non renseigné » ou « inconnu » et ne constitue pas une négation fiable.

Le futur modèle doit représenter explicitement l'inconnu au lieu de le rabattre sur `false`.

Exemples établis pendant l'audit :

- un fichier présent sur disque peut correspondre à `is_available: true` et `is_recorded: false`, le second champ n'ayant jamais été renseigné ;
- une fiche non vérifiée, enregistrée mais indisponible, indique seulement qu'un enregistrement aurait existé : elle ne prouve ni son visionnage ni une suppression volontaire ;
- une fiche vérifiée, enregistrée, visionnée et indisponible peut raisonnablement témoigner d'un encodage supprimé ;
- une série, une saison ou une collection peut porter un état synthétique hérité, sans posséder elle-même de fichier.

## Hiérarchie des preuves pour la migration

La création initiale des `VideoAsset` suivra une politique prudente :

1. un fichier trouvé sur disque constitue la preuve forte d'un asset présent ;
2. un projet JSON peut relier avec une forte confiance la capture, l'encodage et sa destination ;
3. un marqueur TXT constitue la preuve d'un asset visionné puis supprimé ;
4. une fiche vérifiée et cohérente peut initialiser un asset historique supprimé ;
5. les autres combinaisons d'états deviennent des candidats à examiner et non des assets certains.

Les états des conteneurs sont calculés à partir de leurs descendants. Une série, une saison ou une collection ne reçoit pas automatiquement de `VideoAsset`, même si elle n'a pas encore d'enfants dans la hiérarchie actuelle. Le futur vocabulaire de `record_kind` devra notamment pouvoir représenter les collections.

## État métier et caractéristiques techniques

- `Record.is_seen` signifie « j'ai vu cette œuvre ». Il est indépendant de la présence actuelle d'un fichier.
- `Record.is_checked` signifie que la complétude éditoriale de l'œuvre a été vérifiée manuellement, notamment le pays, le genre et les autres métadonnées attendues.
- La présence physique appartient au `VideoAsset`, avec au minimum les états `present` et `deleted`.
- La durée réelle est mesurée sur le fichier encodé et stockée avec une précision à la minute. La provenance doit rester connue si une durée théorique ou historique est utilisée faute de fichier.
- Les propriétés techniques — conteneur, codecs, pistes audio et sous-titres sélectionnables — proviennent de l'inspection du fichier, et non de son seul nom.

Pour une saison, une série ou une autre branche, la durée affichée est normalement la somme des descendants. Une durée inscrite directement sur le `Record` peut rester une valeur manuelle de repli lorsque les enfants sont incomplets ; elle ne doit pas être confondue avec la durée technique d'un asset.

Les champs historiques `is_recorded`, `is_available`, `length_in_mn` et `language_version` devront être migrés ou redéfinis à partir de ces distinctions. Cette note ne fixe pas encore la migration de schéma.

## Identification progressive des captures

Une capture peut passer par les états suivants :

1. non identifiée ;
2. associée à un ou plusieurs candidats ;
3. identification confirmée ;
4. proposition rejetée, le cas échéant.

Le guide, XMLTV et `Tv::RecordingIntent` appartiennent à la même famille de preuves. Ils sont utiles, mais peuvent comporter une erreur de titre ou de numérotation d'épisode. Leur observation d'origine doit être conservée sans être remplacée silencieusement par l'identité finalement acceptée.

TMDB ou une source équivalente peut enrichir les candidats, pas identifier à elle seule un fichier brut ambigu. Ainsi `Blanca.m2t`, `Blanca-1.m2t` et `Blanca-2.m2t` sont vraisemblablement des épisodes distincts malgré leur titre générique ; l'identité exacte peut n'être résolue qu'au visionnage ou lors de la préparation manuelle dans `video_encoder`.

Le chemin de la source enregistré dans le projet JSON doit permettre de relier ultérieurement la capture, le projet, le résultat encodé et le `Record` confirmé.

## Nommage et classement physiques

### Principes

- Les chemins physiques sont conçus pour rester lisibles sur téléviseur avec MiniDLNA.
- Le titre français est privilégié ; le titre original est ajouté entre parenthèses lorsqu'il est connu, **y compris lorsqu'il est identique au titre français**. Cette répétition est volontaire.
- Le titre d'un conteneur (série, collection, série documentaire) suit également la forme « titre français (titre original) » lorsque les deux sont connus.
- L'année est ajoutée lorsqu'elle est connue et pertinente, sans invention.
- Les films autonomes sont regroupés par **un ou deux genres principaux**, avec les libellés de `vidb`, triés **alphabétiquement** : `Policier, Thriller` et non `Thriller, Policier`.
- Le classement des collections conserve le rang local des films ; un film n'a qu'un emplacement physique principal dans un premier temps.
- Les noms sur disque conservent l'UTF-8. Le séparateur `/` ne peut pas apparaître dans un composant de chemin et doit être remplacé selon une règle stable. Les contraintes techniques supplémentaires des systèmes de fichiers seront vérifiées séparément.
- Certains téléviseurs affichent mal les caractères japonais ou chinois. Prévoir une représentation latinisée **validée** pour le nom physique lorsque nécessaire, sans altérer le titre original conservé dans `vidb`.

### Conventions initiales

```text
/videos/
  Films/
    Policier, Thriller/
      Titre français (Original Title) (2020).mkv
      [*] Titre déjà vu (Titre déjà vu) (2018).mkv
  Collections/
    Nom français (Original Collection Name)/
      01 - Premier film (Original Title) (année).mkv
      [*] 02 - Deuxième film (Deuxième film).mkv
  Séries/
    Nom français (Original Series Name)/
      Saison 01/
        S01 E01 - Titre français (Original Title).mkv
        [*] S01 E02 - Autre titre (Autre titre).mkv
  Documentaires/
    Nom de série documentaire (Original Series Name)/
      Saison 01/
        S01 E01 - Titre français (Original Title).mkv
    Titre documentaire (Original Title) (année)/
      Titre documentaire (Original Title) (année).mkv
```

Les exemples illustrent la syntaxe et non l'existence de ces œuvres. Les extensions réelles doivent être conservées : le renommage ne convertit pas un conteneur.

### Visionnage

Le préfixe **`[*] `** est la convention provisoirement retenue pour représenter `Record.is_seen` dans le nom des fichiers. Il est placé au début pour rester visible dans les listes MiniDLNA tronquées. Une modification de l'état « visionné » dans `vidb` doit pouvoir actualiser automatiquement le nom physique, après contrôles de sécurité et de cohérence. Le préfixe doit être ignoré par les mécanismes d'identification des titres et épisodes. Il ne faut pas créer de répertoire `Vus` par défaut.

### Fichiers associés et compatibilité

Un déplacement ou renommage doit tenir compte des fichiers JSON associés, de leurs éventuels chemins internes et des opérations d'encodage encore actives. Aucun déplacement aveugle de projet n'est acceptable. Les fichiers de provenance peuvent devenir inutiles **après** intégration fiable de leurs informations dans `vidb`, mais pas avant. Les anciens suffixes de complétion restent des indices historiques, pas une partie de l'identité canonique.

Les épisodes spéciaux, les collections atypiques, les variantes de langue ou de montage et les règles détaillées de translittération restent à préciser. La convention devra être confrontée aux répertoires réels et aux capacités de MiniDLNA avant application massive.

### Contexte historique du 4 octobre

Le classement physique doit rester stable et lisible dans MiniDLNA. Il peut inclure le type d'œuvre, la série, la saison, le numéro d'épisode et ses titres, par exemple :

```text
/videos/Séries TV/Nom de la série/Saison 01/S01 E01 - Titre français (Titre original).mkv
```

Cet exemple est conservé comme illustration de la convention envisagée le 4 octobre ; les conventions retenues le 15 octobre figurent ci-dessus.

Les suffixes tels que `(VI - 66_84)` pour une série et `(00_14)` pour une saison sont des résumés manuels de complétion. Ils varient avec une série en cours et ne doivent pas participer à l'identité. La cible privilégiée est un chemin stable et un calcul dynamique de la complétion dans `vidb` ; la convention finale sera décidée après rapprochement avec les usages MiniDLNA.

## Indications linguistiques historiques

| Marqueur | Interprétation de migration |
|---|---|
| `(VF)` | Version française d'après le nom historique |
| `_vf` | Indication française de repli ; souvent suffixe utilisé pour éviter une collision lors d'un futur remplacement |
| `(VOST)` | Audio original avec sous-titres français incrustés dans l'image |
| `(VO)` | Version originale d'après le nom historique |
| `(VM)` | Signification encore indéterminée ; échantillons à inspecter |

Un marqueur entre parenthèses prime sur `_vf`. Par exemple, `(VOST)_vf` doit être interprété comme VOST, `_vf` étant un artefact de renommage. Ces indications restent des preuves historiques ; l'inspection technique prime pour les pistes sélectionnables, mais ne peut pas détecter avec certitude des sous-titres incrustés.

## Faits établis par l'inventaire du 4 octobre 2026

L'inventaire a recensé 18 719 entrées, dont 16 473 fichiers. Les principaux formats sont :

| Extension | Nombre | Volume approximatif | Interprétation |
|---|---:|---:|---|
| M4V | 9 114 | 5,24 To | format historique principal |
| MKV | 6 378 | 4,48 To | format actuel |
| AVI | 73 | 30,5 Go | anciens épisodes fournis par un tiers |
| M2T | 629 | 2,05 To | captures ou sources, inventaire mouvant |
| JSON | 176 | faible | projets `video_encoder` |
| MP4 | 29 | 8,2 Go | ensemble mixte, hors périmètre initial à confirmer |
| MOV | 2 | 1,05 Go | vidéos personnelles, hors périmètre initial |

Parmi les 176 projets JSON :

- 170 ont un MKV homonyme ;
- 2 coexistent avec un ancien M4V et un MKV pendant un remplacement ;
- 4 n'ont pas encore de fichier encodé homonyme et constituent une dette temporaire connue.

Autres cas de migration :

- les TXT vides sont des marqueurs d'encodages visionnés puis supprimés : ils doivent créer ou compléter le `Record`, marquer l'œuvre comme vue et produire la trace d'un `VideoAsset` supprimé ;
- les fichiers vidéo sans extension sont des erreurs de nommage ;
- les noms suffixés automatiquement par `-1`, `-2`, etc. ne prouvent pas qu'il s'agit de rediffusions du même épisode ;
- les deux fichiers TS recensés se trouvent dans un espace de travail `video_encoder` en échec et ne sont pas des médias à importer ;
- MP4, MOV et vidéos familiales ne sont pas intégrés au premier périmètre sans décision explicite.

## Réconciliation, opérations physiques et décisions

Le traitement cible est continu : inventaire, détection des changements, rapprochement avec les œuvres, qualification des preuves, propositions d'action, validation éventuelle et suivi durable des dossiers non résolus.

Un renommage initié dans `vidb` ou observé sur disque doit mettre à jour le rattachement de la copie existante, et non produire artificiellement une suppression suivie d'une création. L'identité ne peut pas reposer uniquement sur le chemin ; des contrôles adaptés de taille, date, caractéristiques techniques et, lorsque nécessaire, empreinte doivent être envisagés.

Les opérations physiques doivent être **prévisualisables, traçables, reprises après incident et protégées contre les collisions**. Une transaction PostgreSQL ne rend pas à elle seule atomique un déplacement de fichier. Les opérations destructrices exigent une validation explicite.

Les services déjà présents de scanner, rapprochement, suivi et import constituent le socle. Leur fonctionnement effectif en production, leurs effets d'écriture et les points d'entrée de validation restent à auditer. La procédure de rafraîchissement existante peut importer des exports `video_encoder` qualifiés : ne pas la qualifier globalement de lecture seule.

## Copies redondantes et qualité

Deux encodages de la même œuvre peuvent constituer des copies redondantes ou des versions légitimement distinctes. `vidb` doit proposer une comparaison puis, le cas échéant, une consolidation **sur disque et/ou en base**. Les DVD et autres supports physiques associés à la même œuvre ne sont pas des doublons numériques à supprimer.

Pour une première réalisation, comparer ce qui est raisonnablement mesurable : durée, résolution, codec, débit, pistes audio, langues, sous-titres, taille et erreurs de décodage accessibles. Distinguer l'intégrité technique des artefacts visuels, défauts sonores et erreurs de montage, dont la détection exhaustive n'est pas attendue initialement. Une recommandation doit expliciter ses critères et incertitudes ; ni suppression de fichier ni fusion de fiches ne doivent être automatiques.

## Conservation transitoire pendant l'audit

Les encodages peuvent continuer. Conserver les projets et fichiers de découpage JSON, y compris ceux renommés ou modifiés, près des résultats dans `/videos`. Conserver les sources `.m2t` en quarantaine sous `/commun/Quarantaine` ; **ne supprimer aucune source actuellement en quarantaine pendant l'audit initial**. Ensuite, définir une procédure de sortie de quarantaine après validation du résultat, de ses pistes, de son montage et de sa conservation. La quarantaine ne remplace pas une sauvegarde.

## Déroulement cible, par étapes

### Première étape

1. inventorier sans modifier les fichiers ;
2. modéliser les liens entre `Record`, capture, projet et asset ;
3. importer les cas certains et signaler les ambiguïtés ;
4. proposer un nom et une destination canoniques ;
5. fournir des contrôles d'intégrité et de complétude.

### Étapes ultérieures possibles

- préparer automatiquement un projet à partir d'une capture identifiée ;
- proposer automatiquement des plages de coupure, avec validation humaine ;
- déclencher le traitement automatique dans `video_encoder` ;
- déplacer de façon sûre le résultat validé vers `/videos` ;
- tendre vers un flux intégralement automatique si la détection et l'identification deviennent suffisamment fiables.

### Priorités de mise en œuvre au 15 octobre 2026

1. Auditer les services, commandes, automatisations et interfaces existants ; distinguer code disponible et fonctionnement réellement déployé.
2. Confronter les conventions physiques aux cas réels : films, collections, séries, documentaires et exceptions.
3. Installer une file durable de réconciliation : preuves, confiance, décisions, anomalies et suivi.
4. Construire un moteur commun de chemins canoniques et de reconnaissance des déplacements extérieurs.
5. Proposer des opérations physiques sûres, avec aperçu, vérification, validation adaptée et reprise.
6. Comparer les copies numériques et proposer leur consolidation.
7. Étendre progressivement le traitement aux sources de `/commun`, sans rendre `vidb` dépendant de `video_encoder`.

## Décisions encore ouvertes

- détails et exceptions des conventions canoniques, désormais définies dans leurs grandes lignes ;
- composant autorisé à déplacer le fichier encodé vers sa destination finale ;
- stratégie de rapprochement lorsqu'une capture reste ambiguë ;
- représentation précise de la provenance et du niveau de confiance ;
- migration des champs historiques de `Record` ;
- traitement des remplacements temporaires et seuil à partir duquel leur historique aurait une valeur ;
- signification de `(VM)` après inspection d'échantillons ;
- périmètre éventuel des MP4, MOV et vidéos personnelles.

Ces points doivent rester explicites dans les travaux suivants : une inconnue modélisée vaut mieux qu'une identification ou une correction silencieuse.


### Questions complémentaires du 15 octobre 2026

- Représentation exacte des DVD et autres supports dans le schéma actuel.
- Règles de distinction entre versions légitimes et doublons numériques.
- Traitement des épisodes spéciaux et des collections atypiques.
- Convention de translittération et tests MiniDLNA réels.
- Gestion des collisions, des fichiers associés et de la reprise après incident.
- Politique précise de validation automatique, d'identification des déplacements et de suppression.
- Questions historiques du document du 4 octobre non encore tranchées : `(VM)`, champs historiques, captures ambiguës, MP4/MOV et vidéos personnelles.

## Traçabilité documentaire

Le cadrage du **4 octobre 2026** fournit le modèle initial, les constats d'inventaire, les états historiques, les preuves et les règles de migration. Les décisions du **15 octobre 2026** précisent la cible : œuvre et matérialisations, conventions de classement, visionnage, synchronisation des fichiers et de la base, comparaison des copies et conservation transitoire. Les informations historiques sont conservées même lorsqu'une orientation ultérieure les complète ou les révise.

**Précaution :** les décisions fonctionnelles ne prouvent pas que les fonctions correspondantes sont déjà développées ou déployées. Le schéma réel et les services doivent encore être audités avant toute modification.
