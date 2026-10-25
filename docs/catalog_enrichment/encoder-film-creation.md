# Créer la fiche d’un film à partir du montage

Le titre de la sortie prévue sert à rechercher une fiche vidb existante. Si elle
est absente, le lien proposé dans video_encoder ouvre une recherche extérieure
préremplie dans vidb, sans perdre l’UUID ni les coupures du montage.

La recherche consulte Wikipédia en français en priorité. Si aucun film n’est
identifié, elle consulte TMDB avec la configuration de catalogue existante.
On peut aussi coller directement un lien Wikipédia ou un lien TMDB de film.
Les pages d’homonymie ne deviennent jamais automatiquement des fiches de films.

La page présente les propositions, l’année, les genres, les pays, le résumé et
leur source. Une confirmation explicite crée le film retenu et l’associe au
projet. Les genres principaux sont limités à deux et les références de pays
proviennent du référentiel vidb. L’année suit la première présentation/sortie
répertoriée ; la durée réelle et le support attendent le fichier encodé.

La création conserve les sources dans les provenances de la fiche. Elle ne
déclare aucune copie physique, ne mesure aucune durée et initialise la langue
à IND. Le résumé importé porte une provenance extérieure. La fiche reste
non enregistrée, non disponible et non vue avant l’import du fichier.

Les propositions signées sont liées au compte vidb et au projet et expirent
après deux heures. Rejouer une confirmation ne crée pas une seconde fiche.
Une fiche existante concordante et déjà qualifiée est réutilisée sans réécriture
de ses métadonnées. Les homonymes ou placements non qualifiés restent à arbitrer.

Après confirmation, reprendre l’identification dans video_encoder puis lancer
l’enregistrement ou l’encodage. Pour un film identifié, l’application affiche
année, genres, pays et résumé, puis préremplit la destination avec le titre vidb
et le titre original lorsqu’il diffère. Un répertoire de genre existant sous
`/videos/Films` est proposé s’il correspond au genre ou à la combinaison des deux
genres du film. Aucun genre n’a de priorité générale. En cas d’absence ou
d’ambiguïté du dossier correspondant, le choix du répertoire reste manuel.
Le dialogue habituel permet de modifier le nom ou le répertoire.
Aucune année n’est ajoutée d’office au nom du fichier.

Les projets déjà ouverts restent utilisables : leur association est retrouvée
par UUID. Le choix d’une nouvelle destination intervient avant l’encodage ; une
sortie en cours n’est pas déplacée ou renommée par ce parcours. La confirmation
des sources avant quarantaine reste indépendante.

Les requêtes Wikipédia et leurs réponses ne créent aucun fichier JSON durable.
Le cache TMDB existant reste sous `tmp/encoder-film-search`. Aucune migration ni
nouvelle configuration de passerelle n’est nécessaire.

Ce parcours extérieur crée des films autonomes. Les épisodes continuent de
passer par l’identification dans leur série et leur saison et par la consolidation
de leur hiérarchie ; ils ne sont pas créés comme films à partir de leur titre seul.
