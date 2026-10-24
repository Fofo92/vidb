# Consolidation par propositions

Depuis l’atelier « Qualification et rapprochement », ouvrir « Consolider les
propositions par lot ». Les deux axes restent indépendants : fiches et métadonnées,
fichiers et rattachements. La page affiche les propositions préparées par les
moteurs existants ; elle ne transforme pas un fichier non identifié en correspondance
certaine et ne crée pas de nouvelle règle automatique.

## Parcours pour l’existant

1. Filtrer par titre ou dossier, ou par numéro de fiche d’un arbre (descendants inclus).
2. Examiner les valeurs actuelles/proposées, les sources, les chemins et les motifs.
3. Cocher jusqu’à 30 propositions affichées et valider, différer ou écarter le lot.
4. La validation enregistre une décision précise et met une passe d’application en
   attente ; elle ne modifie directement ni les fiches ni les fichiers.
5. Le moteur habituel vérifie encore les empreintes, le placement et les fichiers
   avant d’appliquer. Une modification manuelle intervenue depuis la proposition
   bloque l’opération au lieu de l’écraser.

Les états « À examiner », « Validées, en attente », « À revoir », « Écartées » et
« Appliquées » restent consultables par filtre. Les cas sans proposition exploitable
restent dans les groupes d’exceptions. Les choix entre copies concurrentes se font
dans le détail de la famille ; une validation simple ne contourne pas cet arbitrage.
Pour qualifier plusieurs enfants, la vue existante « Qualifier les enfants » reste
complémentaire : elle permet une saisie directe, sans prétendre valider une source.

Une décision sur un cas prime sur une règle de famille déjà approuvée. Un report
ou un rejet persiste pour la même clé de cas après un nouveau scan. Une approbation
reste limitée à l’empreinte examinée : une proposition modifiée demande une nouvelle
validation. Les autres cas autorisés continuent à être traités. Les décisions et
leurs modifications sont conservées dans `reconciliation_case_reviews`, sans
copier les données du catalogue dans des rapports externes.

La page est signée pour son axe et ses seules propositions, pendant deux heures.
Elle refuse une sélection hors page, un périmètre devenu inactif ou déjà appliqué,
une version ancienne d’une règle et les demandes non authentifiées. Un double
clic identique ne crée pas une seconde demande d’application.

## Socle commun et suite video_encoder

`ReconciliationWorkbench::CaseReview` est le point commun d’enregistrement des
validations et de mise en attente. `Permission` applique la priorité entre choix
sur un cas et règles récurrentes ; l’exécuteur conserve tous ses contrôles.

Le raccordement de video_encoder est l’étape suivante, pas une fonctionnalité
annoncée comme déjà active dans ce lot :

- À l’enregistrement d’un projet, demander à vidb une identification et ses propositions.
- Associer directement une identité certaine ; présenter les candidates en cas de doute.
- Après validation, conserver un UUID de projet et un identifiant de fiche stable.
- À la fin de l’export, reprendre ces identifiants dans le reçu, vérifier le fichier
  final puis le rattacher. La création du projet ne vaut pas disponibilité.
- Permettre l’encodage pendant qu’une identification reste à compléter, avec reprise
  après indisponibilité de vidb ; une seule fiche par identité confirmée.

Ce raccordement utilisera les mêmes décisions explicites, et ne donnera pas à
video_encoder un accès direct à PostgreSQL. Le scan continuera de traiter les
fichiers ajoutés autrement et de vérifier la cohérence du disque.
