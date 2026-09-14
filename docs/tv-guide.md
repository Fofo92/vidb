# Modèle du guide TV

Ce document définit la représentation du guide TV dans `vidb`.

Il complète `docs/media-lifecycle.md` et prépare l’import persistant des documents XMLTV. Il ne définit
pas encore la programmation des captures ni le dialogue avec Kaffeine.

## Objectif et périmètre

La première tranche doit permettre :

- d’importer un document XMLTV local ;
- d’identifier sa source ;
- de rapprocher ses chaînes des chaînes métier connues par `vidb` ;
- de conserver les observations annoncées par le guide ;
- de mesurer la couverture et les lacunes de chaque chaîne ;
- de consulter les programmes d’une journée ;
- de connaître la provenance et la fraîcheur des informations affichées.

L’import ne doit pas :

- créer automatiquement des fiches `Record` ;
- considérer une annonce comme une diffusion réellement constatée ;
- créer une intention d’enregistrement ;
- programmer Kaffeine ;
- effacer l’historique des imports précédents.

## Principes généraux

Un document XMLTV constitue un instantané fourni par une source à un moment donné.

Il ne représente pas directement la vérité métier. Il contient des affirmations de la source concernant des
chaînes, des horaires et des programmes.

Les identités suivantes doivent rester distinctes :

- la chaîne métier connue par `vidb` ;
- la source du guide ;
- l’identifiant d’une chaîne dans cette source ;
- l’import d’un document ;
- l’observation d’un programme annoncée par la source ;
- la présence de cette observation dans un import déterminé.

Une observation identique peut apparaître dans plusieurs imports successifs. Elle ne doit pas
nécessairement être dupliquée intégralement à chaque import.

Le document XMLTV est une entrée d’import, et non une donnée métier conservée sous forme de fichier.
Les informations utiles sont validées puis enregistrées dans des colonnes relationnelles ou JSONB
documentées. Le fichier source peut être supprimé après un import réussi, sauf politique explicite
d’archivage à des fins de diagnostic.

## Chaîne métier

Une chaîne métier représente une chaîne de télévision indépendamment de la source qui la décrit.

Le nom conceptuel pressenti est `Tv::Channel`.

Elle pourra notamment conserver :

- son nom d’affichage dans `vidb` ;
- son état actif ou inactif ;
- ultérieurement, les informations nécessaires à la réception et à la programmation technique.

Le nom destiné à l’utilisateur reste distinct du nom technique éventuellement attendu par Kaffeine.

Par exemple, le nom affiché pourra être `France 3` même si un outil externe utilise une autre désignation.

Une chaîne métier peut être reliée à plusieurs identifiants provenant de plusieurs sources de guide.

## Source du guide

Une source représente un fournisseur ou un mode d’obtention des données du
guide.

Le nom conceptuel pressenti est `Tv::GuideSource`.

Elle pourra notamment conserver :

- un nom interne ;
- un libellé d’affichage ;
- son état actif ou inactif ;
- son fuseau horaire attendu ;
- des informations de configuration non sensibles ;
- la date de son dernier import réussi.

Les secrets éventuels ne devront pas être enregistrés directement dans cette table.

XML TV Fr constituera la première source configurée.

## Chaîne déclarée par une source

Une chaîne déclarée par une source représente l’identité externe utilisée dans les documents de cette
source.

Le nom conceptuel pressenti est `Tv::GuideChannel`.

Elle appartient à une source et conserve notamment :

- l’identifiant externe exact ;
- les noms observés dans les documents importés ;
- son rapprochement facultatif avec une chaîne métier.

Le couple formé par la source et l’identifiant externe doit être unique.

Le rapprochement avec une chaîne métier ne doit pas reposer uniquement sur le nom affiché. Il peut être
proposé automatiquement, mais doit pouvoir être confirmé ou corrigé.

Une chaîne externe non encore rapprochée doit pouvoir être importée sans créer automatiquement une
nouvelle chaîne métier.

## Import du guide

Un import représente la réception et le traitement d’un document provenant d’une source.

Le nom conceptuel pressenti est `Tv::GuideImport`.

Il pourra notamment conserver :

