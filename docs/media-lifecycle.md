# Cycle de vie des contenus et des fichiers vidéo

Ce document définit les principales identités manipulées par `vidb`, le guide TV, le futur adaptateur Kaffeine
et `video_encoder`.

Il précise notamment les différents sens historiques du mot « enregistrement » et les niveaux de preuve
associés.

## Principe général

Une œuvre, une diffusion, une capture et un fichier physique sont des
objets distincts.

Chaque objet possède sa propre identité durable. Les relations entre ces objets permettent de reconstituer
l’histoire complète, depuis l’annonce d’un programme jusqu’au fichier final disponible.

Un nom, un chemin ou un identifiant fourni par un logiciel externe ne constitue pas l’identité interne
durable d’un objet de `vidb`.

## Contenu catalogué

L’actuel modèle `Record` représente une fiche du catalogue personnel.

Selon sa nature, cette fiche peut décrire :

- une vidéo autonome ;
- une série ;
- une saison ;
- un épisode ;
- un contenu encore indéterminé.

Une fiche peut exister indépendamment de toute diffusion ou de tout fichier physique. Elle reste présente
après la disparition de ses fichiers.

Le nom conceptuel `Content` pourra être envisagé ultérieurement. Pendant la transition, le modèle et la
table `Record` sont conservés.

## Observation du guide

Une observation du guide reproduit une annonce provenant d’une source identifiée, par exemple XML TVFr.

Elle peut contenir :

- l’identifiant externe de la chaîne ;
- les horaires annoncés ;
- les titres et sous-titres ;
- une description ;
- des catégories ;
- une numérotation d’épisode ;
- la langue et le système associés à ces valeurs.

Cette observation constitue une information de source. Elle ne prouve ni que le programme sera
effectivement diffusé, ni qu’il correspond déjà à une fiche du catalogue.

Les observations successives doivent rester traçables. Une correction d’horaire et le remplacement
éditorial d’un programme ne peuvent pas être distingués automatiquement sur la seule ressemblance des
titres et des horaires.

## Diffusion

Une diffusion représente l’événement éditorial consistant à proposer un contenu sur une chaîne à un
moment donné.

Son identité métier ne peut pas être déduite de manière fiable du fichier XMLTV actuel. Elle sera introduite
lorsque plusieurs observations pourront être rapprochées par une règle suffisamment sûre ou par une
décision humaine.

Une diffusion pourra être associée à zéro, un ou plusieurs contenus catalogués.

## Intention d’enregistrement

Une intention d’enregistrement exprime le souhait de l’utilisateur d’obtenir un contenu ou une diffusion
annoncée.

Elle pourra conserver :

- l’observation ou la diffusion choisie ;
- le contenu attendu lorsqu’il est connu ;
- les marges souhaitées ;
- les décisions prises après une modification du guide ;
- son état métier.

Une intention ne prouve pas qu’une programmation technique a été créée ni qu’une capture a eu lieu.

## Programmation technique

Une programmation technique représente la demande transmise au moteur d’acquisition, initialement
Kaffeine.

Elle conserve notamment :

- l’intention dont elle provient ;
- le nom technique de la chaîne ;
- le début et la fin demandés, marges comprises ;
- la référence externe renvoyée par Kaffeine ;
- le résultat de la vérification après création ;
- les modifications ou annulations ultérieures.

L’identifiant fourni par Kaffeine n’est pas une identité durable. Il peut être réutilisé après suppression.

Une intention pourra donner lieu à plusieurs programmations techniques, par exemple après une
correction, une nouvelle tentative ou le choix d’une rediffusion.

## Capture réelle

Une capture représente une tentative d’acquisition effectivement exécutée.

Elle pourra exister avec ou sans programmation préalable et conserver :

- la programmation éventuellement associée ;
- la chaîne demandée ;
- les heures réelles observées ;
- son état technique ;
- les erreurs éventuelles ;
- les fichiers produits.

Une capture terminée ne prouve pas encore que le contenu attendu a réellement été diffusé ni que le
fichier est exploitable.

Une même capture peut contenir plusieurs films ou épisodes.

## Fichier physique

Un fichier physique désigne un ensemble précis d’octets observé par le système.

Chaque fichier possède une identité interne indépendante de son nom et de son chemin.

Les rôles envisagés comprennent notamment :

- source de capture ;
- export final ;
- autre fichier intermédiaire utile.

Un fichier `.m2t` produit par une capture et un fichier `.mkv` produit par un montage sont deux fichiers
physiques distincts.

Leur relation est représentée par la transformation qui a utilisé le premier pour produire le second.

## Emplacements d’un fichier

Le chemin d’un fichier ne constitue jamais son identité.

L’historique des emplacements doit permettre de conserver :

- le premier chemin observé ;
- les renommages ;
- les déplacements ;
- la mise en quarantaine ;
- la disparition constatée ;
- la suppression confirmée.

Un déplacement ou un renommage ne crée pas un nouveau fichier physique.

Si de nouveaux octets remplacent un ancien fichier au même chemin, ils doivent pouvoir être reconnus
comme un autre fichier physique.

La taille et une empreinte peuvent contribuer à cette identification.

## Noms des fichiers

Le nom d’un fichier constitue une information pratique et modifiable.

Le nom initial d’une source `.m2t` peut privilégier les faits techniques :

- date et heure ;
- chaîne ;
- identifiant court de capture ;
- titre annoncé facultatif.

Le nom d’un `.mkv` final peut privilégier le contenu éditorial après validation :

- titre ;
- année ;
- saison et épisode ;
- titre d’épisode.

Ces noms peuvent être proposés automatiquement. Ils ne prouvent pas le contenu du fichier.

