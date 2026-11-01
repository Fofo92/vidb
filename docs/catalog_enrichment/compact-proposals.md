# Identification compacte et sources concordantes

Les recherches TMDB films/séries éliminent les répétitions d’identifiant avant
de limiter le nombre de résultats et de charger les fiches détaillées. Deux
identifiants TMDB distincts sont toujours conservés, même avec le même titre.

Une carte Wikipédia et une carte TMDB sont regroupées uniquement si leurs titres
français et originaux normalisés concordent, que leur année renseignée est
identique et que la correspondance est unique dans les deux sens. C’est le cas
de la fixture « La Maison du docteur Edwardes » / « Spellbound » (1945). Un titre
seul, une année absente, un remake ou plusieurs candidats concordants empêchent
le regroupement. L’identité Wikipédia, le synopsis choisi et les valeurs
éditoriales sont conservés ; la carte expose les deux liens de source et reprend
l’affiche TMDB. Cette présentation n’écrit aucune fiche ni association.

Les listes Genres principaux / Pays de production affichent trois lignes dans
les formulaires films et épisodes. Le contrôleur Stimulus `encoder-choices`
centre le défilement initial sur la première valeur proposée, sans modifier les
sélections, déplacer le focus ni retirer d’option. Les champs de chaque carte
ont des identifiants distincts. Toutes les valeurs restent accessibles au clavier
et par défilement ; le contrôle existant des deux genres maximum est conservé.

L’affiche, lorsqu’un `poster_path` TMDB est disponible, utilise exclusivement
`https://image.tmdb.org/t/p/w185/…`, en vignette de 92 × 138 pixels avec
chargement différé. Les chemins invalides ou absents ne créent aucun emplacement
vide ; une erreur de chargement masque la figure. Le libellé « Affiche TMDB »
indique la provenance. L’image reste une aide visuelle, pas une preuve d’identité.
Les séries et les propositions TMDB d’épisodes peuvent également afficher
l’affiche de leur série. Aucune requête TMDB supplémentaire n’est nécessaire.

Les cartes réduisent marges et espacements, remplacent les URL longues par des
liens nommés et évitent de répéter genres/pays au-dessus des sélecteurs. Le résumé
reste visible et la confirmation du montage conserve son fonctionnement.

Vérifications : tests de regroupement/ambiguïté, d’URL d’affiche, de recherches
sans répétitions et tests de rendu du formulaire. Le centrage peut être vérifié
indépendamment avec `node test/javascript/encoder_choices_test.mjs`.
