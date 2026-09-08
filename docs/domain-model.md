# Modèle métier de vidb

Ce document décrit le sens actuel des données de `vidb` et les orientations retenues pour leur évolution. Il
sert de référence avant toute transformation du modèle.

Il ne décrit pas encore un schéma de base de données définitif.

## Responsabilité de vidb

`vidb` est la base de connaissances personnelle consacrée aux contenus audiovisuels et à leur disponibilité.

À terme, elle devra représenter notamment :

- les contenus catalogués ;
- les films, séries, saisons et épisodes ;
- les collections ;
- les métadonnées externes validées ;
- les chaînes et diffusions télévisées ;
- les programmations d’enregistrement ;
- les captures réellement obtenues ;
- les fichiers physiques et leurs emplacements successifs ;
- les états de consultation et de disponibilité.

Les faits techniques liés au découpage et à l’encodage resteront sous la responsabilité de `video_encoder`.

Les deux applications ne partageront pas leur base de données. Leur future intégration reposera sur un
contrat explicite, probablement constitué de documents JSON versionnés et idempotents.

## Sens actuel de Record

Le modèle `Record` représente actuellement une fiche de la base de connaissances. Selon les données,
cette fiche peut désigner :

- une vidéo autonome ;
- une série ;
- une saison ;
- un épisode ;
- une collection ;
- un membre d’une collection ;
- un contenu encore mal classé à la suite de la récupération d’une ancienne base.

Une vidéo autonome peut être un film, un documentaire, un court métrage, un téléfilm, une captation de
pièce ou de spectacle, une vidéo familiale, un extrait provenant d’Internet ou tout autre contenu lisible par
un lecteur vidéo courant.

`Record` mélange donc aujourd’hui plusieurs dimensions qui devront être distinguées progressivement.

## Dimensions indépendantes

### Nature du contenu

La nature décrit ce que représente la fiche. Le vocabulaire envisagé est :

- `undetermined` : nature encore inconnue ou à consolider ;
- `standalone_video` : vidéo autonome ;
- `series` : série ;
- `season` : saison ;
- `episode` : épisode ;
- `collection` : regroupement ordonné de contenus.

Ces noms sont provisoires. Si cette information est ajoutée au modèle Rails, la colonne ne devra pas
s’appeler `type`, car ce nom est réservé par Rails à l’héritage STI.

### Organisation

L’organisation décrit les relations entre les contenus.
Deux structures principales existent dans les données :

- série → saison → épisode ;
- collection → contenu.

Une collection représente par exemple une série de films comme James Bond, Astérix ou Mission Impossible.

La relation entre une série, ses saisons et ses épisodes n’a pas nécessairement les mêmes règles que
l’appartenance à une collection. Un contenu pourrait notamment appartenir à plusieurs collections.

Les pilotes, épisodes spéciaux et épisodes hors saison devront pouvoir être représentés sans créer
artificiellement une saison ordinaire.

### Vérification

`is_checked` signifie que les attributs de la fiche ont fait l’objet d’une vérification manuelle, généralement
avec TMDB ou une autre source disponible sur Internet.

Cette vérification :

- qualifie chaque fiche indépendamment ;
- ne se propage pas automatiquement entre parent et enfants ;
- ne garantit pas l’absence d’erreur humaine ;
- ne signifie pas que toute la structure d’une série est complète ;
- ne signifie pas que le contenu possède une référence TMDB.

### Possession et historique

Les états actuels ont les significations suivantes :

- `is_recorded` indique que le contenu a été enregistré au moins une fois ;
- `is_available` indique qu’un fichier vidéo correspondant est actuellement
  disponible sur le stockage du PC ;
- `is_seen` indique que le contenu a été visionné.

Un contenu enregistré peut ne plus être disponible : le fichier peut avoir été supprimé afin de limiter le
volume de stockage, tandis que sa fiche reste dans la base de connaissances.

Ces booléens décrivent imparfaitement l’histoire réelle. Ils ne permettent pas de représenter plusieurs
fichiers, leurs déplacements, leurs suppressions ou plusieurs captures successives d’un même contenu.

## Hiérarchie actuelle

La hiérarchie repose sur `ancestry`.

L’observation des données a montré trois formes principales :

- des racines isolées ;
- des racines avec un niveau d’enfants, généralement des collections ;
- des racines avec deux niveaux de descendants, généralement des séries
  structurées en saisons et épisodes.

Lors de l’inventaire effectué sur 7 049 fiches, la base contenait :

| Forme                        | Nombre |
| ---------------------------- | -----: |
| Racines                      |  4 578 |
| Descendants                  |  2 471 |
| Racines isolées              |  4 377 |
| Collections probables        |     32 |
| Séries structurées probables |    169 |
| Fiches de profondeur 1       |    467 |
| Fiches de profondeur 2       |  2 004 |

Aucune fiche plus profonde n’a été observée et aucune référence à un ancêtre absent n’a été détectée.

La hiérarchie actuelle doit être conservée pendant la transition afin de préserver les identifiants et les
données récupérées.

## Origine des données à consolider

La base actuelle provient en partie d’une ancienne base imparfaitement récupérée. Certains liens entre
parents et enfants ont été perdus.

Les fiches non vérifiées ont été conservées pour éviter une ressaisie manuelle longue. Elles constituent des
données récupérables, mais leur classement, leurs attributs ou leurs états peuvent être inexacts.

