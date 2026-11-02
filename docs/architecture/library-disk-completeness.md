# Recherche des ensembles complets sur disque

Le filtre « Complétude sur disque » s’applique aux collections, séries et
saisons, ainsi qu’aux arbres historiques ayant des enfants. Il se combine
avec la nature, le titre, l’arbre et les autres critères habituels.

- **Complets** : chaque œuvre terminale connue dans vidb a une copie confirmée
  à l’état `present`. Pour une œuvre répartie sur plusieurs fichiers, toutes
  les parties attendues doivent être présentes, ou une copie entière.
- **Incomplets** : au moins une œuvre connue n’a pas cette couverture. Une
  ancienne case `is_available` ou `is_recorded` cochée ne suffit jamais.
- **Indéterminés** : ensemble vide ou branche vide, sans œuvre attendue
  renseignée, et sans autre absence déjà établie.

Plusieurs encodages du même épisode ne compensent pas un autre épisode absent.
Les copies `missing` et `deleted` ne contribuent pas à la couverture. Les
feuilles sans copie confirmée sont non couvertes, même si un fichier encore
non rapproché pourrait se trouver sur le disque. Il faut alors rapprocher ce
fichier dans vidb avant que la complétude puisse le prendre en compte.

Le calcul lit les états des copies établis par le dernier inventaire et les
imports confirmés, avec les associations préchargées. Il ne parcourt pas /videos
pendant une recherche et ne modifie ni les fichiers, ni les tâches d’encodage.
Après un effacement manuel récent, demander l’actualisation de l’inventaire
pour disposer d’un état à jour. Aucune référence aux suffixes de progression
des noms de dossiers : ils peuvent être anciens.

La complétude porte sur **les œuvres connues dans vidb**. Elle ne prouve pas
qu’une collection contient tous les films ou qu’une série contient tous les
épisodes existants. Une fiche James Bond ne décrivant que deux films présents
est complète pour ces deux fiches connues. Détecter les épisodes ou films non
encore décrits nécessiterait une comparaison de catalogue distincte.

L’affichage « Arbres des fiches correspondantes » conserve son fonctionnement :
il peut ajouter des fiches de contexte qui ne répondent pas au filtre. Les
étiquettes de contexte existantes continuent de les distinguer.

## Formulaire condensé

Les contrôles principaux se répartissent sur deux lignes aux grandes largeurs,
avec des champs et boutons Bootstrap `sm`, des espacements et marges réduits.
Le titre, la nature, la complétude, l’arbre et le mode d’affichage restent au
premier niveau ; pays, genre, version, support et année restent immédiatement
accessibles. Le formulaire se replie en colonnes sur les petits écrans.

Les critères « Information manquante » et « À consolider », ainsi que l’aide,
sont regroupés dans un volet compact. Ce volet est ouvert automatiquement si
l’un de ses filtres est actif. Aucun critère ni identifiant de champ existant
n’est supprimé ; les valeurs sont conservées après recherche.

Tests : `record_completeness_test.rb`, ajouts dans `record_index_filter_test.rb`
et `record_completeness_filter_test.rb`. Aucune migration ni passerelle à installer.
Déploiement normal de vidb ; video_encoder peut continuer à fonctionner.
