# Qualification des œuvres et rapprochement disque

Le chantier distingue deux résultats : une fiche documentée et une copie physique rattachée.
L’écran **Outils → Qualification et rapprochement** possède un onglet pour chaque axe.
Les compteurs ne confondent pas ces deux résultats. Une décision sur un axe n’approuve
aucune règle de l’autre axe.

## Fonctionnement par famille

1. Le service prépare les propositions à partir du dernier inventaire et des propositions sourcées.
2. L’écran présente la règle, ses limites, le nombre de fiches/fichiers concernés, les avant/après et les sources.
3. Une validation de famille autorise les cas équivalents de cette version de la règle.
   Les remplacements de valeurs existantes sont limités aux empreintes des propositions examinées,
   sur toutes les pages. Ils n’autorisent aucun futur remplacement.
4. Le même service applique toutes les familles autorisées, poursuit malgré une exception locale,
   renouvelle le bilan disque après les changements, puis traite les rattachements autorisés.
   Aucune limite artificielle de 20 ou 40 fichiers ne demande un nouveau lancement.
5. Les exceptions restent regroupées par nature et répertoire. Différer ou écarter une famille
   arrête ses prochaines opérations. Un arrêt demandé termine uniquement l’opération SQL en cours.

Aucune famille n’est approuvée à l’installation. Les actions d’actualisation et d’application
mettent le travail en attente ; les requêtes HTTP ne scannent pas `/videos`.

## Périmètre initial

| Axe | Automatisation fournie | Limites |
| --- | --- | --- |
| Caractéristiques | Qualification série/saison/épisode dans une hiérarchie déjà explicite | Aucun parent créé, aucun déplacement, aucun titre modifié |
| Caractéristiques | Année, résumé, pays, langue de fiche et genres documentés | Identité française/originale exacte, justification, sources HTTPS, provenance conservée |
| Disque | Copie unique, titre exact ou numéro et titre d’épisode concordants | Fiche qualifiée, placement cohérent, fichier stable 24 h, volume vérifié, pas de copie concurrente |

Les identités inconnues, les hiérarchies absentes, les homonymes, les doublons et les conflits de titre
restent à instruire. Cette version **ne recherche pas seule les sources externes** et ne prétend
pas résoudre automatiquement tout le stock en attente. Elle reçoit les résultats de recherche
sous un format commun, et regroupe leur examen au lieu de livrer un script par lot.
La langue de la fiche peut être transmise à la copie dans cette règle explicitement approuvée ;
les observations techniques audio restent conservées. Aucun fichier n’est déplacé, renommé ou supprimé.

## Préférence entre copies concurrentes

Une famille distincte compare les fiches ayant au moins deux copies présentes déjà rattachées.
Elle ne crée pas de nouvelle copie et ne supprime aucun fichier. Une préférence manuelle signalée
avec une provenance `manual` est conservée. L’approbation de la règle des rattachements uniques
ne vaut pas approbation de cette nouvelle famille.

La copie proposée doit réunir tous les critères suivants :

- Un export video_encoder dont le compte rendu enregistré correspond au fichier et au compte rendu actuel vérifié.
- Une date de modification du fichier plus récente que celles de toutes les autres copies.
- Une taille strictement inférieure, sans utiliser ce critère comme preuve de qualité.
- Toutes les langues et tous les sous-titres utiles antérieurs conservés, avec au moins une langue ou un sous-titre supplémentaire.
- Les rôles des pistes conservés (notamment sous-titres forcés et accessibilité), sans diminution du nombre de canaux audio.
- Des dimensions vidéo au moins équivalentes et des durées mesurées à deux secondes près.

Les langues absentes, `und`, `mul`, `zxx` ou privées comme `qaa` ne sont pas devinées depuis le nom
ou une simple étiquette VM. Les commentaires audio existants restent conservés, mais un commentaire supplémentaire
ne suffit pas à compter comme une version linguistique supplémentaire. Une durée très différente reste à examiner, y compris lorsqu’elle
s’explique par une suppression de publicités. Un fichier récent sans compte rendu exploitable
reste également à examiner. Une nouvelle observation technique doit précéder la comparaison si
la copie a changé depuis son rattachement.

