# Navigation : vidéothèque, montage et télévision

La barre principale présente Vidéothèque, Montage, Programmation TV et Outils.
La recherche globale reste accessible au même endroit.

| Entrée | Destination |
| --- | --- |
| Vidéothèque | Accès direct au catalogue |
| Flèche Vidéothèque → Ajouter un DVD par scan | Identifier une édition physique et compléter les fiches vidb |
| Flèche Vidéothèque → Scans DVD à identifier | Reprendre les codes-barres déjà conservés |
| Montage → Nouveau montage | Choisir une source dans video_encoder |
| Montage → Reprendre un projet | Ouvrir un projet existant dans video_encoder |
| Montage → Encoder un DVD | Ouvrir le parcours du disque dans le lecteur |
| Montage → File d’encodage | Afficher la file actuelle dans video_encoder |
| Programmation TV → Planning | Guide et programmation actuels |
| Programmation TV → Enregistrements | Intentions et suivi des enregistrements TV |
| Outils | Inventaire et doublons, qualification et rapprochement, données d’application, crédits et déconnexion |

Le scan du DVD et son encodage restent indépendants. Scanner une édition ne
commande pas la lecture du disque ni un encodage. Le lecteur DVD reste piloté
par l’interface native de video_encoder, avec ses confirmations habituelles.

La page Montage utilise le protocole local déjà installé (`vidb-encoder`). Les
commandes sont signées pour le compte et le serveur configurés. Elles ne portent
aucun chemin de source et n’associent aucune fiche. La préparation depuis une
fiche conserve son parcours séparé et son choix explicite d’œuvre.

Une fois les deux correctifs validés, déployer vidb et relancer video_encoder
après la fin des encodages. Il n’est pas nécessaire de réinstaller le lanceur
du premier lot. Le lancement direct de video_encoder, avec ou sans fichier en
argument, reste disponible.

Contrôle manuel : ouvrir chaque menu à la souris et au clavier, vérifier les
deux entrées DVD distinctes, puis essayer les quatre commandes de Montage sur
Zeus. Annuler un sélecteur ou fermer le dialogue DVD ne doit pas déclencher une
autre commande ni modifier une association de fiche.
