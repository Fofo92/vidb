# Propositions globales de métadonnées pour les films

Cet incrément ajoute la recherche de films par titre et la préparation de
propositions par champ. Il n'écrit ni fiches, ni associations, ni chemins vidéo.
Le client TMDB des séries est réutilisé par une sous-classe sans être modifié.
Les variables TMDB_READ_ACCESS_TOKEN ou TMDB_API_KEY existantes sont utilisées ;
aucun secret n'est conservé dans les rapports ou réponses mises en cache.

## Rapprochement

Les titres français et original renseignés sont recherchés sans imposer l'année
locale, qui peut être une année de production erronée. Les pages sont lues jusqu'à
20 par titre ; une recherche plus grande ou un résultat qui s'élargit en cours de
lecture reste explicitement incomplet. Les identifiants trouvés plusieurs fois
sont regroupés avant comparaison. Un candidat doit avoir un titre français
ou original normalisé concordant, au moins cinq termes significatifs partagés
avec le résumé local, un recouvrement d'au moins 50 % du plus court ensemble
de termes et une année proche à deux ans lorsque l'année locale existe.
Ce calcul est une heuristique explicite, pas une preuve sémantique absolue.
Le détail de chaque critère reste dans le rapport. Deux candidats concordants,
un résumé insuffisant, une identité absente ou une recherche incomplète
restent needs_review ; le premier résultat n'est jamais choisi par rang.
Les détails du film sélectionné sont rapprochés à nouveau avant proposition.
Le résumé externe reste dans les comparaisons dont titre et année concordent,
afin de permettre l'examen du rapprochement sans réécrire le résumé local.

## Champs

- L'année vient maintenant des événements movie/ID/release_dates, et non de la
  seule date principale release_date. La plus ancienne présentation/sortie publique
  répertoriée est retenue : première (type 1), salles limitées ou générales (2/3),
  numérique (4), télévision (6). L'édition physique (5) est exclue. Une première
  en festival peut donc précéder l'année de sortie générale : c'est une première
  présentation publique, pas une année de production. Les pays, types, dates
  retenues et l'ancienne date principale figurent dans la preuve. Sans événement
  public exploitable, aucune confirmation silencieuse par la date principale.
  Les dates invalides, futures, antérieures à 1900 ou éloignées de plus de deux
  ans de la saisie locale restent à examiner.
  Une provenance déjà présente est protégée, même si sa base est unknown.
  La diversité des conventions de sortie reste visible ; une sortie française
  ne doit pas être confondue implicitement avec une première sortie originale.
- Pour une fiche sans genre, seuls un ou deux genres TMDB reconnus et présents
  dans le dictionnaire local peuvent produire une proposition. Trois genres
  ne sont jamais tronqués. Un documentaire, une catégorie inconnue ou un genre
  spécifique comme Espionnage peut nécessiter une autre source et un argumentaire.
- Les genres déjà renseignés sont conservés : concordance signalée, divergence
  protégée. Cet incrément n'a pas encore de provenance générique des genres
  permettant de distinguer une correction manuelle d'un ancien import.
- Les résumés restent intacts, y compris les corrections ou suppressions
  manuelles. Le service de protection éditoriale existant n'est pas contourné.
- Aucune langue de copie n'est déduite du catalogue externe.

Le statut candidate signifie proposition suffisamment étayée pour la prochaine
étape de qualification ; il ne constitue ni un enregistrement ni une autorisation
de déplacement. Le futur applicateur devra vérifier le cliché local, protéger
les provenances et journaliser les changements avant de reconstruire les chemins.

## Préparation reprenable

`bin/rails runner script/prepare_film_metadata_proposals.rb GLOBAL_REPORT.json`

L'entrée est le rapport global complet des films. Les copies sont regroupées
par fiche, sans limite de cinq candidats ni plafond de 250 copies. Chaque fiche
est comparée à un instantané PostgreSQL en lecture seule, puis la transaction
est fermée avant toute requête externe. Un changement du cliché interrompt la
préparation pour empêcher de reprendre une décision sur des métadonnées anciennes.

Les réponses TMDB sont sous tmp/tmdb-film-cache. Les propositions terminées
sont sous tmp/film-metadata-proposals/EMPREINTE_RAPPORT/v2/record-ID.json, puis
report.json rassemble l'ensemble. Sur la production, tmp est partagé entre les
releases. Ces données de travail sont conservées pour les reprises. Les propositions v1 sont conservées dans leur répertoire initial. Le verrou
.lock empêche deux préparations concurrentes du même relevé. Les publications
JSON utilisent un fichier temporaire puis un renommage atomique.

Une interruption HTTP, dont 429, arrête proprement la préparation. Les fiches
terminées et les réponses restent disponibles pour une relance ; le script
n'impose pas une succession de petits lots ni un recommencement global.
Les rapports ne conservent pas les en-têtes d'authentification et les erreurs
n'affichent pas d'URL contenant une clé. Ne jamais transmettre le fichier env.

## Vérification

Les cinq services ont des tests sans réseau ni clé. Ils couvrent les titres
contenant des caractères réservés, le cache distinct par recherche, les erreurs
HTTP, le refus d'endpoints inattendus, les homonymes, les dates, les corrections
protégées et les listes de genres trop nombreuses. La suite Rails complète doit
être lancée sur le dépôt avant publication. Aucun schéma n'est modifié.

Sources officielles :
https://developer.themoviedb.org/reference/search-movie
https://developer.themoviedb.org/reference/movie-details
https://developer.themoviedb.org/reference/movie-release-dates

Données fournies par TMDB. Cette intégration n'est ni approuvée ni certifiée par
TMDB. L'attribution devra accompagner la future consultation dans les vues.