L’écran expose les chemins, dates de fichiers, tailles, langues et le choix proposé.
Une seule décision de famille couvre les futurs cas équivalents ; les cas incomparables restent
bloqués sans empêcher les autres de progresser. L’application journalise une préférence provisoire,
affichée sur la fiche, et conserve les deux fichiers présents. Les modifications manuelles,
changements physiques ou nouvelles copies intervenus après la proposition bloquent son application.

**La qualité visuelle et la complétude éditoriale ne sont pas prouvées par ces critères techniques.**
Le futur module de qualité pourra compléter cette décision. Cette version ne libère donc pas
l’espace occupé par les anciens fichiers et n’autorise pas leur effacement automatique.
Le compteur des préférences est séparé de celui des nouveaux rattachements.

Les anciennes propositions d’import portant sur un même chemin déjà confirmé sont retirées
après vérification de la taille et de la date d’observation ; le coordinateur renouvelle alors
le scan pour remettre le bilan global à jour, sans réimporter ces copies.

## Durées des épisodes d’animation

La durée catalogue reste facultative et entière, avec une limite supérieure de 240 minutes.
Le minimum est de 3 minutes pour une fiche qualifiée comme épisode dont le genre Animation
est renseigné sur l’épisode, sa saison ou sa série. Les autres fiches conservent le minimum
historique de 10 minutes. Le nom de la série n’intervient pas dans cette règle.
Une qualification conserve la durée existante ; une valeur sous le seuil reste un blocage,
sans modification partielle de la hiérarchie. Les durées techniques des copies restent distinctes.

## Propositions issues de recherches externes

Document JSON importable dans l’onglet Caractéristiques ou avec
`bin/rails runner script/reconciliation_workbench.rb --proposals propositions.json` :

```json
{
  "format": "vidb.sourced_metadata_proposals",
  "version": 1,
  "proposals": [{
    "record_id": 123,
    "identity": {"french_title": "Titre exact dans vidb", "original_title": "Original exact ou null"},
    "field": "year",
    "value": 2020,
    "year_basis": "first_release",
    "reason": "Première diffusion attestée pour cette œuvre précisément identifiée.",
    "sources": ["https://www.arte.tv/fr/"]
  }]
}
```

Les sources doivent désigner les pages précises consultées ; l’URL ci-dessus est illustrative.
Utiliser la valeur JSON réelle de `original_title`, y compris `null` si le champ est nul.
`year_basis` vaut `first_release` ou `production`.
Autres champs : `abstract` (texte), `country_id`, `language_version_id` (identifiants existants),
`genres` (liste de noms existants). Le document entier est refusé si une proposition est invalide.
L’import enregistre des propositions, sans les approuver ni les appliquer.

## Durabilité

Les propositions, décisions versionnées, tentatives et résultats sont enregistrés en base.
Une opération et sa clôture SQL sont atomiques. Un travail terminé n’est pas rejoué ; une interruption
avant validation de la transaction laisse une tentative reprenable. Les instantanés d’une proposition
sont immuables. Les modifications manuelles intervenues depuis sa création bloquent son application,
même après retour à l’ancienne valeur par l’interface. Les transitions produites par le moteur sont
journalisées pour permettre plusieurs enrichissements indépendants sur la même fiche.

Un nouveau calcul conserve les instantanés des opérations en attente déjà autorisées.
Pour réexaminer un état modifié, différer la famille, actualiser ses propositions puis examiner
le nouveau périmètre avant de la valider. Les anciens instantanés ne sont jamais modifiés.
Les propositions remplacées restent consultables en base. Les règles récurrentes portent sur leur
version ; toute extension de leur portée exige une nouvelle version et une nouvelle décision.

