# Métadonnées des séries et saisons

Une série ou une saison est un conteneur. Cette étape conserve toutes les valeurs enregistrées : aucun nettoyage ni migration de données.

| Information | Série | Saison | Film ou épisode |
|---|---|---|---|
| Résumé | Résumé général propre | Facultatif | Résumé propre |
| Pays, genres | Référence commune explicite | Héritage, sauf valeur propre | Valeur propre prioritaire, sinon héritage |
| Années | Plage des années des vidéos connues | Même règle | Année propre et provenance |
| Durée | Somme des vidéos connues | Même règle | Copies mesurées, sinon durée de fiche |
| Version, support | Synthèse des vidéos connues | Même règle | Copies présentes, sinon valeur de fiche |
| Disponibilité, état vu | Compteurs des vidéos connues | Même règle | État propre |

Les copies alternatives ne s’additionnent pas : leurs durées produisent une plage. Les parties d’un épisode s’additionnent lorsqu’elles couvrent toutes les parties attendues. Une durée inconnue rend la synthèse partielle. Les durées de fiches complètent les mesures disponibles sans modifier les données.

Un ensemble vide ne reçoit aucune durée, langue ou support par défaut. La présence de toutes les vidéos connues dans vidb ne prouve pas que tous les épisodes diffusés existent dans la bibliothèque.

L’audit distingue vidéos, séries, saisons et fiches à qualifier. Il compte les lacunes des années, langues et supports uniquement sur les vidéos. Un pays ou genre commun manquant est signalé sur la série ; ses enfants n’ajoutent pas la même lacune au compteur. Une synthèse issue des enfants peut être affichée sans remplacer la référence commune à renseigner sur la série. Les valeurs explicites et les exceptions restent intactes.

Les filtres pays et genres utilisent les valeurs affichées, y compris héritées. Les autres filtres conservent leurs règles existantes. Les tableaux restent compacts ; les précisions de provenance restent dans le détail.

La collection de films sera une entité distincte avec des membres ordonnés. Un film pourra appartenir à plusieurs collections sans changement de son placement. Cette étape ne crée pas encore cette entité.
