# Qualification des genres et rangement vidéo

Décisions confirmées avec Pascal le 16 octobre 2026. Ce document est le point
de reprise pour éviter de réinterpréter ces règles à chaque changement de chat.

- Une fiche qualifiée porte un ou deux genres au maximum.
- Les genres doivent caractériser l'œuvre. Ils déterminent le dossier de rangement.
- L'assistant tranche les cas clairs sans demander un accord supplémentaire.
- Pour les cas difficiles à trancher seulement, il présente des propositions
  argumentées et attend la validation de Pascal avant la modification.
- Un dossier existant constitue un indice, pas une qualification validée.
- Archives de transfert, patches et scripts ponctuels : `/tmp` sur Zeus.
- Services, tests, documentation et scripts réutilisables : dépôt Git.

## Cas acquis : 355

- Fiche : `3879`, titre français `355`, titre original `The 355`, année `2022`.
- Type : `standalone_video`.
- Ancienne qualification à remplacer : `Action`, `Aventure`, `Thriller`.
- Genre retenu : **Espionnage**, sans nouvelle demande de validation.
- Copie confirmée : `1445`.
- Chemin observé : `/videos/Films/Espionnage/355 (The 355)_vf.mkv`.
- Cible issue de cette qualification :
  `/videos/Films/Espionnage/355 (The 355) (2022).mkv`.

L'incrément 9 initial est retiré : ignorer les genres pour préserver le dossier
aurait laissé la fiche incorrecte. Revenir à la construction canonique des
incréments 1 à 8 et corriger d'abord la qualification en base.

La correction des genres ne renomme aucun fichier et ne modifie aucun chemin
de copie. Elle est suivie d'un nouvel aperçu en lecture seule. Les exécuteurs
et mécanismes de reprise développés à ce stade restent réservés aux essais.
Le renommage réel ne doit pas utiliser directement ces classes d'essai.
