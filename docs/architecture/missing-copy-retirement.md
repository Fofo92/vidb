# Confirmer la suppression d’un fichier déjà absent

Une référence `missing` ne prouve pas une suppression volontaire : un fichier
peut avoir été déplacé, renommé ou être inaccessible. Elle ne passe donc jamais
automatiquement à `deleted` lors d’un inventaire.

## Action individuelle et sélection multiple

Dans Détails des copies, une copie Introuvable possède une action
**Confirmer la suppression du fichier**, distincte de la poubelle qui déplace
une copie présente dans la corbeille. Une page affiche les chemins avant de
demander la confirmation explicite de leur suppression volontaire.

Dans **Outils → Inventaire et doublons**, les lignes dont le relevé constate
l’absence et dont le statut est `missing` peuvent être cochées. Le bouton
**Confirmer la suppression des fichiers sélectionnés…** ouvre la même confirmation
pour la sélection. Les cases concernent la page affichée, pas toutes les pages
du rapport. La limite de service est de 100 références par confirmation.

Si le fichier a été renommé ou déplacé, préférer le rattachement au nouveau
chemin, notamment pour `_old` et `_vf`. La page de confirmation le rappelle.
Une opération de corbeille inachevée doit être reprise par sa voie habituelle ;
elle ne peut pas être remplacée par cette confirmation.

## Vérifications et effet

Le volume /videos et son UUID sont contrôlés avec le garde existant, lors de
la préparation puis avant et après l’écriture. Les chemins sont absolus,
canoniques et sous le volume. La vérification ne suit pas de lien symbolique :
un lien cassé reste une entrée existante et est refusé. Un parent symbolique,
un accès refusé ou une erreur de lecture ne sont pas assimilés à une absence.
Un dossier parent supprimé sous le volume monté permet en revanche d’établir
l’absence du fichier. La perte du volume racine est toujours un échec.

Le plan signé expire après 15 minutes et contient l’utilisateur, les identifiants,
les chemins et les versions des références. Les lignes sont relues et verrouillées
avant validation. La transaction emploie le verrou des imports d’exports puis
les verrous records/video_assets, comme le rattachement manuel. Toutes les
absences sont vérifiées avant les mises à jour, puis à nouveau avant le commit.
Un refus annule tout le lot. Il n’existe pas de validation silencieuse d’un
sous-ensemble.

La seule modification fonctionnelle est le passage de `missing` à `deleted`,
avec un événement `technical_details.copy_retirement` contenant date, utilisateur,
ancien statut, chemin et origine `manual_missing_confirmation`. La ligne,
sa durée et toute sa provenance sont conservées. Les callbacks habituels
préservent l’historique d’acquisition et recalculent la disponibilité avec les
autres copies. Une bonne copie VMST présente reste inchangée lorsque l’ancienne
copie VF est classée supprimée.

Aucun fichier physique, dossier, projet JSON, reçu ou job n’est effacé, déplacé
ou réécrit. La quarantaine et la corbeille de video_encoder ne sont pas appelées.
Le contrôle constate une absence à l’instant de la validation ; il ne bloque pas
un autre logiciel recréant plus tard un fichier au même chemin. Une telle
réapparition ne réactive pas une référence volontairement `deleted` : elle doit
faire l’objet d’un nouveau rapprochement ou examen, conformément aux règles
d’inventaire existantes.

## Affichage

Les copies présentes et introuvables restent dans le tableau principal.
Les copies `deleted`, qu’elles proviennent de la corbeille ou de cette action,
sont déplacées dans **Afficher l’historique des copies (N)**, fermé par défaut.
Leurs détails techniques, qualifications, chemins et provenance restent lisibles.
Le tableau est rendu par un partiel commun pour éviter des différences entre
copies actives et historiques. Les identifiants de lignes sont conservés pour
l’actualisation automatique de Record.show.

## Vérification et déploiement

Tests : absence réelle, lien cassé, parent symbolique, permission refusée,
fichier réapparu, référence modifiée, volume perdu, plan expiré, authentification,
lot atomique, historique replié et conservation d’une autre copie présente.

`bin/check`, commit sélectif et déploiement normal de vidb. Aucune migration,
passerelle à réinstaller ou relance de video_encoder nécessaire.
