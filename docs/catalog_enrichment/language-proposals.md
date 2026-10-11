# Propositions linguistiques des copies

Le rapport reste en lecture seule. Il ne modifie ni les copies ni les fiches.

Les pistes observées du fichier final priment sur les pistes sources du projet.
Les suffixes VF, VO, VOST, VM et VMST sont relevés dans le nom du fichier.
Des indications contradictoires empêchent une proposition automatique.
Un suffixe VF peut qualifier une piste unique sans langue déclarée ; il ne
transforme pas plusieurs pistes indéterminées en une VF.

Un projet voisin portant exactement le même nom, avec l'extension JSON,
permet de reconnaître la convention de video_encoder. Le format accepté est
`video_encoder.trim_project`, version 2. Seules les sources effectivement
utilisées par les segments sont examinées. Les rôles français et original
doivent être présents dans toutes ces sources, hors audiodescription.

Selon la politique documentée de video_encoder, `qaa` désigne le rôle original,
sans identifier sa langue réelle. Les pistes finales permettent de proposer :

| Audio final | Sous-titres français ordinaires | Proposition |
| --- | --- | --- |
| Français | Indifférent | VF |
| Français et qaa | Absents | VM |
| Français et qaa | Présents | VMST |
| qaa seul | Absents | VO |
| qaa seul | Présents | VOST |

Les sous-titres forcés seuls ou pour malentendants ne suffisent pas à proposer
une version sous-titrée ordinaire. Les indices des pistes sources et finales
ne sont pas assimilés : l'export peut supprimer et réordonner les pistes.

La copie doit exister, avoir la taille enregistrée, ne pas avoir été modifiée
depuis l'observation et avoir au moins 24 heures sans modification. Ce délai
est une précaution ; il ne constitue pas une preuve de succès de l'export.
Le projet ne doit pas être plus récent que la copie, afin de ne pas appliquer
un montage nouvellement enregistré à une ancienne sortie.
Un projet seul, même valide, ne prouve jamais qu'une copie est disponible.
Le rapport examine uniquement les copies déjà confirmées, sans parcourir les
projets en attente ou les fichiers temporaires des espaces de travail.

Un projet illisible ou incomplet est signalé dans `encoder_evidence` et ne
permet pas d'interpréter qaa. Les anciennes qualifications sont conservées.
Les rapports précédents ne comportent pas ces informations : relancer le
script après déploiement pour produire le rapport version 2.

Politique de référence :
https://github.com/Fofo92/video_encoder/blob/main/docs/domain/track_selection.md
https://github.com/Fofo92/video_encoder/blob/main/docs/architecture/track_selection.md