- la source ;
- l’empreinte cryptographique du document reçu ;
- sa taille en octets ;
- son état ;
- le début et la fin du traitement ;
- les métadonnées déclarées par le document ;
- le nombre de chaînes rencontrées ;
- le nombre total de programmes lus ;
- le nombre de programmes retenus ;
- le nombre de doublons éliminés ;
- les informations relatives à une erreur éventuelle.

Les états pressentis sont :

- `running` ;
- `succeeded` ;
- `failed`.

Un document déjà importé avec succès pour la même source ne doit pas créer un nouvel import
fonctionnel ni dupliquer ses observations.

Une tentative en échec ne doit pas empêcher une nouvelle tentative du même document.

Le chemin du fichier importé n’est pas son identité. L’empreinte et la source permettent d’identifier son
contenu de manière durable.

## Couverture d’une chaîne importée

La couverture décrit ce qu’un import contient pour une chaîne externe déterminée.

Le nom conceptuel pressenti est `Tv::GuideImportChannel`.

Elle pourra conserver :

- l’import ;
- la chaîne externe ;
- les noms observés dans cet import ;
- le nombre de programmes ;
- le premier horaire couvert ;
- le dernier horaire couvert ;
- le nombre de lacunes détectées ;
- la durée totale des lacunes ;
- le détail structuré de ces lacunes.

Cette information appartient à l’import. Deux imports successifs peuvent offrir des couvertures différentes
pour la même chaîne.

Une lacune signifie seulement qu’aucun programme ne couvre un intervalle dans le document. Elle ne
prouve pas une absence réelle de diffusion.

Les chevauchements entre programmes ne doivent pas être transformés en fausses lacunes.

## Observation d’un programme

Une observation représente l’annonce d’un programme par une source, sur une chaîne externe et pendant
un intervalle donné.

Le nom conceptuel pressenti est `Tv::BroadcastObservation`.

Elle pourra notamment conserver :

- la chaîne externe ;
- une empreinte déterministe ;
- le début annoncé ;
- la fin annoncée ;
- les valeurs temporelles brutes de la source ;
- les titres localisés ;
- les sous-titres localisés ;
- les descriptions localisées ;
- les catégories ;
- les numérotations d’épisodes et leurs systèmes ;
- les autres métadonnées sources utiles.

Les valeurs multilingues ou multiples pourront être conservées sous une forme structurée, notamment en
JSONB, sans perdre leur langue ni leur système d’origine.

La fin doit être strictement postérieure au début.

Une observation reste une affirmation de la source. Elle ne constitue pas encore une `Tv::Broadcast`
durable et ne prouve pas qu’une diffusion réelle a eu lieu.

## Présence d’une observation dans un import

La relation entre un import et une observation doit être explicite.

Le nom conceptuel pressenti est `Tv::GuideImportObservation`.

Cette relation permet :

- de savoir dans quels imports une observation est apparue ;
- de partager une observation identique entre plusieurs instantanés ;
- de déterminer les observations présentes dans le guide courant ;
- de conserver la disparition d’une annonce dans un import ultérieur sans supprimer son histoire.

Le couple formé par l’import et l’observation doit être unique.

La disparition d’une observation dans un nouvel import ne provoque aucune suppression de l’observation
historique.

## Déduplication et empreinte

Deux nœuds XML strictement identiques dans un même document sont considérés comme des doublons
de source.

Le lecteur XMLTV élimine déjà ces doublons tout en comptabilisant leur nombre.

Pour la persistance, une empreinte déterministe devra représenter les informations significatives de
l’observation, notamment :

- la source et la chaîne externe ;
- le début et la fin ;
- les titres et sous-titres ;
- les descriptions ;
- les catégories ;
- les numérotations d’épisodes.

La représentation utilisée pour calculer cette empreinte devra être normalisée, stable et versionnée.

Une correction d’horaire ou de métadonnées produira une autre observation. Aucune règle heuristique ne
devra fusionner automatiquement deux observations simplement parce que leurs titres ou leurs horaires
sont proches.

## Atomicité et reprise après erreur

La lecture et la validation du document doivent avoir lieu avant l’écriture définitive de ses données métier.

La persistance d’un import réussi doit être atomique :

