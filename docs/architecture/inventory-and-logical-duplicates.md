# Inventaire, renommages manuels et fiches en doublon

## Fonctionnement existant

Le timer `vidb-reconciliation-refresh.timer` prévoit un inventaire toutes les
15 minutes. Son activation effective se vérifie sur Zeus avec `systemctl`.
Un scan complet du volume attendu permet de marquer les copies absentes
`missing`, sans effacer leur historique ni remettre en cause le visionnage.
Une copie volontairement `deleted` n’est pas réactivée par simple présence.
Le volume manquant, un répertoire inaccessible ou un scan incohérent provoquent
un refus de synchronisation, pas des milliers de fausses disparitions.

Les déplacements faits par video_encoder peuvent être rapprochés automatiquement
grâce au reçu d’export et à `previous_output_path`. Un renommage manuel ne fournit
pas cette preuve. L’ancien chemin peut même être réutilisé par un nouvel encodage.

Ce correctif traite ce dernier cas : si les mesures connues de l’ancienne copie
ne correspondent plus au fichier occupant son chemin (taille différente ou
modification postérieure à son observation), elle devient `missing` au prochain
scan complet. Ce nouveau fichier ne confirme plus les mesures de l’ancienne
copie. Les copies sans mesures suffisantes ne sont pas invalidées sur cette base.
Deux fichiers de même taille, avec une date conservée artificiellement, ne sont
pas distinguables par ces seuls indices : aucun hachage complet n’est ajouté.

## Outils → Inventaire et doublons

La page lit le dernier inventaire terminé, sans parcourir les disques pendant
la requête web. Le bouton Actualiser utilise la demande existante au service de
scan ; il ne relance pas video_encoder et n’exécute pas la passe d’application
du chantier de qualification. L’affichage donne la date du relevé. Les constats
sont donc ceux du dernier scan, pas une surveillance instantanée des fichiers.

Les chemins absents, occupés par un fichier changé, hors périmètre ou dépourvus
de mesures suffisantes sont distingués. Une recherche par titre ou identifiant
et une pagination limitent l’affichage. Sans relevé complet compatible, aucune
absence n’est inférée ; la recherche de fiches reste disponible.

### Reconnaître un renommage

Pour une copie absente ou remplacée, la page propose les fichiers non encore
associés, de même taille, du même dossier et de date compatible. `nom_old.ext`
et `nom_vf.ext`, avec la même extension, apparaissent en priorité. Le suffixe
n’est jamais une preuve ; les autres possibilités restent examinables.
Les fichiers d’un autre dossier ne sont pas proposés dans ce premier incrément.

Cliquer un candidat ouvre une confirmation explicite de son identité. Le token
signé est lié à la copie, à son chemin, à sa version, à l’utilisateur et à
l’identité stat du fichier ; il expire après 15 minutes. Le volume et le fichier
sont contrôlés à nouveau avant l’écriture. Les liens symboliques, les chemins
déjà associés, les suppressions en cours et les changements concurrents sont
refusés. La transaction utilise le verrou des imports d’exports puis les verrous
de tables dans le même ordre que la synchronisation de présence.

La validation met uniquement à jour `last_known_path` et conserve l’identifiant,
la durée, les mesures, les annotations et la provenance de VideoAsset. Un
événement `manual_inventory_review` est ajouté à `relocation_history`. Aucun
fichier physique, projet JSON, reçu ou job de video_encoder n’est réécrit.

Exemple : `Jo.mkv` devient `Jo_old.mkv`, puis un nouvel encodage reprend `Jo.mkv`.
Après scan et confirmation du candidat, l’ancienne copie est liée à Jo_old.mkv.
Le nouvel export pourra être importé séparément par la voie habituelle. Le
renommage n’ajoute pas une copie fictive et ne fusionne pas les deux encodages.

Une disparition manuelle reste `missing`, pas `deleted` : elle ne prouve pas une
suppression volontaire et définitive. Une suppression via le bouton Poubelle
continue d’utiliser la corbeille et son historique dédiés.

### Fiches logiques potentiellement en doublon

La seconde partie groupe des Record distincts de même nature, titre normalisé
et année. Le contexte et le rang des épisodes/saisons évitent de confondre les
saisons 1 de séries différentes. Les films restent comparables à travers les
collections. Les copies et leurs chemins sont présentés fiche par fiche.

Plusieurs fichiers d’une seule fiche ne constituent pas deux fiches en doublon.
Les résultats sont des suspicions à examiner, jamais une fusion automatique.
Une année manquante d’un côté seulement, des titres différents ou des variantes
de traduction ne sont pas rapprochés à ce stade. Le rapport n’est pas un
comparateur binaire des fichiers et ne suppose pas qu’une petite copie est
nécessairement mauvaise. Aucun enregistrement n’est supprimé par cette page.

## Menu CSV et Crédits

L’entrée « Importation csv » était un lien `#`, sans route ni contrôleur d’import
CSV identifié dans l’application actuelle. Ce point d’entrée inactif est retiré.
Les imports XMLTV, les importations de copies et les scripts de maintenance
existants sont indépendants et sont conservés.

La page Crédits reprend le texte demandé :

> Crédits
>
> The Movie Database (TMDB)
>
> Ce produit utilise l’API TMDB. Les données et images provenant de TMDB sont identifiées dans les fiches et propositions de cette application.

## Validation et déploiement

Aucune migration ni installation de passerelle. `bin/check` vérifie les nouveaux
services et contrôleurs ainsi que les conventions existantes. Les tests couvrent
les suffixes _old/_vf, les métadonnées divergentes, la portée série/épisode, le
refus des doubles associations, l’authentification, les signatures et les courses.
Déployer vidb normalement ; aucun redémarrage de video_encoder nécessaire.