Une racine portant un rang non nul peut ainsi être un ancien enfant dont le parent n’a pas encore été
retrouvé.

Cette situation constitue une dette de consolidation historique. Elle ne doit pas être transformée
implicitement en règle métier.

## Rang

Le champ `rank` sert actuellement à ordonner :

- les saisons d’une série ;
- les épisodes d’une saison ;
- les membres d’une collection.

Cette notion recouvre plusieurs significations métier. Elle pourra être remplacée ultérieurement par des
attributs distincts, tels qu’un numéro de saison, un numéro d’épisode ou une position dans une collection.

Les données contiennent notamment :

- onze descendants sans rang, tous nommés « Saison 1 » ;
- un épisode pilote de rang zéro ;
- quelques rangs dupliqués sous un même parent ;
- des racines portant un rang, généralement à consolider.

Les rangs ne doivent donc pas encore faire l’objet d’une contrainte générale. Les pilotes, épisodes spéciaux
et autres cas particuliers devront être étudiés avant de définir les futurs invariants.

## Supports

`Medium` représente actuellement un type de support de stockage, par exemple :

- disque dur ;
- DVD ;
- Blu-ray.

Une fiche peut être associée à plusieurs supports.

`Medium` ne représente ni un fichier physique précis, ni son chemin, ni une copie particulière du contenu.
Dans les données actuelles, seul le support disque dur est réellement utilisé ; les collections de DVD et
Blu-ray n’ont pas encore été renseignées.

Le futur modèle des fichiers physiques devra posséder une identité durable, indépendante de leur chemin
et de leur support.

## Sources de métadonnées

TMDB constitue la source externe de référence par défaut pour les contenus auxquels il peut être
appliqué.

Le rapprochement avec une source externe devra distinguer plusieurs états :

- recherche à effectuer ;
- recherche effectuée sans résultat satisfaisant ;
- correspondance proposée mais non validée ;
- correspondance validée ;
- absence volontaire de référence externe.

Lorsqu’aucune correspondance TMDB satisfaisante n’est trouvée, une autre source peut être utilisée. Wikipédia en français peut notamment fournir des informations mieux adaptées à certaines diffusions ou
productions françaises.

La saisie entièrement manuelle constitue le dernier recours.

L’absence volontaire de rapprochement avec une source externe est une exception explicite. Elle ne doit
pas être confondue avec une recherche non effectuée ou infructueuse.

L’identifiant interne de `vidb` restera l’identité durable du contenu. Un identifiant TMDB ou provenant d’une
autre source sera une référence externe et ne remplacera pas cette identité.

## Pays

L’application utilise une association plusieurs-à-plusieurs entre les fiches et
les pays. Une œuvre peut légitimement avoir plusieurs pays de production.

La colonne historique `records.country_id` n’est pas utilisée par l’application. Lors de l’inventaire, aucune
fiche ne la renseignait.

De nombreuses fiches ne possèdent encore aucun pays, presque toujours parce qu’elles n’ont pas été
vérifiées. L’absence de pays doit être traitée comme une donnée à consolider, sans imposer
immédiatement une contrainte incompatible avec l’existant.

## Comportements actuellement caractérisés

Les tests protègent désormais les comportements suivants :

- une hiérarchie peut comporter une série, une saison et un épisode ;
- les titres complets utilisent les titres des ancêtres ;
- les plages d’années et durées agrégées utilisent tous les descendants ;
- la suppression d’un parent supprime actuellement ses descendants ;
- la création d’un enfant recopie les pays, genres, supports et version
  linguistique de son parent ;
- les états enregistré, disponible, visionné et vérifié ne sont pas recopiés ;
- les compteurs d’une saison portent sur ses épisodes ;
- les enfants sont affichés dans l’ordre de leur rang ;
- une fiche doit posséder au moins un titre ;
- une version linguistique est obligatoire ;
- les années et durées respectent les validations actuelles.

Ces tests décrivent le comportement existant. Ils ne signifient pas que chaque comportement devra être
conservé dans le modèle définitif.

## Principes de transition

Les évolutions du modèle respecteront les principes suivants :

1. préserver les fiches et leurs identifiants ;
2. ne pas corriger silencieusement les données ambiguës ;
3. ajouter les nouvelles informations progressivement ;
4. distinguer les faits connus des valeurs déduites ;
5. permettre explicitement un état indéterminé ;
6. conserver temporairement `ancestry` pendant la migration ;
7. n’avoir qu’une représentation faisant autorité à chaque étape ;
8. caractériser les comportements existants avant de les modifier ;
9. effectuer les corrections de données par opérations identifiables et contrôlables ;
10. ne pas introduire les fichiers physiques ni l’intégration avec `video_encoder` avant la stabilisation du catalogue.

## Décisions encore ouvertes

Les points suivants devront être décidés avant les premières migrations
structurelles :

- nom définitif de l’attribut décrivant la nature d’une fiche ;

- distinction exacte entre vidéo autonome et catégories éditoriales ;

- représentation des épisodes sans saison ordinaire ;

- modèle d’appartenance à une ou plusieurs collections ;

- règles de suppression des séries, saisons et collections ;

- remplacement progressif de `rank` ;

- représentation des références TMDB, Wikipédia et autres sources ;

- suivi de la complétude d’une série indépendamment de la vérification de ses
  fiches ;

- stratégie de correction des états enregistré et disponible incohérents.

  