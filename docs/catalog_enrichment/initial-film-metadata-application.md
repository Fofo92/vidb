# Premier enrichissement des films

Application des seules propositions v2 identifiées de façon unique et étayées.
Le manifeste fixe les preuves et l’état initial attendu de chaque fiche.

## Portée

Au maximum 654 qualifications d’année de première diffusion publique, dont 72
changements de valeur numérique, et 242 compléments de genres initialement vides.
Les genres présents sont conservés, sans écrêtage des propositions à deux genres.
Six fiches signalées pour une classification plus spécifique ne reçoivent aucun
genre automatique ; leur année peut néanmoins être qualifiée.
Aucun résumé, pays, langue, état de disponibilité ou fichier vidéo n’est modifié.
Les anciennes valeurs et preuves d’année sont archivées par RecordYears.

## Protection et reprise

La prévisualisation utilise des transactions PostgreSQL en lecture seule.
L’application verrouille une fiche par transaction et compare les titres, l’année,
les preuves, les genres et le résumé à l’état observé. Tout écart protège la fiche.
Un historique d’année préexistant protège aussi les corrections anciennes.
Les validations Rails sont vérifiées avant l’écriture ; une ancienne fiche devenue
invalide est signalée et les autres peuvent continuer. Une exception imprévue
arrête le lot ; les transactions précédentes restent acquises.

Un journal privé par fiche, sous /srv/vidb/shared/film-metadata-journal, conserve
la préparation puis la confirmation après commit. Le marqueur d’opération dans
les preuves d’année permet de reprendre après une interruption sans réappliquer
une modification déjà commise. Les corrections et suppressions manuelles
ultérieures restent protégées. Ne pas effacer les journaux pour forcer une reprise.
Les journaux ne remplacent pas la sauvegarde PostgreSQL préalable.

Cette procédure concerne le premier enrichissement de ce manifeste. Elle ne
constitue pas une politique générale de rafraîchissement automatique des genres.

## Exécution

Le paquet installe les sources dans vidb-clean et exécute bin/check. Le lanceur
charge ces services dans un processus Rails séparé sous l’utilisateur vidb, sans
changer la release web. Il réalise la prévisualisation, une seule sauvegarde si
des fiches sont prêtes, puis l’application et un nouvel audit des chemins.
Aucun déplacement physique n’est exécuté par ce paquet.
Les rapports de travail sont conservés dans Rails.root/tmp/film-metadata-application
et copiés sous /tmp pour consultation. Les fichiers temporaires de transfert
restent sous /tmp ; les sources et tests sont destinés au dépôt Git.
