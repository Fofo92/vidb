# Durée catalogue et contexte des recherches

Le formulaire d’édition masque le contrôle de durée catalogue lorsque toutes
les copies présentes sont mesurées et que toutes les durées complètes sont
strictement à moins de 10 % de la durée catalogue. L’écart relatif est calculé
par rapport à la durée catalogue. À exactement 10 %, le contrôle reste visible.
Les parties d’une même diffusion sont additionnées avant comparaison et doivent
être complètes. Les copies supprimées n’interviennent pas. Une mesure manquante,
une partie manquante ou une durée catalogue absente conserve le contrôle.
La durée catalogue stockée n’est ni recalculée, ni effacée, ni remplacée.

La colonne historiquement nommée Correspondance ne désignait pas un lien avec
un fichier vidéo. Elle distinguait les fiches répondant aux filtres et les
fiches de contexte ajoutées par le mode d’affichage des arborescences.
Elle est désormais nommée Recherche, avec les valeurs Résultat et Arborescence,
et n’apparaît que lorsque des fiches de contexte sont effectivement incluses.

Le test de modification à taille constante du renommage force explicitement
un changement de mtime : une écriture très rapprochée ne garantit pas une
variation observable des horodatages. Il conserve la même taille et vérifie
que l’identité de métadonnées diffère avant d’attendre le refus. Cela ne
transforme pas le contrôle de métadonnées en comparaison intégrale du contenu.
