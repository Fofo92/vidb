# Reprise d'un reclassement documenté

Une opération conserve ses instantanés initiaux dans un manifeste privé immuable,
créé avant toute exécution. Un rejeu ne fabrique pas de nouveaux instantanés pour
faire accepter une modification manuelle intervenue entre-temps.

`ReclassificationRecovery` reprend les options de `ReclassificationCommit`.
`preview_state(plan:, asset:, genres:)` lit le journal et compare les états sans
écriture SQL ni écriture de journal. `call(..., authorized: true)` reprend sous
les verrous de la fiche, de la copie et du journal, sans transaction SQL englobante.

| État constaté | Reprise |
| --- | --- |
| Source intacte, SQL initial, journal vide ou préparation sans déplacement | Revérifier puis déplacer une seule fois |
| Cible vérifiée, source absente, SQL initial | Appliquer uniquement les genres, la provenance et le chemin SQL |
| Cible vérifiée, SQL et preuve de genres déjà appliqués | Clôturer uniquement le journal |
| État déjà réconcilié | Aucun changement |
| Métadonnées, preuve ou identité incompatibles | Refus sans écraser la correction ou déplacer inversement le fichier |

Le journal est privé, régulier, sans lien symbolique ni lien physique, appartenant
au processus Rails. Sa lecture est bornée et son verrou non bloquant. Un journal
tronqué ou de format inattendu n'est pas réécrit pour le rendre artificiellement
valide. Une préparation doit correspondre à l'opération, aux chemins, à l'identité,
à la classification et à tous les instantanés immuables.

L'événement `filesystem_renamed` conserve désormais l'identité complète après le
déplacement, ctime comprise. Lorsqu'il existe, la reprise exige son égalité exacte.
Si l'interruption précède cet événement, la reprise vérifie l'identité initiale
hors ctime, comme la vérification immédiatement après rename : rename change ctime.
Il s'agit de contrôles d'identité de fichier, pas d'une empreinte cryptographique
du contenu vidéo. Un nouveau point de contrôle physique est alors enregistré.

La reprise SQL ne sollicite aucun adaptateur physique. Une exception SQL annule
ensemble le changement de genres et de chemin. `reconciled` est ajouté après
le commit SQL ; un rejeu identique ne réécrit ni la preuve ni ce marqueur.
Une exception après un marqueur `completed` déjà écrit peut être clôturée par
`reconciled`, après les mêmes vérifications, sans nouvelle écriture SQL.

## Coordinateur des huit décisions du 17 octobre 2026

Le paquet opérationnel fixe les copies 821, 529, 1545, 1203, 1404, 1135, 1839 et 667.
Les sources, cibles, identités et décisions documentaires sont figées par empreinte.
Le précontrôle vérifie la langue, la provenance de l'année, le résumé, les genres,
la copie unique et sa taille. Les validations des modèles sont contrôlées avant
le premier déplacement, en refusant une normalisation incidente d'autres champs.

Les travaux immuables et rapports sont conservés sous
`/srv/vidb/shared/relocations/reviewed-eight-20261017`, avec des permissions privées.
La préparation peut écrire ces fichiers de travail ; elle ne change ni PostgreSQL
ni les vidéos. Le dépôt reçoit uniquement les composants, tests et documentation.
Le paquet et les rapports destinés au transfert restent dans /tmp.

Chaque processus Rails tourne comme vidb avec l'environnement de production.
Root ne déplace qu'un fichier épinglé par manifeste, via un worker éphémère limité
aux deux parents concernés et à son répertoire d'exécution. Landlock ABI >= 3 restreint les opérations d’écriture aux deux parents et au
runtime. Le montage /videos reste unique pour éviter EXDEV entre montages bind.
Le code des trois modules est vérifié puis copié dans ce répertoire privé appartenant à root.
L'écriture du bytecode Python y est désactivée. Les reprises purement SQL ne
lancent pas de worker root. Aucun répertoire vidéo n'est créé ou chmodé.

La sauvegarde précédant le déploiement est vérifiée avec pg_restore et SHA256.
Un reçu privé root lié au commit permet de la réutiliser pendant l'enchaînement
déploiement et application, sans produire un second dump dans la même minute.
La publication vérifie le périmètre Git et les empreintes des composants critiques.
Le lancement refuse une autre release courante et vérifie les huit résultats.

Le test réel de Landlock s'exécute dans un sous-processus sur des fixtures /tmp
avant publication. Tout échec ou ABI non pris en charge bloque l'enchaînement ;
il n'existe aucun repli sans confinement. Les lectures et certaines opérations
de métadonnées ne sont pas médiées par cette politique : le code figé ne les
utilise pas pour modifier d'autres fichiers. Voir
https://docs.kernel.org/6.12/userspace-api/landlock.html.
