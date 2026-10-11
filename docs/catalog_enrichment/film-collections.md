# Collections de films

Une collection est un conteneur ordonné de fiches vidéo autonomes. Elle utilise
la hiérarchie ancestry existante ; le rang de chaque film fixe son ordre local.
Le film garde son identité, ses copies, ses pays, ses genres, ses années et ses
états de visionnage. Le classement des fichiers sur disque est indépendant.

Une collection peut être créée à la racine. Ses enfants sont des vidéos
autonomes ou des fiches encore à qualifier. Elle ne contient ni saison, ni
épisode, ni série, ni autre collection dans cette première version.

Les synthèses affichent les années, durées, versions, supports et états des
films connus dans vidb. Les pays et genres résultent des films ; les anciennes
valeurs du conteneur restent stockées mais ne sont pas transmises aux films.
Le résumé d’une collection est facultatif. Le bilan distingue les collections
des films et ne leur demande pas de durée, année, support ou langue propres.
Les lacunes des films restent comptées sur les films.

Le formulaire, les filtres et la qualification des enfants proposent ce type.
La contrainte PostgreSQL est étendue par migration. Aucune fiche existante
n’est requalifiée automatiquement lors du déploiement.

James Bond constitue le premier lot de données séparé : fiche 69, films
numérotés 01 à 25 déjà présents dans vidb. Le rang 20 reste occupé par la fiche
« Meurs un autre jour » même si aucun fichier correspondant n’a été relevé dans
le dossier. « Jamais plus jamais », fiche 93 déjà rattachée, reste indépendant.

L’appartenance d’un film à plusieurs collections et les parcours de crossovers
restent des extensions futures. Cette première version conserve le modèle de
conteneur simple et le parent unique convenus.
