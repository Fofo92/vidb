# Renommage délégué, lié à un plan précis

Cet incrément retire la dépendance au cas particulier 355 dans l’adaptateur
Ruby et le worker natif. Il ne change pas la limite du planificateur : un MKV
isolé, sans projet JSON associé, dans son répertoire actuel sous /videos/Films.

## Coordination

RelocationCommit conserve son autorisation explicite, les contrôles de volume,
les verrous Record/VideoAsset, le recontrôle du plan et la vérification des
genres et des collisions de destination en base. Il accepte un adaptateur
file_rename optionnel ; le comportement natif antérieur reste le défaut.

Avant de journaliser filesystem_renamed et d’écrire le chemin en base, il
vérifie indépendamment que la cible visible est un fichier régulier de la
même identité (hors ctime), que ses ancêtres ne sont pas des symlinks et que
la source a disparu. Une réponse erronée d’un adaptateur n’autorise pas une
mise à jour aveugle de PostgreSQL. Le journal reste celui de la coordination
et conserve les erreurs ; aucune inversion automatique n’est ajoutée.

RelocationSocketRename fait une copie du plan à sa création. Il n’envoie que
probe/rename, source, cible et identité exactes. Il vérifie le pair UID 0 avant
d’envoyer la demande, borne le délai et la taille de réponse, puis vérifie le
résultat visible. Il n’exécute aucune commande et ne possède aucun repli vers
un renommage moins strict. probe doit précéder l’appel au coordinateur dans
le futur lanceur opérationnel, afin de détecter un worker indisponible avant
la création d’un journal définitif.

## Worker root ponctuel

script/video_asset_rename_worker.py reçoit uniquement le chemin d’un plan.json
et celui de worker.sock. Le dossier doit être privé, appartenir à root:vidb,
sans symlink, sous /run/vidb-relocation-*. Le plan doit être un fichier régulier
root, mode 0600, dans ce même dossier. Le socket est root:vidb, mode 0660. Seul
le pair UID vidb est accepté. Au maximum deux connexions sont servies : contrôle
puis renommage. Chaque demande est bornée et doit correspondre exactement au
plan chargé une fois au démarrage.

Le plan est au format vidb.relocation_request, version entière 1, avec :
execution_authorized=true, root=/videos, record_id et asset_id positifs,
source et target MKV canoniques distincts dans le même répertoire sous
/videos/Films, et identity={dev, ino, size, mtime_ns, ctime_ns} entière complète.
Une prévisualisation non autorisée n’est donc pas directement exécutable.

Le worker ouvre les ancêtres par descripteurs sans suivre de symlinks, contrôle
l’identité et le volume non monté en lecture seule, puis emploie exclusivement
renameat2(RENAME_NOREPLACE). Il synchronise le répertoire et vérifie l’identité
ancrée et visible de la cible. La disponibilité de renameat2 est obligatoire.
Il ne touche ni PostgreSQL, ni permissions de /videos, ni ACL. Un échec n’est
jamais suivi d’un renommage de remplacement ou d’un retour arrière automatique.

Les métadonnées stat ne prouvent pas l’absence de toute modification du contenu
si un acteur parvient à préserver toutes les valeurs contrôlées ; cet incrément
n’ajoute pas un hachage intégral des MKV.

## Passage à un premier lot

script/video_asset_relocation_batch_preview.rb ne fait qu’un relevé. Il exige
vidb_production et le volume attendu, utilise une transaction PostgreSQL en
lecture seule et examine au maximum 250 copies de films présentes sous
/videos/Films. Il retient au maximum cinq plans techniquement prêts et fournit
des exemples de blocages. Un chemin déjà canonique n’est pas renommé à nouveau.
Une cible réclamée en base ou un journal existant est exclu.

Les données de qualification sont présentées pour examen : titre, année et
provenance, genres, résumé et version linguistique de la copie. Un plan prêt
n’affirme pas à lui seul que ces métadonnées sont correctes. Les références
d’année et les langues manquantes sont signalées ; les cas clairs pourront
être résolus sans validation systématique, conformément à la convention.

Cet incrément ne contient pas de commande démarrant le worker root en
production et n’émet aucun plan autorisé. Le lanceur du premier déplacement
sera construit à partir du relevé concret, avec un plan root privé, un service
systemd temporaire à durée et capacités limitées et des accès en écriture
limités à son dossier /run et au répertoire source exact. Les chemins contenant
des espaces devront être cités suivant la syntaxe des propriétés systemd.
L’utilisation des scripts temporaires de 355 pour d’autres films est exclue.

Les tests du worker utilisent uniquement des fichiers fictifs sous /tmp. Les
manifestes de test contenant /videos servent seulement à vérifier leur format ;
ils n’y ouvrent aucun fichier. Les tests du client Ruby simulent le transport.
L’authentification réelle du socket et le service root seront vérifiés sur Zeus
lors de la préparation du premier déplacement concret, avant toute écriture.
