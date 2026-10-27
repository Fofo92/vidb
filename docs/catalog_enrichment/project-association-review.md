# Choix d’une fiche pour un montage

Une identification incertaine ouvre une page dédiée au projet signé et au compte courant.
Elle ne montre que les propositions actives de ce projet, avec la source, la destination provisoire
et le placement série / saison / épisode. Les propositions d’autres projets ne sont pas supprimées.

L’utilisateur peut associer explicitement un film ou un épisode correctement placé.
La validation utilise les contrôles de périmètre, de fraîcheur des propositions et d’exclusivité existants.
Elle ne crée aucune copie, ne renomme aucun fichier et ne modifie aucun état de visionnage.
La confirmation utilise le même signal de reprise dans video_encoder que la préparation d’un épisode.

Une série ou une saison propose les champs distincts Saison et Épisode et ouvre la préparation existante.
Une fiche de nature indéterminée reste à qualifier ; elle n’est pas convertie automatiquement.
Les anciennes demandes restent consultables dans l’atelier général, avec leur historique.
