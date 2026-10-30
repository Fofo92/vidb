# Réexaminer le choix de fiche d'un montage

Une identification réussie fournit désormais `selection_url`, un lien signé
vers le choix de fiche locale. Le contexte inclut l'association courante attendue.
Le lien reste lié au compte vidb, au projet et à la durée de validité habituelle.
Il ne modifie aucune association par sa seule consultation.

Un formulaire de révision demande une confirmation explicite, pour les choix
locaux comme pour la préparation d'un film ou d'un épisode. Le serveur vérifie
que l'association courante correspond encore à celle du contexte signé.
Un choix devenu périmé est refusé et doit être rouvert depuis video_encoder.

AssociationRevision utilise la transaction et le verrou de projet existants.
Les anciennes propositions appliquées sont désactivées, sans effacer leur état
ni leur résultat. Le nouveau choix utilise ensuite les contrôles habituels de
qualification, instantanés et autorisation. Une erreur restaure l'association
précédente par annulation de la transaction. Sans contexte de révision signé,
la protection existante contre le remplacement d'une autre fiche reste active.

Les reçus d'encodage antérieurs conservent leur liaison signée et continuent de
désigner leur fiche d'origine. La révision vise les prochains enregistrements
du projet, sans déplacer ni réattribuer une copie déjà importée.
