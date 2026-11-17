# Changer de version d’une copie

L’action « Changer de version… » apparaît sur les copies MKV présentes d’une
vidéo autonome ou d’un épisode qualifié. Elle ouvre video_encoder via le lanceur
existant ; elle ne modifie pas la version de la copie et ne démarre pas un
encodage dans Rails. L’entrée générique est aussi disponible dans Montage.

La copie est choisie explicitement, contrairement à une préparation depuis une
fiche seule. Le ticket réutilise le périmètre du compte et de la fiche, contient
l’identifiant de copie, et renvoie son chemin via l’API authentifiée. Une copie
disparue ou rattachée à une autre fiche est refusée lors de la résolution.

video_encoder propose un remultiplexage VOST lorsque l’utilisateur confirme la
piste originale à l’écoute et les sous-titres français déjà incrustés. La vidéo et
l’audio sélectionnés sont conservés sans réencodage. Le travail rejoint la file
existante et produit une nouvelle copie.

Le reçu de succès conserve cette déclaration explicite. L’import normal des
exports contrôle le fichier et ses pistes avant d’attribuer VOST à la nouvelle
copie. L’absence de piste de sous-titres seule n’implique jamais VOST.
La copie source et sa version restent inchangées. Les conditions de conservation
de la source connue sont reprises sur la nouvelle copie de la même œuvre.

La synchronisation de la nouvelle copie intervient lors de l’actualisation
habituelle de l’inventaire et des exports terminés. Modifier la version dans une
fiche ou qualifier sa copie reste une correction de catalogue, sans traitement
du fichier.
