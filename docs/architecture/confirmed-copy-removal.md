# Supprimer une copie confirmée depuis une fiche

Le bouton Poubelle, à droite d’une copie présente, ouvre une confirmation
distincte affichant son fichier, son chemin, sa durée et sa taille connue.
Annuler ou fermer cette page ne déplace aucun fichier. Le POST, protégé par CSRF,
exige une confirmation signée, valable 30 minutes, liée à l’utilisateur, à la copie
et à son chemin. Une requête ne peut pas désigner la copie d’une autre fiche.

## Effet et conservation

Seul le fichier vidéo sélectionné est déplacé, sur le même volume, dans
`<dossier>/.video_encoder_trash/<identifiant>/`. Le manifeste est compatible avec
la corbeille existante de video_encoder et son dossier est enregistré dans la
base de cette file. Aucun projet JSON, fichier de découpage, reçu d’export,
autre copie ou source n’est supprimé par association de nom.

La ligne VideoAsset est conservée avec l’état `deleted`, ses mesures et sa
provenance. `technical_details.copy_removal` conserve le reçu, l’utilisateur et
la date. La disponibilité et les durées sont recalculées par les callbacks
habituels ; cette copie ne contribue plus à la durée de la fiche. Le chemin de
corbeille reste consultable dans ses détails. Les autres copies sont intactes.

**L’espace disque n’est libéré qu’au vidage de la corbeille.** Sa conservation
est sans limite de durée ; la règle de 30 jours de la quarantaine des captures
ne s’applique pas à cette corbeille. La suppression définitive se fait depuis
la corbeille de video_encoder, avec sa confirmation habituelle.

Une restauration depuis cette corbeille restitue le fichier ; elle ne constitue
pas une nouvelle confirmation de copie dans vidb. Il faut ensuite rétablir sa confirmation dans vidb après contrôle du fichier ;
la restauration de la corbeille n’effectue pas cette mise à jour. L’état `deleted` ne doit
pas être réactivé automatiquement par un simple contrôle de présence.

## Protection de la file

Le pont s’exécute comme propriétaire de video_encoder et utilise sa base SQLite
existante, sans créer de base ni lancer de migrations. Préparation et déplacement
s’exécutent sous une transaction `immediate`, avec le même verrou que les
opérations de la file. `ProjectTrashUsage` vérifie les chemins des projets,
sorties et sources des tâches `running`, `queued`, `deferred`. Un projet actif
manquant ou illisible entraîne un refus. Le contrôle est répété au moment de
l’effacement, même si la confirmation avait réussi auparavant.

Cette protection concerne les tâches gérées par la file. Elle n’inventorie pas
les logiciels externes ni un encodage immédiat qui n’y serait pas enregistré.
Éviter de retirer une copie utilisée par un autre logiciel ou une opération
immédiate. Les fichiers ouverts peuvent rester lisibles après déplacement, mais
une réouverture à l’ancien chemin ne le serait plus.

Le volume `/videos` et son UUID attendu sont vérifiés avant toute requête.
Les chemins externes, fichiers non vidéo, liens symboliques, parents symboliques,
liens physiques multiples et chemins internes de corbeille sont refusés.
La confirmation contient l’identité du fichier : périphérique, inode, taille,
mtime et ctime. Un fichier remplacé ou modifié nécessite une nouvelle validation.
Un manifeste préexistant incohérent provoque un refus, jamais un écrasement.

## Installation après déploiement

Ce patch est uniquement dans **vidb**. Il réutilise la corbeille et les classes
`ProjectTrashRegistry` / `ProjectTrashUsage` déjà présentes dans video_encoder.
Il ne nécessite pas de redémarrage de video_encoder et ne modifie aucun job.

Après `bin/check`, commit et déploiement de vidb, exécuter comme Pascal :

```sh
cd ~/code/Fofo92/vidb-clean
python3 bin/install-copy-trash-bridge --encoder-root ../video_encoder --ruby "$(rbenv which ruby)"
```

L’installateur vérifie les chemins, valide son fragment avec `visudo`, puis
installe un lanceur appartenant à root dans `/usr/local/libexec/vidb-copy-trash`
et `/etc/sudoers.d/vidb-copy-trash`. La seule autorisation accordée à `vidb` est
ce lanceur **sans argument**, comme `pascal`, jamais comme root. Il accepte une
requête JSON bornée sur son entrée standard. Les données de la page ne deviennent
ni une commande shell, ni un chemin de programme. L’installateur lit uniquement
les deux fichiers de code nécessaires dans `/srv/vidb/current`, comme `vidb`,
et les installe dans `/usr/local/libexec/vidb-copy-trash-code/<empreinte>/`.
Ces copies appartiennent à root et sont lisibles par Pascal. Le lanceur utilise
ces copies et fixe le dépôt, le Ruby et le Gemfile de video_encoder. Aucun accès
supplémentaire aux releases, à la base PostgreSQL ou aux secrets de production.

Pour un autre utilisateur propriétaire, renseigner `VIDB_COPY_TRASH_USER` dans
`/etc/vidb/vidb.env`, puis redémarrer uniquement vidb. Si le dépôt video_encoder
ou son Ruby change d’emplacement, réexécuter l’installateur. Le réexécuter aussi
après un déploiement qui modifie `bin/trash-confirmed-copy` ou
`lib/confirmed_copy_trash.rb` : ces deux fichiers sont copiés, pas liés à la release.
Si le pont n’est pas
installé ou que l’accès est refusé, la confirmation échoue sans suppression.
Le worker refuse d’être lancé comme root. Aucun timer supplémentaire.

## Échec et reprise

Avant le déplacement, vidb enregistre un plan `copy_removal_pending`.
L’identifiant détermine un dossier de corbeille stable. Si le fichier y est déjà
présent avec la bonne identité, la répétition du POST renvoie le même reçu.
Un clic ultérieur sur la poubelle d’une suppression inachevée reprend ce plan,
même si le contrôle de présence a temporairement marqué la copie introuvable.
Une réussite déjà enregistrée ne déplace plus rien.

En cas de refus pour tâche active, terminer cette tâche puis réessayer. En cas
de fichier changé ou de manifeste incohérent, examiner le plan et la corbeille :
aucun contournement silencieux du contrôle d’identité n’est prévu. Ne pas vider
ou restaurer cette entrée tant que vidb n’a pas enregistré la suppression.

Le mouvement et le commit Rails ne sont pas une transaction distribuée ; le plan
persistant et le manifeste rendent cette interruption détectable et reprenable.
Un disque plein, un arrêt brutal ou des permissions insuffisantes peuvent laisser
une entrée préparée à examiner. Aucun effacement définitif de secours.

## Vérifications

`test/lib/confirmed_copy_trash_test.rb` couvre déplacement sélectif, répétition,
identité changée, liens, confinement, projet actif inaccessible et manifeste.
`test/controllers/record_copy_removals_controller_test.rb` couvre la confirmation,
les signatures, la portée de la copie, l’authentification, la reprise et la durée
après retrait d’une seule copie. Les tests n’effacent pas les vidéos réelles.

Après installation, tester d’abord l’ouverture et l’annulation de la confirmation.
Une suppression choisie explicitement doit conserver les autres fichiers,
afficher « Supprimée » et apparaître dans la corbeille de video_encoder à sa
prochaine actualisation.