Le verrou de service empêche deux coordinateurs de travailler simultanément. Les mutations SQL
verrouillent le catalogue et les copies sur PostgreSQL, puis revérifient identité et concurrence.
La vérification du volume et du fichier est répétée avant validation. Les scans utilisent le même
verrou de publication que le suivi existant, sans lancer les imports de sorties d’encodeur.

## Publication unique

Cette évolution appartient au dépôt Rails ; elle ne se déploie pas comme un lot documentaire.
Sur la machine de développement, après récupération de la branche :

```sh
bin/rails db:migrate
RAILS_ENV=test bin/rails db:migrate
bin/check
```

Après intégration de la branche à `main`, effectuer une seule sauvegarde explicite,
puis déployer le commit validé selon la procédure habituelle :

```sh
sudo /usr/local/bin/pg_backup_vidb_production.sh
bin/deploy-production COMMIT
```

`bin/deploy-production` ne réalise pas lui-même cette sauvegarde.
Après ce déploiement seulement :

```sh
/srv/vidb/current/bin/install-reconciliation-workbench
```

L’installation du timer est unique ; les éditions suivantes passent par les déploiements Rails.
Le service reprend les travaux en attente toutes les 30 secondes. L’écran Actualiser prépare les
familles à partir du dernier scan existant ; il ne produit pas un nouvel inventaire à chaque clic.
En mode application, les scans nécessaires s’enchaînent dans le coordinateur.
Après un arrêt demandé, une nouvelle passe doit être lancée explicitement dans l’interface.
`systemctl stop vidb-reconciliation-workbench.timer` suspend les nouveaux démarrages ; le bouton
Arrêter de l’écran demande un arrêt après l’opération en cours.

Vérifications locales disponibles dans l’environnement de préparation : tests des services et des
contrôleurs sur Rails 8.1 avec SQLite et un harnais local, RuboCop des fichiers Ruby ajoutés et
validation ERB des quatre vues. Le harnais ne remplace pas `bin/check` sur Ruby 4.0.6/PostgreSQL :
ces contrôles, l’authentification réelle et la couverture globale restent à exécuter avant publication.

### Présence sur disque et copies candidates

« Actualiser les propositions » demande maintenant un scan complet avant la préparation des familles. Le même contrôle de présence est exécuté par le rafraîchissement automatique. Après validation du montage et du scan, une copie enregistrée dont le chemin a disparu devient **introuvable** (`missing`), conserve son historique et cesse de compter pour la disponibilité. Une autre copie présente peut maintenir l’œuvre disponible. Aucun fichier ni fiche d’œuvre n’est supprimé. Le retour d’un fichier ne restaure automatiquement la présence que si taille et date restent compatibles avec sa dernière observation technique. Les copies explicitement supprimées ne sont jamais restaurées par un scan. Un scan incomplet, un changement pendant le contrôle ou une perte du montage annule la synchronisation.

Un fichier candidat face à une copie déjà enregistrée rejoint désormais la famille de comparaison, au lieu du rattachement unique. La version 2 de cette règle doit être validée séparément : elle peut rattacher le candidat et enregistrer la préférence dans une seule transaction. La copie privilégiée peut être celle déjà enregistrée. Le rattachement conserve les mesures techniques et le reçu video_encoder validé lorsqu’il existe ; aucune langue n’est déduite du suffixe du fichier. En cas d’échec SQL ou de contrôle physique, rattachement, préférence et clôture du cas sont annulés ensemble. Les comparaisons sans gagnant démontré restent à examiner et ne bloquent pas les autres cas. Plusieurs nouveaux candidats pour la même œuvre ne sont pas départagés automatiquement.

Convention linguistique de la vidéothèque : une **seule piste audio**, explicitement marquée `und`, est interprétée comme française (`fra`, équivalent de `fre`) pour comparer les copies. Cette hypothèse est affichée dans la proposition et conservée avec les capacités calculées ; les mesures brutes et le fichier ne sont pas modifiés. La convention ne s’étend ni aux sous-titres, ni à plusieurs pistes audio, ni à une langue absente ou privée (`qaa`). Les autres critères de préférence restent exigés.
