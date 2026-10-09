# Import des parties de Blanca

Les 18 fiches représentent les épisodes originaux. Le champ broadcast_part_count
déclare deux parties ; chaque VideoAsset porte broadcast_part_number 1 ou 2.
Une copie complète a un numéro de partie nul. La provenance conserve M6, la
confirmation de Pascal et le numéro local du fichier. Aucune fiche n'est créée
ou fusionnée, aucun fichier n'est déplacé ou supprimé.

Disponibilité : une copie complète présente ou toutes les parties présentes.
Enregistré : un épisode a déjà été complet au moins une fois ; l'historique reste
vrai après suppression. Plusieurs encodages d'une même partie ne complètent pas
l'épisode. Les informations personnelles existantes restent conservées.

Durée : somme des durées précises des parties, puis arrondi à la minute. Plusieurs
copies d'une partie donnent une plage d'alternatives, pas une somme. Une partie
seule ne donne pas une durée complète ; une copie entière reste une alternative.
Les durées catalogue ne sont pas écrasées. Les versions linguistiques des copies
restent non qualifiées par cet import.

Le manifeste contient 36 fichiers et 18 paires du scan du 9 octobre. Les seules
corrections éditoriales sont Blu profonde → Blu profondo et Chien troisCan →
Chien trois, confirmées par Pascal. Le doublon Fantômes partie 2 en quarantaine
sous /commun reste hors du lot.

L'import prévisualise puis vérifie le catalogue, chaque fichier, son volume et
sa stabilité. Une transaction globale protège titres, types, déclarations de
parties, copies et états. Une relance réutilise les copies aux mêmes chemins.
Après application, actualiser le journal durable pour voir progresser l'accueil.

```sh
bin/rails runner script/import_broadcast_parts.rb EVIDENCE.json OUTPUT.json
bin/rails runner script/import_broadcast_parts.rb EVIDENCE.json OUTPUT.json --apply
```
