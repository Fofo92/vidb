# Exécution d'un reclassement entre répertoires

## Contrat

`ReclassificationPlanner` complète les contrôles du planificateur historique
pour deux répertoires existants sur le même périphérique. Il exige des références
de genres disponibles et non ambiguës, une provenance encore non qualifiée et
l'absence de JSON adjacent à la source comme à la cible. Le plan ne constitue
jamais une autorisation d'exécution. La qualification éditoriale de l'identité,
de l'année et de la langue reste une responsabilité de l'orchestrateur.

La classification est un Hash à clés symboles : `category`, `genres`, `evidence`.
Les catégories admises sont `film` et `documentary`. `evidence` contient `reason`
et `sources`. Le composant de proposition normalise Biographie vers la référence
Biopic, conserve l'orthographe des répertoires Biographie et dirige les
documentaires vers `/videos/Documentaires`.

`ReclassificationCommit` réutilise le verrouillage et le journal privés de
`RelocationCommit`. Son initialisation requiert explicitement un adaptateur de
fichiers, et une qualification contenant :

- les clés de classification précédentes et un `operation_id` stable ;
- `expected: { genres: [...], provenance: {} }` avant application ;
- `record_snapshot: record.attributes.except('updated_at').as_json` ;
- `copy_snapshot: asset.attributes.except('updated_at').as_json`.

Ces instantanés proviennent de la préparation de la décision. Les recréer
aveuglément après un changement manuel reviendrait à abandonner cette protection.
Le commit compare toutes les métadonnées sous les verrous avant le déplacement.
Une destination revendiquée par une autre copie, même supprimée, est refusée.

Le service vérifie le déplacement, applique les genres et leur provenance puis
le chemin de copie dans la même transaction SQL. Il vérifie la préservation des
autres attributs. Il clôt le journal après le commit SQL.

## Adaptateur physique

`script/video_asset_reclassification_worker.py` accepte un manifeste privé,
appartenant à root, mode 0600, dans un répertoire privé root:vidb de `/run`.
Le format est `vidb.reclassification_request`, version 1, avec autorisation
booléenne vraie, racine `/videos`, identifiants de fiche et de copie positifs,
catégorie, chemins exacts et identité complète.

La source est un MKV directement sous un répertoire de genres de Films.
La cible est un MKV sous un autre répertoire de genres de Films ou directement
sous Documentaires, selon la catégorie. L'adaptateur ouvre les deux répertoires
composante par composante sans suivre de liens symboliques. Il utilise
`renameat2(RENAME_NOREPLACE)` avec leurs descripteurs, refuse un périphérique
différent, vérifie l'identité et synchronise les deux parents. Aucun mkdir,
chmod des répertoires vidéo, écrasement, copie ou réencodage n'est possible.
Le serveur de socket conserve les contrôles d'utilisateur de son prédécesseur.

L'adaptateur historique reçoit uniquement deux points d'injection facultatifs
pour le chargement du manifeste. Ses appels par défaut et son contrat de
renommage dans le même répertoire sont conservés.

## Interruption et réconciliation

Une exception SQL après le déplacement annule genres, provenance et chemin SQL,
mais laisse le fichier à sa nouvelle place. Le journal préparé contient les
instantanés et toute la qualification ; l'événement filesystem_renamed atteste
la vérification physique. Une exception avant la clôture peut également laisser
un SQL déjà committé. Un journal existant bloque un rejeu aveugle.

Il n'y a pas de déplacement inverse automatique. Le choix d'une reprise nécessite
de comparer le journal, l'identité du fichier, le chemin SQL et la preuve de genres.
Le coordinateur de reprise et le lancement borné des huit copies ne sont pas
fournis dans cet incrément. Aucun lancement en production n'est ajouté ici.
La publication et la migration de provenance en production devront précéder
leur application réelle. Les permissions du worker devront limiter l'écriture
aux deux répertoires précis et au répertoire privé d'exécution.
