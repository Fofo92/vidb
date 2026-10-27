# SensCritique dans la préparation des films

La recherche des films consulte Wikipédia puis TMDB. Si TMDB ne propose aucun film,
elle consulte aussi SensCritique. Un lien
`https://www.senscritique.com/film/.../identifiant` consulte directement cette
fiche, sans rechercher le titre de l’URL dans les autres catalogues. Il ne faut
ni clé d’API ni compte SensCritique.

Les résultats restent des propositions distinctes à confirmer : un titre seul
ne suffit pas à fusionner des œuvres homonymes. La priorité de Wikipédia pour
l’identité et de TMDB pour un synopsis concordant reste inchangée. SensCritique
peut fournir le synopsis concordant lorsqu’il manque dans TMDB.

Le lecteur utilise les métadonnées publiques structurées Movie (JSON-LD) :
titre, titre alternatif, année, pays, genres et description. Sans ces données,
un titre OpenGraph explicitement marqué Film ou Téléfilm permet seulement une
proposition partielle ; les autres champs ne sont pas inventés. Aucune critique
d’utilisateur ni note n’est importée. Les genres proposés passent par la
sélection vidb habituelle, avec deux genres maximum après confirmation.

Les indisponibilités, refus HTTP et changements de structure sont signalés
dans le formulaire sans supprimer les propositions Wikipédia ou TMDB. Les
redirections ne sont pas suivies. Seuls les liens HTTPS du domaine SensCritique
vers des fiches de films sont lus ; les réponses sont limitées en taille.
Aucune donnée intermédiaire n’est conservée sur disque.

La confirmation emploie le jeton signé, la réutilisation des fiches existantes
et la transaction déjà utilisés pour les autres films. La recherche n’écrit pas
dans la base. Les états, support, langue et durée mesurée sont déterminés à
l’import du fichier encodé, comme auparavant.

Périmètre : films et téléfilms. Les pages de séries et d’épisodes SensCritique
ne sont pas encore prises en charge par ce lecteur.

## Vérification

`bin/rails test test/services/encoder_projects/senscritique_catalogue_test.rb test/services/encoder_projects/senscritique_film_test.rb test/services/encoder_projects/film_catalogue_test.rb`

Les tests utilisent des pages simulées : ils vérifient le lecteur et le parcours
sans dépendre de la disponibilité du site. Pour le contrôle réel, rechercher
Impossible ou coller `https://www.senscritique.com/film/impossible/139932052` dans
le formulaire. Vérifier l’identité avant confirmation ; en cas de refus HTTP,
le formulaire indique que SensCritique est indisponible.
