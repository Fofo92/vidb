# Identifier les projets avant l’encodage

La passerelle associe les projets video_encoder aux fiches existantes ou préparées
depuis la fenêtre d’identification.
Une correspondance certaine utilise les mêmes règles que le rapprochement disque :
titre unique pour une vidéo autonome, série/saison/numéro/titre concordants pour
un épisode. Un épisode homonyme trouvé globalement n’est jamais accepté automatiquement.
Les fiches doivent avoir une nature et un placement qualifiés. Aucun état de la
fiche ni aucune copie n’est modifié pendant cette identification.

## Installation

Appliquer et vérifier les correctifs dans les deux dépôts. Déployer vidb, puis
exécuter depuis son dépôt de développement, avec le compte pascal (sans sudo global) :

```sh
bin/install-encoder-project-bridge https://zeus.fodiman.fr
```

Si vidb contient plusieurs comptes, préciser le numéro du compte qui sera attribué
aux demandes de cette installation : ajouter `USER_ID` à la commande. Le script
réutilise le secret existant lors d’une réinstallation ; il ne l’affiche pas.
Le serveur conserve sa configuration sous `/srv/vidb/shared/encoder-bridge/server.json`
(mode 0600, compte vidb). Le client est configuré sous
`~/.config/video_encoder/vidb.json` (mode 0600, compte courant), ou sous XDG_CONFIG_HOME.
Le secret sert uniquement à l’API des projets ; il n’est jamais placé dans les projets
ni dans leurs reçus et ne donne aucun accès direct à PostgreSQL.

Recharger video_encoder après la fin des travaux en cours pour charger son nouveau code.

## Parcours

À l’enregistrement d’un projet destiné à `/videos`, video_encoder conserve son UUID
et demande son identification à `POST /encoder_projects/identify`, en HTTPS avec
un secret dans l’en-tête Authorization. La demande contient l’UUID, les chemins du
projet et de la sortie prévue et les sources ; elle ne transmet aucun état de
visionnage ou de disponibilité.

- Cas certain : la décision précise et son application sont journalisées dans
  l’atelier ; un lien signé vers la fiche est retourné.
- Cas douteux : des propositions apparaissent dans la file de consolidation. Le
  bouton de video_encoder ouvre cette file filtrée sur l’UUID. Cocher une seule
  fiche puis valider ; les propositions concurrentes sont ensuite désactivées.
- Fiche manquante : les formulaires permettent de consulter les sources et de
  préparer un film ou un épisode après confirmation. Une série absente peut être
  créée avec ses épisodes documentés ; une série existante peut être complétée.
  Une fiche non qualifiée ou une identité ambiguë nécessite un examen préalable.
  Voir [Préparer un épisode](encoder-episode-creation.md) et
  [Créer une série absente](missing-series-preparation.md).
- vidb indisponible : le projet reste enregistré et peut être encodé. La demande
  reste dans le document de projet pour une reprise ultérieure.

La famille « Associer les projets video_encoder à leurs fiches » ne peut pas être
validée globalement : seules les décisions sur un cas précis peuvent choisir une
fiche. Une décision différée ou écartée n’est pas réapprouvée automatiquement à la
sauvegarde suivante. Les fiches et les fichiers gardent leurs validations distinctes.

Le lien signé reste stable lors d’un déplacement du projet. Créer un nouveau montage
réinitialise son UUID et son association. Les documents de projet restent en version 2 ;
les clés optionnelles `project_id` et `vidb` sont ignorées par les anciens lecteurs.

## Fin d’export et reprise

Le reçu terminé transporte l’UUID et, si disponible, le lien signé. Le scan habituel
peut rattacher la sortie à cette fiche même si son nom a changé ou si le rapprochement
par titre reste ambigu. Il conserve les vérifications de signature du fichier,
taille, date, pistes, durée, placement et historique de copie.

Une validation effectuée après l’encodage est aussi retrouvée par UUID. Si la demande
avait échoué faute de vidb, le scan peut la reprendre depuis le projet d’origine :
le JSON doit être un fichier régulier sous `/videos`, avoir exactement le SHA-256 du
reçu et porter le même UUID. Un projet modifié ou introuvable n’est pas utilisé pour
inventer une nouvelle association. Les cas en attente d’une décision sur le projet
ne sont pas contournés par un rattachement automatique au seul nom du fichier.
Les anciens reçus sans UUID gardent le comportement antérieur pour les épisodes.

Cette intégration ne change ni les commandes d’encodage, ni leurs paramètres audio
ou vidéo, ni le comportement de la ShuttleXpress.
