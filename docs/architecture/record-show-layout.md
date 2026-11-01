# Présentation d'une fiche de vidéothèque

Le haut de la vue `records/show` distingue deux ensembles :

- Les informations éditoriales : pochette à gauche, titre et actions à droite,
  puis année, durée, genres, pays de production et abrégé.
- Le bloc « Visionnage et copies » : états existants, supports et versions,
  avec un volet natif « Détails des copies » pour les fichiers et leur provenance.

La pochette est affichée sur 240 pixels de large, avec une hauteur maximale de
360 pixels, contre 120 et 180 auparavant. Les proportions sont conservées. Le
partiel garde ses dimensions habituelles si l'option `large` n'est pas fournie.
En l'absence d'image, un emplacement 240 × 360 est réservé avec la mention
« Pochette indisponible ». Sur écran étroit, la colonne image est réduite mais
reste à gauche des informations.

Le volet des copies fonctionne sans JavaScript et au clavier. Le détail de chaque
fichier conserve son propre volet technique. Pour les fiches regroupant des
enfants, les états et durées gardent leurs calculs existants et les fichiers se
consultent dans les fiches enfants. Les tableaux de copies continuent de distinguer
les fichiers présents, introuvables et supprimés.

Le diagnostic de classement reste accessible sur la pastille de nature du contenu ;
la provenance de l'année demeure disponible au second plan. Pour une saison, le texte facultatif reste dans
« Présentation de cette saison ». Aucun texte n'est supprimé ni réécrit.

La partie basse, à partir du lien de retour et comprenant le tableau des enfants,
est conservée à l'identique. Les cibles Stimulus de mise à jour des états et les
attributs d'identification des copies sont préservés.

Ce correctif ne modifie ni les données, ni les fichiers, ni les associations de
montages. Il n'exige aucune migration ou modification de video_encoder.

Validation complète dans le dépôt : `bin/check`. Les tests d'intégration couvrent
la séparation des informations, le détail des copies, la présentation des saisons
et les nouvelles dimensions de pochette.

## Présentation compacte et chargement des styles

Les valeurs éditoriales se lisent sur une ligne qui peut se replier ; les intitulés
restent accessibles aux lecteurs d'écran sans occuper chacun une ligne visible.
Les genres et pays manquants ne créent pas de lignes vides. Le bloc de visionnage
se trouve sous l'abrégé, dans la colonne droite, pour exploiter la hauteur de la
pochette et rapprocher le tableau des enfants du haut de la page. Les compteurs de
visionnage sont mis en valeur et les intitulés apparaissent dans une teinte discrète.

La feuille `app/assets/stylesheets/record_show.css` est chargée explicitement dans
le head de la fiche, via `content_for :head` et le layout. Le manifeste existant
inclut les CSS à la racine des stylesheets. Elle ne dépend donc plus d'une nouvelle
compilation de `application.css` pour apparaître en développement. L'ancien import
SCSS spécifique est retiré pour éviter une double inclusion.

## Informations essentielles

La fiche présente l'année ou l'intervalle retenu en gras, sans suffixe de convention
ni point d'interrogation. L'origine de cette valeur reste consultable en infobulle
et dans l'historique. Aucune année ni preuve existante n'est modifiée.

Les valeurs compactes de `VideoAssets::DisplaySummary` sont utilisées : durée
mesurée des copies présentes en priorité, puis durée renseignée si aucune mesure
n'est connue ; supports et versions sans suffixe « catalogue ». Les incertitudes
de couverture restent représentées par les marqueurs compacts existants (par
exemple ≥ pour un total partiel). Aucun fichier n'est analysé ou modifié par la vue.

Le texte d'aide des pochettes n'est plus répété dans chaque fiche. L'attribution
TMDB est regroupée sur la page « Outils → Crédits ». Les règles de protection des
images personnelles et d'héritage des images de séries restent inchangées.

## Arborescence, nature et titres

La ligne des commandes reste alignée à droite. En dessous, un fil d'arborescence
à 1 rem rassemble les informations de classement et les ancêtres cliquables.
Pour les films, il rappelle la nature et les genres avant le chemin dans les
collections. Pour une série, il suit série, saison et épisode, avec le rang
lorsqu'il est renseigné. Il se replie sans tronquer les titres longs.

Sur la même ligne, à droite, la nature du contenu porte une couleur pastel selon
la conformité du placement : vert, ambre ou rose. Le statut est explicité par
l'infobulle et le libellé accessible, sans dépendre uniquement de la couleur.
Il reprend le diagnostic existant sans modifier la qualification de la fiche.

Le titre principal ne répète plus les parents : titre français (ou original si le
français manque), puis année ou intervalle entre parenthèses. Le titre original
renseigné est présenté en dessous, plus petit. Les métadonnées en gras suivent
l'ordre genres, durée, pays ; les pays sont triés alphabétiquement en neutralisant
les accents. Le synopsis est justifié. Le bandeau de visionnage et les cibles de
mise à jour des copies sont conservés.
