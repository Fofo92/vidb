# Propositions linguistiques des copies

Le rapport reste en lecture seule. Il ne modifie ni les copies ni les fiches.

## Convention commune mise à jour le 16 octobre 2026

### Œuvres muettes

La version « Muet » (code `MUET`) décrit une œuvre sans dialogue parlé, même
si sa copie contient une musique ou un accompagnement sonore. Elle est
sélectionnable sur une fiche et sur une copie. Une qualification déjà existante
libellée « Muet » est réutilisée sans imposer un changement de son ancien code.

Une fiche explicitement qualifiée Muet permet de proposer cette qualification
pour une copie stable encore non qualifiée, avec la provenance
`declared_silent_work`. Les protections de volume, d’identité et de réobservation
restent applicables avant écriture. Une piste musicale, même étiquetée française,
ne déclenche pas VF dans ce cas. L’absence de piste audio ne suffit jamais,
à elle seule, à reconnaître une œuvre muette.

La fiche peut être qualifiée avant encodage. Cela ne crée aucune copie et ne
prouve aucune disponibilité. Aelita est actuellement en attente d’encodage :
sa fiche doit être examinée et corrigée indépendamment de la future sortie.

Une qualification déjà enregistrée sur une copie est conservée. Un projet JSON
exploitable associé à cette copie est prioritaire. Sinon, en l’absence de projet,
une seule piste audio implique VF, sauf mention explicite VO/VOST dans le nom
ou le titre. Le suffixe VF et une étiquette audio française ne sont pas requis.
Cette convention accepte le cas résiduel rare d’une VO/VOST non signalée avec
une seule piste et des sous-titres éventuellement incrustés.

Les mentions VO, VOST et VOSTFR sont reconnues, y compris entre parenthèses ou
crochets. VOST explicite peut correspondre à des sous-titres incrustés sans piste
séparée. Des mentions contradictoires ou un VO/VOST explicitement marqué face à
une piste déclarée française restent à examiner.

L’absence d’information externe n’impose donc pas une validation systématique.
Ce sont l’ambiguïté ou la contradiction qui la justifient. Un projet présent
mais illisible, incomplet ou contradictoire ne déclenche pas silencieusement le
raccourci VF. Les pistes multiples non interprétables restent à qualifier.

Les pistes finales déterminent le nombre de pistes exportées; le projet aide
à interpréter leurs rôles. Il ne suffit pas de compter les pistes sources.

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
script après déploiement pour produire le rapport version 3.

Politique de référence :
https://github.com/Fofo92/video_encoder/blob/main/docs/domain/track_selection.md
https://github.com/Fofo92/video_encoder/blob/main/docs/architecture/track_selection.md

Quand un compte rendu `.mkv.video_encoder-export.json` accompagne le fichier,
son chemin de sortie, sa taille, sa date de modification et l’empreinte SHA-256
du projet doivent correspondre. Sans compte rendu historique, l’association
reste fondée sur le même nom et la chronologie : elle est explicitement indiquée
comme `legacy_same_name_and_chronology`, sans inventer de preuve cryptographique.
Les liens symboliques des projets et comptes rendus ne sont pas suivis.

## Application automatique ciblée

`AutomaticLanguageQualification` réobserve le fichier avec ffprobe, contrôle le
volume attendu et réutilise les vérifications transactionnelles de `LanguageBatch`.
Les pistes sont à nouveau observées avant écriture. Les propositions encore
ambiguës restent en attente. Le service ne modifie ni la langue de la fiche,
ni le chemin, ni le contenu du fichier. Une qualification préexistante reste intacte.

La provenance mentionne `vidb (politique automatique)` et
`source_report.manual_listening: false`; elle n’attribue aucune écoute à Pascal.
La commande ciblée sur 355 est `bin/rails runner script/qualify_355_language.rb --apply`.
Elle exige le film 3879, sa copie 1445, le genre Espionnage et vidb_production.

### Ancien suffixe VF face à deux pistes finales identifiées

En l’absence de projet JSON, des pistes finales explicitement identifiées en
français et anglais, sans aucune piste de sous-titres, suffisent à qualifier VM.
Un ancien suffixe VF ne bloque pas cette conclusion : c’est le cas de 355.
Les langues indéterminées, les sous-titres présents ou une mention explicite
VO/VOST contradictoire ne déclenchent pas ce raccourci. La provenance conserve
les pistes observées et la raison de la qualification automatique.
