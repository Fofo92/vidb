# Coordination du renommage et de PostgreSQL

Les exécuteurs d’essai gardent leurs restrictions. `RelocationCommit` constitue
une voie distincte, avec autorisation d’exécution explicite dans l’appel,
plan prêt, actif persisté inchangé, volume vérifié, propriétaires verrouillés,
genres rechargés, nouvelle comparaison de l’identité et destination libre en
base et sur disque. La portée reste un MKV isolé dans son répertoire actuel;
les limites JSON et copies multiples du planificateur restent applicables.

`RelocationDirectoryHandle` ouvre les répertoires composant le chemin via des
descripteurs épinglés, en refusant les liens symboliques. Le renommage natif
Linux `renameat2(RENAME_NOREPLACE)` refuse atomiquement une destination occupée;
il n’existe aucun repli vers un renommage écrasant. L’identité visible de la
cible est contrôlée après renommage et son répertoire est synchronisé.

Le journal doit se trouver dans un répertoire privé appartenant à l’utilisateur
exécutant l’opération, sans liens symboliques. Le déploiement de production
prévoira `/srv/vidb/shared/relocations`, persistant entre les releases. Ce n’est
pas un patch ni un fichier intermédiaire jetable : ne pas le placer dans /tmp.
La création du répertoire et du journal est synchronisée, puis l’événement
`prepared` est synchronisé avant de toucher au fichier. L’événement
`filesystem_renamed` précède la mise à jour de la ligne existante VideoAsset;
`completed` est écrit après le retour du commit PostgreSQL.

Un journal préexistant pour cette copie bloque une nouvelle tentative : aucun
écrasement du diagnostic et aucune nouvelle tentative automatique. Cette
restriction volontaire convient au premier renommage ciblé; un futur
historique de plusieurs déplacements devra gérer des tentatives distinctes.

## Échecs

PostgreSQL et le système de fichiers n’ont pas de transaction commune.
Un échec après le renommage peut donc laisser le fichier à destination et la
base à la source. Le service conserve `needs_review` avec la cause, sans retour
arrière physique automatique. Si l’écriture du diagnostic échoue aussi, la
cause originale et le chemin du journal restent accessibles dans l’exception.
Un journal terminé par `prepared` doit également être inspecté : le processus
a pu s’interrompre après le déplacement et avant l’événement suivant.

Les observations ne constituent pas un verrou contre d’autres programmes
modifiant les fichiers. Les vérifications détectent des changements; elles ne
rendent pas atomiques les écritures PostgreSQL et le système de fichiers.
La comparaison après renommage exclut ctime, changé normalement par l’opération;
elle vérifie dev, inode, taille et mtime, sans prétendre comparer tous les octets.

## État de livraison

Cet incrément ajoute les services et les tests de coordination. Il n’exécute
aucun renommage en production. Les tests PostgreSQL doivent passer sur Zeus
avant de préparer le runner ciblé sur le film 355. Le diagnostic de production
fourni avec l’archive est en lecture seule et vérifie notamment l’accès à
Fiddle et renameat2 dans le bundle réellement déployé.

La qualification linguistique de la copie 1445 de 355 est déjà VM. La cible
canonique reste `/videos/Films/Espionnage/355 (The 355) (2022).mkv`.