## Inspection technique

Une inspection décrit un fichier physique à une date donnée avec un outil et une version identifiés.

Elle peut notamment conserver :

- la durée mesurée ;
- le conteneur ;
- les codecs ;
- la résolution ;
- les pistes audio ;
- les langues déclarées ;
- les sous-titres ;
- les débits ;
- les anomalies détectées ;
- la réponse structurée de l’outil.

Les informations provenant de `ffprobe`, `ffmpeg`, `mkvinfo` ou d’un autre outil appartiennent au fichier
inspecté.

Plusieurs inspections peuvent être conservées pour un même fichier.

Les durées et versions linguistiques actuellement présentes dans `Record` restent des informations
éditoriales indicatives. Elles ne remplacent pas les caractéristiques techniques des fichiers réels.

## Montage et export

Une transformation représente l’utilisation d’un ou plusieurs fichiers sources pour produire un ou plusieurs
fichiers finaux.

Une source peut alimenter plusieurs exports. Un export peut utiliser plusieurs sources.

`video_encoder` reste responsable des détails techniques :

- projets de découpage ;
- segments ;
- pistes ;
- contrôles audio ;
- tentatives d’encodage ;
- fichiers produits ;
- erreurs ;
- quarantaine.

`vidb` conservera les faits utiles publiés par `video_encoder`, sans lire directement sa base SQLite.

Le futur contrat d’échange devra être explicite, versionné et idempotent.

## Identification du contenu

Une capture ou un fichier peut être associé à plusieurs contenus avec un niveau de certitude explicite.

Les niveaux pressentis sont :

| Niveau      | Signification                                 |
| ----------- | --------------------------------------------- |
| `expected`  | Contenu prévu d’après le guide ou l’intention |
| `probable`  | Correspondance déduite, non encore vérifiée   |
| `confirmed` | Contenu vérifié par l’utilisateur             |
| `rejected`  | Contenu attendu mais constaté absent          |

Une association attendue ne doit jamais devenir confirmée automatiquement du seul fait que la capture
ou le fichier existe.

## Références externes et TMDB

TMDB décrit un contenu éditorial. Il ne décrit pas un fichier physique ni une capture particulière.

Une recherche peut utiliser des indices provenant :

- du guide TV ;
- du nom d’un fichier source ;
- du nom d’un fichier final ;
- d’une inspection ;
- d’une fiche existante ;
- d’une saisie manuelle.

La recherche produit des candidats. La sélection validée relie ensuite une fiche interne à une référence
externe.

L’identité interne du contenu reste celle de `vidb`. L’identifiant TMDB est une référence externe
accompagnée de sa provenance et de sa date de validation.

## Niveaux de preuve

Le cycle de vie distingue les niveaux suivants :

| Niveau    | Fait établi                                                  |
| --------- | ------------------------------------------------------------ |
| Prévu     | Le guide annonce une diffusion et une intention existe       |
| Demandé   | Une programmation a été acceptée par le moteur               |
| Capturé   | Une tentative réelle et un fichier source sont observés      |
| Identifié | Le contenu de la capture ou du fichier est vérifié           |
| Finalisé  | Un fichier final est produit, inspecté et associé au contenu |

Le terme « enregistré » ne doit pas être utilisé seul lorsqu’une ambiguïté subsiste entre ces niveaux.

## États historiques de Record

Les attributs historiques `is_recorded` et `is_available` restent conservés pendant la transition.

À terme :

- l’existence passée d’une capture ou d’un fichier source contribuera à déterminer qu’un contenu a été
  enregistré ;
- la présence actuelle d’au moins un fichier exploitable contribuera à déterminer qu’il est disponible ;
- la suppression des fichiers ne supprimera pas l’historique de leur existence.

La stratégie de migration de ces booléens sera définie après l’introduction des captures et des fichiers
physiques.

## Répartition des responsabilités

### vidb

`vidb` est responsable :

- du catalogue ;
- des chaînes et diffusions ;
- des intentions ;
- des associations avec les contenus ;
- des fichiers physiques connus ;
- de leur histoire et de leur disponibilité métier ;
- de la provenance des métadonnées.

### Moteur d’acquisition

Le moteur d’acquisition est responsable :

- des programmations techniques ;
- de l’utilisation des tuners ;
- de la réception ;
- de la création des fichiers sources ;
- des états et erreurs de capture.

Kaffeine reste le moteur initialement retenu.

### video_encoder

`video_encoder` est responsable :

- de l’inspection nécessaire au traitement ;
- du découpage ;
- du montage ;
- de l’encodage ;
- des fichiers finaux ;
- de la quarantaine technique.

## Relations plusieurs-à-plusieurs

Le modèle doit permettre les situations suivantes :

- une capture contient plusieurs contenus ;
- un contenu apparaît dans plusieurs captures ;
- un fichier source produit plusieurs fichiers finaux ;
- un fichier final utilise plusieurs fichiers sources ;
- un contenu possède plusieurs fichiers finaux ;
- un fichier contient éventuellement plusieurs contenus.

Ces relations ne doivent pas être réduites à une colonne unique placée sur un fichier, une capture ou une
fiche du catalogue.

## Décisions différées

Les points suivants seront précisés dans des étapes ultérieures :

- représentation définitive des diffusions ;
- contrat avec Kaffeine ;
- contrat JSON avec `video_encoder` ;
- politique d’empreinte des fichiers ;
- règles de rapprochement TMDB ;
- noms définitifs des associations entre contenus, captures et fichiers ;
- calcul des états dérivés remplaçant progressivement `is_recorded` et `is_available`.
