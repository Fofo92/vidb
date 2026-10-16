# Résumés : enrichissement externe et corrections éditoriales

## Règle commune

Un résumé absent peut être complété par une source externe, même si sa rédaction
n’est pas parfaite, dès lors que le rapprochement avec l’œuvre ne prête pas à
confusion. L’absence d’une autre information externe ne constitue pas, à elle
seule, un motif de validation systématique.

Une saisie, une correction ou une suppression manuelle du résumé doit ensuite
être préservée. Une source ne peut la remplacer qu’après une intervention
éditoriale explicite. Cette première étape porte sur `Record.abstract` ; elle
ne prétend pas ajouter la même provenance aux autres champs du catalogue.

## Provenance

`abstract_provenance` est un objet JSON contenant la nature de la dernière
écriture, son horodatage et l’empreinte SHA-256 du texte exact. Une écriture
externe contient aussi l’identification de la source.

- `manual` : écriture locale sans contexte source externe explicite. Aucun nom
  d’auteur ou validation personnelle n’est inventé. Une suppression depuis un
  texte non vide produit cette même protection, même si le résultat est vide.
- `external` : écriture par `CatalogEnrichment::AbstractEnrichment` après
  rapprochement confirmé. La source conserve `provider` et `external_id` ;
  une date de collecte absente reste absente ou nulle.
- `{}` : origine historique inconnue. Un ancien résumé non vide est conservé
  sans le déclarer rétroactivement manuel ou externe. Un champ déjà vide sans
  historique est disponible pour enrichissement : on ne peut pas reconstituer
  une suppression antérieure au déploiement.

L’enregistrement d’un formulaire vide sur un champ déjà vide ne crée pas une
fausse suppression manuelle. Les autres modifications d’une fiche ne changent
pas la provenance du résumé. Les paramètres HTTP de provenance ne sont pas
acceptés par le contrôleur.

## Enrichissement et validation

Le service exige un texte ou nil, une source structurée et
`identity_confirmed: true`. Ce dernier argument est une affirmation du code
appelant après ses contrôles de rapprochement, pas une preuve issue du nombre
de pistes, d’une recherche approximative ou du simple titre. Par défaut, il
est faux. La seule intégration externe actuellement trouvée dans les écritures
applicatives est le writer de hiérarchie TMDB ; celui-ci est appelé après la
validation et le verrouillage du plan de rapprochement.

La prévisualisation renvoie le texte actuel, le texte proposé, la source et le
statut sans écriture. L’application recharge la fiche sous verrou et recalcule
la décision : une correction faite après la prévisualisation est donc préservée.
Une réponse externe vide n’efface jamais un texte existant.

Un texte précédemment importé peut être actualisé automatiquement uniquement
si son empreinte est intacte et si la source désigne le même fournisseur et
le même identifiant externe. Toute écriture éditoriale locale lui retire cette
possibilité. Une empreinte incohérente est également protégée, même lorsqu’une
écriture directe a contourné les callbacks ordinaires du modèle.

| Statut | Conséquence |
| --- | --- |
| `candidate` | Complément ou actualisation admissible en prévisualisation |
| `applied` | Texte et provenance enregistrés ensemble |
| `unchanged` | Texte identique, aucune nouvelle écriture |
| `no_candidate` | Source vide, aucune suppression |
| `needs_review` | Rapprochement ou source insuffisamment établis |
| `protected` | Résumé local ou historique à conserver |
| `source_changed` | Autre fournisseur ou autre identifiant : rapprochement à revoir |

Pour accepter un texte de remplacement après lecture, on modifie le résumé
dans la vue d’édition existante puis on sauvegarde. Ce geste vaut validation
éditoriale et le texte obtenu reste protégé. Aucun bouton permettant une
levée permanente de protection n’est ajouté. Le service ne fournit pas de
paramètre `force` ou d’acceptation automatique des propositions protégées.

Les propositions renvoyées par le service ne constituent pas une file de
validation persistante. Dans l’import TMDB, le texte source reste conservé dans
`CatalogueEpisodeLink.evidence.overview_fr` ; `abstract_application` indique
s’il a été appliqué ou protégé. L’import des autres métadonnées peut continuer
sans écraser le résumé. Aucune nouvelle interface générale de comparaison des
sources n’est incluse dans cet incrément.

## Limites des écritures directes

Les écritures sources doivent passer par le service. Un `update_all`, un
`update_columns` ou du SQL direct ne déclenche pas les callbacks Rails et ne
constitue pas une API d’enrichissement autorisée. Le contrôle d’empreinte protège
une actualisation ultérieure par le service ; il ne bloque pas l’exécution de
SQL arbitraire possédant les droits de mise à jour en base.

La migration ajoute uniquement un champ de provenance vide, sans modifier les
résumés, les états de disponibilité, les copies ou les fichiers vidéo.
