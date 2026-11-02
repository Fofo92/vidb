# Actualisation de la fiche ouverte

## Fonctionnement

La vue `records/show` utilise le contrôleur Stimulus `record-live` en complément de
`record-states`. Une vérification est effectuée environ toutes les 15 secondes,
uniquement pour un onglet visible. Il n'y a jamais deux requêtes simultanées pour
une fiche. Le retour à l'onglet déclenche une vérification immédiate.

Le GET authentifié `/records/:record_id/live` compare une empreinte de données :

- Fiches de l'arbre racine, donc aussi les parents et enfants de la fiche ouverte.
- Associations de pays, genres et supports, ainsi que leurs libellés et les versions.
- Copies, y compris changement de chemin, durée, statut ou détails techniques.
- Sources de pochettes et rattachements de fichiers Active Storage.

Les données sont lues directement, sans dépendre du seul `updated_at` de la fiche.
Une modification de pays ou une récupération de pochette sans sauvegarde de
`Record` peut donc déclencher l'actualisation. Il n'y a ni lecture de fichier
source vidéo ni modification de la base dans ce parcours.

Si rien ne change, le serveur renvoie 204 sans HTML. Sinon, il rend la fiche avec
les partiels existants, sans layout, et vérifie à nouveau l'empreinte sans cache de
requête. La fiche propriétaire est relue avant le rendu. Un changement concurrent
produit une réponse 409 pour différer la mise à jour au prochain passage.

## Zones et interaction

Le navigateur compare et remplace seulement les zones dont le contenu a changé :
pochette, informations de l'œuvre, visionnage et copies, provenance de l'année,
commandes et tableau des enfants. Les jetons CSRF aléatoires et l'attribut `open`
des volets ne provoquent pas à eux seuls un remplacement.

Les volets ouverts, le focus identifiable, le défilement de la fenêtre et celui
des tableaux de copies sont restaurés après remplacement. Les lignes enfants
possèdent un identifiant de présentation stable sans changement de mise en page.
Le contenu et les actions du tableau restent ceux des partiels existants.
Les URL de pochettes portent l'identifiant du fichier attaché pour éviter la
réutilisation de l'ancienne image lors d'un remplacement.

La vérification est différée si un champ est actif, un formulaire modifié ou en
cours d'envoi, un menu de modification d'état ouvert, ou pendant une interaction
immédiate à la souris ou au clavier. Une sélection de fichier de pochette est
ainsi préservée. Un changement de fiche via une autre fenêtre sera pris en compte
lorsque la page pourra de nouveau être actualisée sans interrompre une saisie.

Les actions manuelles de `record-states` signalent leur début et leur fin. Toute
réponse automatique entamée avant une telle action est ignorée. Les requêtes sont
annulées à la déconnexion du contrôleur, à la mise en cache Turbo ou lorsque
l'onglet est masqué. Une réponse tardive ne peut pas reprendre une ancienne boucle.

Un problème réseau conserve la fiche visible et provoque une nouvelle tentative,
avec un délai borné à 60 secondes. Une requête bloquée est annulée après 20 secondes.
Une session expirée ou une fiche supprimée suspend l'actualisation avec un message
non bloquant. Aucun rechargement automatique de la page n'est effectué.

Ce mécanisme reflète les changements déjà enregistrés dans vidb. Il ne remplace
pas le rapprochement des fichiers sur disque ou l'import de fin d'encodage.
Il n'ajoute ni migration, ni timer système, ni service d'arrière-plan.

## Vérification

```sh
bin/check
node --test test/javascript/record_live_controller_test.mjs
```

Les tests Rails couvrent l'authentification, la réponse inchangée, les modifications
et suppressions d'enfants, les rattachements de pochettes, les copies, les
associations de métadonnées et les changements concurrents. Les tests JavaScript
couvrent la boucle, les onglets masqués, les saisies, les actions locales, les
erreurs et l'arrêt des requêtes.

Essai visuel en développement : ouvrir une fiche avec enfants dans une première
fenêtre, puis modifier un enfant dans une autre. Au retour dans la première,
vérifier le titre, les compteurs et le tableau sans rechargement. Déplier les
copies et leur provenance avant un nouvel essai, puis vérifier que ces volets et
le défilement restent conservés. Faire aussi un essai avec une nouvelle pochette.