- soit l’import, ses couvertures, ses observations et leurs relations sont enregistrés ensemble ;
- soit aucune donnée partielle n’est présentée comme un import réussi.

Un échec doit conserver suffisamment d’informations pour être diagnostiqué, sans remplacer le dernier
import réussi.

Les imports concurrents d’un même document doivent respecter l’idempotence et ne pas créer deux
instantanés réussis équivalents.

La stratégie exacte de verrouillage sera définie et testée lors de l’implémentation.

## Temps et fuseau horaire

Les horaires persistés doivent représenter des instants absolus, avec des colonnes PostgreSQL compatibles
avec les fuseaux horaires.

Les valeurs XMLTV brutes doivent être conservées lorsqu’elles sont utiles au diagnostic.

L’affichage et la navigation journalière utiliseront le fuseau `Europe/Paris`.

Une journée de guide est donc délimitée par le début et la fin de la journée civile en France, y compris lors
des changements d’heure.

Un programme appartient à une journée affichée dès que son intervalle chevauche cette journée. Un
programme commencé la veille mais se terminant après minuit doit donc apparaître.

## Consultation du guide courant

Le guide courant d’une source correspond à son dernier import réussi.

Un import en cours ou en échec ne doit jamais remplacer ce guide courant.

La consultation doit permettre de connaître :

- la source utilisée ;
- la date de l’import ;
- la période couverte ;
- les chaînes rapprochées ou non ;
- les lacunes détectées ;
- la fraîcheur des informations.

Les observations du guide courant pourront être filtrées :

- par chaîne métier ;
- par chaîne externe ;
- par journée dans `Europe/Paris` ;
- par chevauchement avec un intervalle donné.

L’interface graphique hebdomadaire sera construite ultérieurement à partir de ces requêtes. Le premier
affichage pourra rester journalier et simple.

## Articulation avec les contenus catalogués

L’import XMLTV ne crée pas automatiquement de `Record`.

Une observation pourra ultérieurement fournir des indices pour rechercher un contenu :

- titre français ;
- titre original ;
- année ;
- série ;
- saison ;
- épisode ;
- description.

Ces indices pourront alimenter une recherche TMDB ou une autre source.

Le résultat de cette recherche devra rester distinct de l’observation brute.
Une association validée reliera un contenu interne à une observation ou à une future diffusion.

## Articulation avec les intentions d’enregistrement

La sélection d’un programme dans le guide créera ultérieurement une intention d’enregistrement distincte
de l’observation.

Cette intention conservera l’information choisie au moment de la décision, même si un import ultérieur
modifie ou retire l’annonce.

La modification du guide ne devra donc ni déplacer silencieusement une programmation existante ni la
supprimer automatiquement.

Les règles de réconciliation, les marges, les conflits de tuners et le dialogue avec Kaffeine appartiennent à
une phase ultérieure.

## Décisions différées

Les décisions suivantes ne sont pas nécessaires au premier import persistant :

- l’identité durable d’une diffusion `Tv::Broadcast` ;
- le rapprochement automatique d’observations successives ;
- la création des intentions d’enregistrement ;
- les règles de réaction aux modifications du guide ;
- le calcul des quatre multiplex simultanés ;
- la programmation et la vérification dans Kaffeine ;
- le rapprochement avec TMDB ;
- l’association avec les captures et les fichiers physiques ;
- la durée de conservation ou la purge éventuelle des anciens imports.

Ces reports doivent rester explicites afin de ne pas introduire prématurément
des identités ou des automatisations incertaines.

## Première trajectoire d’implémentation

La persistance sera introduite par petits lots cohérents :

1. chaîne métier, source et chaîne externe ;
2. import et états de traitement ;
3. observations dédupliquées et relation avec les imports ;
4. couverture par chaîne ;
5. service d’import atomique et idempotent ;
6. sélection du dernier import réussi ;
7. consultation journalière en `Europe/Paris`.

Chaque lot devra comporter :

- ses migrations ;
- ses contraintes PostgreSQL ;
- ses validations Rails ;
- ses tests de modèle ou de service ;
- un contrôle par `bin/check` ;
- un commit autonome.

Aucune programmation Kaffeine ne sera introduite dans ces lots.