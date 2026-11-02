# Nettoyer les références obsolètes des copies

Ce correctif remplace le classement en historique visible introduit auparavant.
vidb doit montrer les copies actuelles et conserver le visionnage de l’œuvre ;
les anciennes adresses techniques ne sont plus une seconde vidéothèque.

## Parcours

Une référence Introuvable reste une alerte à examiner, jamais une suppression
automatique déduite d’une absence. Son action **Retirer cette ancienne référence…**
ouvre une confirmation, individuelle ou par sélection dans Inventaire et doublons.

Si le fichier a été déplacé et que sa nouvelle adresse n’est pas encore liée,
utiliser le rattachement au nouveau chemin : la copie existante est actualisée.
Si une copie présente existe déjà dans la fiche, conserver cette copie et
retirer les anciens emplacements désormais inutiles. Il n’est pas nécessaire
ni exact de les qualifier de fichiers physiquement supprimés.

Après vérification des absences, une sauvegarde technique privée est synchronisée
sur disque, puis les lignes VideoAsset sélectionnées sont **retirées de la base**.
Aucun fichier média n’est effacé, déplacé ou renommé par cette opération.
La fiche Record de l’œuvre reste en place. Son état `is_seen` et sa confirmation
`seen_state_confirmed_at` ne sont pas modifiés. Les copies restantes, leurs
mesures et leurs qualifications ne sont pas modifiées. Les callbacks habituels
recalculent la disponibilité ; le correctif ne migre pas globalement les anciens
indicateurs d’acquisition du catalogue.

Les références déjà `deleted` par les procédures précédentes peuvent aussi être
nettoyées si leur ancien chemin est toujours absent. La fiche ne présente plus
leur historique détaillé : un petit lien **Nettoyer ces références…** remplace
l’ancien panneau. Le lien traite au plus 100 références à la fois ; répéter si
nécessaire. Une fois nettoyées, elles ne sont plus affichées ni proposées comme
copies à examiner. Les anciennes données ne sont pas fusionnées aveuglément
avec celles de la copie présente ; elles restent récupérables dans la sauvegarde.

## Vérifications

La confirmation signée reste limitée à l’utilisateur, aux identifiants, aux
chemins et aux versions des références, avec une expiration de 15 minutes.
Une ancienne confirmation du classement « Supprimée » ne peut pas autoriser
le nouveau nettoyage : le purpose de signature est différent.

Seules les références `missing` ou `deleted` sont éligibles. Toute copie présente,
suppression vers la corbeille inachevée, entrée encore existante, lien symbolique,
erreur d’accès ou perte du volume bloque le lot. Les absences sont vérifiées
avant et après le nettoyage sous transaction, avec le garde du volume attendu
et les verrous partagés avec les imports. Un refus annule tout le lot en base.
Une réapparition après cette vérification ne peut pas être empêchée ; un nouveau
fichier pourra être rapproché comme nouvelle copie par le parcours habituel.

Une erreur de sauvegarde interdit tout retrait. Un échec ultérieur peut laisser
une sauvegarde alors que la transaction a été annulée : la présence d’un fichier
de sauvegarde ne prouve donc pas que le nettoyage a été commité.

Aucune opération automatique n’est ajoutée. Les copies physiquement mises dans
la corbeille video_encoder par l’action Poubelle y restent indépendamment de la
référence vidb. Le nettoyage ne vide ni la corbeille ni la quarantaine et ne touche
pas aux projets ou à la file d’encodage.

## Sauvegarde technique

Production : `/srv/vidb/shared/copy-reference-backups/` ; développement et tests
hors injection : `tmp/copy-reference-backups/`. Répertoire privé 0700 appartenant
au processus, fichiers exclusifs 0600, sans lien symbolique, nom horodaté unique.
En cas de permissions manquantes, créer le dossier comme administrateur :

```sh
sudo install -d -o vidb -g vidb -m 0700 /srv/vidb/shared/copy-reference-backups
```

Chaque sauvegarde contient tous les attributs des références retirées, les
attributs de leurs œuvres à titre de contexte, la date, l’utilisateur, le format
et une empreinte SHA-256 de contrôle. Les timestamps d’attributs Time conservent
leur précision. Le chemin est indiqué après nettoyage. Aucun secret de connexion
n’est enregistré. Ces fichiers ne sont ni une collection visible dans vidb ni
un historique consulté lors des recherches.

Aucune purge automatique de ces sauvegardes n’est installée dans cet incrément.
Elles restent disponibles pour récupération et peuvent être archivées avec les
sauvegardes techniques du serveur. Il faut utiliser le fichier dans la même base
que celle où le nettoyage a eu lieu.

## Récupération exceptionnelle

Le script `script/restore_copy_reference_backup.rb` s’exécute avec l’environnement
Rails de la base concernée. Par défaut il contrôle le document et affiche un
aperçu sans écrire. `--apply` est nécessaire pour recréer les références.

```sh
bundle exec bin/rails runner script/restore_copy_reference_backup.rb /chemin/sauvegarde.json
bundle exec bin/rails runner script/restore_copy_reference_backup.rb /chemin/sauvegarde.json --apply
```

En production, employer le compte vidb et son environnement de déploiement,
comme pour les autres runners de maintenance. Ne pas lancer ces commandes dans
la base de développement pour restaurer une sauvegarde de production.

La restauration refuse un document altéré, une œuvre disparue, un identifiant
réutilisé ou un chemin déjà associé. Elle conserve les identifiants et données
techniques des références sauvegardées et ne restaure **jamais** les attributs
Record archivés : cela évite de rétablir un ancien état vu/non vu. Aucun média
n’est restauré sur disque. Le statut sauvegardé est retrouvé, et les contrôles
d’inventaire normaux détermineront ensuite sa présence.

## Vérification et déploiement

Les tests couvrent la sauvegarde privée, l’intégrité, le refus de liens, les
échecs de sauvegarde, les anciens tokens, le lot atomique, la restauration sans
écrasement et la conservation des états vu, non vu et inconnu.
`bin/check`, commit sélectif et déploiement habituel. Aucune migration,
réinstallation de passerelle ou relance de video_encoder.
