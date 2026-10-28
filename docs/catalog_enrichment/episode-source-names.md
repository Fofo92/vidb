# Noms de captures d’épisodes et concordance SensCritique

Le repérage d’un épisode reconnaît les numéros compacts (`S09 E06`, `S09E06`)
et les libellés français (`Saison 9, épisode 6`, `saison 9 episode 6`).
Les majuscules, les accents d’« épisode » et les tirets usuels sont acceptés.
Le titre de série est extrait avant ce repère ; un éventuel titre d’épisode
est conservé après le numéro. Une cible de saison/épisode explicitement choisie
continue de prendre priorité sur les numéros du fichier.

Une capture telle que `La stagiaire — Saison 9, épisode 6.m2t` est donc dirigée
vers le parcours des épisodes même si le nom de sortie provisoire est encore
`montage.mkv`. La recherche de films n’est pas lancée à cette étape.

Une saisie explicite telle que `La stagiaire - S09 E06 - Errance` prend aussi
priorité sur le nom de capture, même générique, et sur une ancienne cible.
Le catalogue redirige vers le formulaire d’épisode avec un nouveau lien signé
contenant cette saisie, sans modifier les chemins du montage. Le formulaire
recherche la série `La stagiaire` et conserve `S09 E06` et `Errance` ; il ne
recherche pas la chaîne complète comme un titre de série. La même correction
est acceptée directement dans le champ de recherche du formulaire d’épisode.
Un nouveau choix explicite des numéros dans ce formulaire reste prioritaire.

Indépendamment de ce routage, les liens de films trouvés sur une page de
recherche SensCritique ne deviennent pas des propositions sans concordance de
titre français ou original. Casse, ponctuation et accents sont normalisés.
Une année demandée entre parenthèses doit également correspondre. Les liens
de recommandations sans rapport sont écartés avec un avertissement explicite.
Les liens directs vers un film restent utilisables sans recherche de titre.

Ainsi, `Obsession` ou `L’Odyssée` ne sont pas des propositions valides pour une
recherche `La stagiaire - S09 E06 - Errance`. Si aucune fiche ne concorde, le
catalogue affiche l’absence de résultat plutôt qu’une suggestion arbitraire.

Le cas de régression vérifie `S09 E06 → Errance (2024)` à partir de la liste de
la saison 9 dans l’article Wikipédia de `La Stagiaire`. La série correspond à
la référence TV TMDB `70183`. Ces références documentent le test, sans imposer
un identifiant ou un titre particulier au code de recherche.
