# Qualification des œuvres et rapprochement disque

Le chantier distingue deux résultats : une fiche documentée et une copie physique rattachée.
L’écran **Outils → Qualification et rapprochement** possède un onglet pour chaque axe.
Les compteurs ne confondent pas ces deux résultats. Une décision sur un axe n’approuve
aucune règle de l’autre axe.

## Fonctionnement par famille

Le déclenchement automatique compare la date du bilan avec la passe la plus récente
(date de création, puis identifiant décroissants), pas avec la première passe de
l’historique. Un scan déjà pris en charge ne crée pas de passe supplémentaire ;
le dernier arrêt explicite reste respecté et une reprise manuelle ultérieure le remplace.
Les mesures techniques collectent durée, conteneur et pistes dans un seul appel à
`ffprobe`. Le contrôle du fichier avant/après et la vérification du stockage restent
effectués. Cette réduction du nombre de sondes ne constitue pas une mesure du gain
de temps global sur la vidéothèque.

La famille **Créer les séries absentes depuis leurs guides documentés** utilise le
même dossier JSON de préparation. Un groupe peut fournir `proposed_new_root`, avec
`french_title` et éventuellement `original_title`, à la place de `proposed_existing_root`.
Le nom de la série dans `reference_show.name` doit correspondre à l’une de ces identités.
Chaque épisode conserve les contrôles de titre, numéro, chemin, unicité du rang et source.
Une identité de série concurrente bloque la création à la préparation ou à l’application.
Les épisodes homonymes d’œuvres extérieures ne sont ni déplacés ni modifiés : le guide
documente l’identité propre à la nouvelle série. Les protections des séries existantes
ne changent pas.

L’approbation de cette famille couvre uniquement les propositions affichées. La série,
ses saisons et les épisodes prêts sont créés dans une seule transaction ; un échec ne
laisse aucune création partielle. La langue initiale `IND` / `Indéterminée` est créée si
nécessaire, sans déduire les pistes des fichiers de la langue originale de l’œuvre.
Un réimport du dossier déjà appliqué retrouve son reçu, sans recréer la série. Les
exclusions restent visibles après application. Les rapprochements disque et années
sourcées conservent leurs autorisations distinctes.

Le lecteur de chemins ignore les seuls dossiers de rangement `vus`, `vues`, `_vus`
et `_vues`, ce qui permet de retrouver la vraie série au-dessus du dossier de saison.
Un autre dossier intermédiaire reste significatif ; aucun répertoire n’est renommé.
Ces dossiers sont transitoires. La convention cible reste le préfixe `[*] ` en tête
du nom du fichier, pas dans le titre de la fiche. Ce marqueur est ignoré pour
l’identification. Lors de la création d’une nouvelle série documentée, les épisodes
dont le chemin indique déjà ce visionnage sont proposés avec `is_seen=true` ; les
états des fiches existantes restent conservés. La suppression des dossiers `_vus`
attendra une migration physique distincte : marquage des épisodes vus, remontée des
fichiers avec mise à jour des chemins en base, puis suppression des seuls dossiers
vides. La tolérance actuelle de lecture ne réalise aucune de ces opérations.

Après validation d’une famille, la confirmation affiche le nombre de propositions
autorisées et le numéro de la demande d’application. Une demande en attente n’est pas
encore prise en charge par le service. Le panneau de suivi actualisé toutes les cinq
secondes montre les validations enregistrées, les propositions autorisées en attente,
en cours et bloquées, ainsi que les applications conservées dans l’historique avec
l’heure de la dernière application. Il garde les résultats visibles après une application
rapide ; il ne présente pas un ancien succès comme celui d’une nouvelle demande.
Les demandes actives restent visibles même si des passes plus récentes sont terminées.

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
| Caractéristiques | Structures de séries documentées : créations, réutilisations et correction explicite d’un rang de saison | Approbation des seules propositions affichées ; homonymes, déplacements de fiches et numérotations divergentes exclus |
| Caractéristiques | Année, résumé, pays, langue de fiche et genres documentés | Identité française/originale exacte, justification, sources HTTPS, provenance conservée |
| Disque | Copie unique, titre exact ou numéro et titre d’épisode concordants | Fiche qualifiée, placement cohérent, fichier stable 24 h, volume vérifié, pas de copie concurrente |

Les identités inconnues, les hiérarchies absentes, les homonymes, les doublons et les conflits de titre
restent à instruire. Cette version **ne recherche pas seule les sources externes** et ne prétend
pas résoudre automatiquement tout le stock en attente. Elle reçoit les résultats de recherche
sous un format commun, et regroupe leur examen au lieu de livrer un script par lot.
La langue de la fiche peut être transmise à la copie dans cette règle explicitement approuvée ;
les observations techniques audio restent conservées. Aucun fichier n’est déplacé, renommé ou supprimé.

## Dossier de structures de séries

Dans **Caractéristiques des œuvres → Ajouter des propositions documentées**, charger le JSON
de préparation (par exemple `plan-22-series.json`, extrait de l’archive de recherche).
Le format accepté est `vidb.series_structure_preparation`, version 1. Le même chargeur est
disponible avec l’option `--proposals` du script de l’atelier. Limite HTTP : 2 Mio.

Le document comporte `groups`, `series_group_count`, `file_count`, `inventory_at`, `inputs`
et `reference_attribution`. Chaque groupe indique son répertoire, sa série existante proposée
(ou `null`), les autres racines homonymes, son URL de référence et ses fichiers. Les fichiers
portent le titre observé, les numéros locaux, les candidats de saison et les références
`reference_same_number` avec titre, saison, numéro et URL HTTPS. Les étiquettes de confiance,
les opérations descriptives et les autres suggestions du dossier ne sont pas exécutées.

Le chargeur contrôle les identités partielles du dossier contre les fiches actuelles, puis
capture leurs instantanés complets. Il recalcule les concordances titre/numéro et recherche
les titres français et originaux dans tout le catalogue. Une fiche concordante ne peut être
réutilisée que si elle est déjà au bon emplacement. Un titre trouvé ailleurs reste à arbitrer :
un homonyme n’autorise pas un déplacement. Une nouvelle fiche n’est proposée qu’en l’absence
de concurrent. Une saison explicitement nommée peut recevoir son bon rang si celui-ci est libre.
Les épisodes multiples, traductions non concordantes, références génériques, saisons spéciales,
racines absentes ou concurrentes et rangs concurrents restent affichés parmi les exclusions.

Les nouvelles fiches de saison portent un numéro sans zéro initial : `Saison 3`, `Saison 4`,
`Saison 5`. Les dossiers du disque peuvent porter `Saison 03`, `Saison 04`, `Saison 05` :
le rapprochement compare le numéro. La création d’une fiche ne renomme aucun dossier,
et les titres des saisons existantes restent conservés.

Les dates originales `airdate` au format ISO dans les références concordantes préparent aussi
des propositions d’année pour les épisodes déjà identifiés. Le groupe peut fournir
`season_references`, avec `season`, `airdate` et `url`, pour la première diffusion de chaque
saison. Cette date provient du guide complet, et non du premier fichier présent sur le disque.
La convention est `first_release`. Les années sont traitées par la famille existante
**Compléter : année de référence**, avec son approbation propre ; approuver une structure
ne valide pas implicitement ses années. Les valeurs déjà renseignées et les provenances
protégées, même sans année, restent intactes. Les nouvelles fiches préparent ces propositions
dans la transaction de création. Si la règle d’année est déjà approuvée, le service les
enchaîne dans la même passe ; un cas bloqué n’est tenté qu’une fois par passe.

Les opérations terminées ne sont pas proposées à nouveau, mais leurs fichiers laissés de côté
restent visibles en lecture seule avec les motifs conservés. Les anciens dossiers non traités
d’une autre version sont également signalés. Un compteur de propositions à zéro ne signifie
donc pas que tous les fichiers ont été rapprochés.

La création d’une fiche et l’enrichissement de son année ne prouvent pas qu’une copie a été
rattachée. Les états d’une saison se lisent à partir de ses épisodes. `is_recorded` conserve
l’historique d’enregistrement ; la présence actuelle des copies concerne `is_available`.
L’absence actuelle d’un fichier n’efface pas automatiquement cet historique.

La politique `wikipedia_fr_first_v1`, appliquée par le code, privilégie les références de
Wikipédia en français pour les titres et la numérotation des épisodes, puis les autres éditions
de Wikipédia, puis les autres sources en l’absence de référence Wikipédia pour le cas.
Le domaine HTTPS réel est contrôlé, sans se fier à une étiquette de fournisseur. Les références
au même numéro et les correspondances proposées à d’autres numéros sont considérées ensemble :
une référence Wikipédia contradictoire ne peut pas être contournée en choisissant un autre guide.
Les incohérences restent à arbitrer ; la préférence de source n’autorise pas une renumérotation,
un déplacement ou un remplacement des titres déjà établis. La politique et les références
retenues sont conservées dans la proposition et affichées avant validation.
Pour une nouvelle fiche, la graphie française de Wikipédia est retenue lorsque son titre
concorde avec celui du fichier après normalisation des accents, de la casse et de la ponctuation.
Le titre proposé est affiché. Les fiches existantes gardent leur titre ; une variante de traduction
qui ne concorde pas ne devient pas équivalente par cette seule priorité de source.

Le chargeur exploite les références du dossier ; il ne télécharge pas automatiquement Wikipédia.
Les titres et numéros doivent donc être présents dans le dossier, avec leurs URL. Les autres
sources restent utilisables pour compléter les références absentes. Cette nouvelle politique
porte la famille des structures documentées à la version 2 : les validations de la version 1
ne l’approuvent pas. Réimporter le dossier puis examiner et valider le nouveau périmètre.

Le numéro explicite `Sxx Eyy` peut être précédé du nom français/original de la série ou de
son sigle, par exemple `Code quantum S03 E04 - …` ou `MAP - S07 E01 - …`. Le préfixe doit
correspondre à la fiche de série existante, et non à une simple étiquette du dossier. Un préfixe
inconnu, plusieurs numéros explicites ou un numéro/titre différent restent exclus. Aucun fichier
n’est renommé. Une série sans opération applicable affiche le décompte de ses motifs d’exclusion
au lieu d’un message global d’identité ambiguë.

## Retirer le nom de série devant le numéro d’épisode

La convention de fichier reste `S03 E04 - La corde raide.avi`. L’acceptation d’un préfixe
dans le lecteur ne remplace pas le renommage demandé. Pour les vidéos encore non rattachées,
le script `script/video_asset_episode_prefix.rb` prépare puis applique ce changement dans un
répertoire explicitement choisi. Il ne recherche pas d’autres séries sur le disque.

```bash
bin/rails runner script/video_asset_episode_prefix.rb \
  --directory '/videos/Séries TV/_incomplet/Code Quantum (V - 93_96)' \
  --series-title 'Code Quantum' \
  --journal /srv/vidb/shared/episode-prefix-renames/code-quantum.jsonl
```

Sans `--apply`, la commande affiche le plan sans écrire de fichier ou de journal.
Ajouter `--apply` exécute tous les renommages préparés dans cette série. Le processus doit
avoir accès à la base et le droit de renommer les fichiers du répertoire. Pour la production,
utiliser le contexte de service avec `/etc/vidb/vidb.env`, le Ruby et le bundle déployés.

Le titre et l’extension sont conservés ; seuls le préfixe et la présentation des numéros
changent. Les fichiers déjà nommés `Sxx Eyy` ne sont pas touchés. Le volume est contrôlé,
le plan complet est préparé avant le premier déplacement, les destinations occupées et les
compagnons à traiter sont refusés. `renameat2(RENAME_NOREPLACE)` assure qu’aucun fichier
n’est écrasé. Le journal privé est synchronisé sur disque avant les opérations. La reprise
reconnaît un fichier déjà renommé et termine seulement son journal ; une autre identité
physique bloque la suite. Les fichiers déjà rattachés à une copie non supprimée sont refusés
avant tout déplacement : ils relèvent de la procédure de déplacement avec mise à jour SQL,
et ne doivent pas être transformés en copies manquantes par cette commande.

Après application, une actualisation du rapprochement est demandée. Charger ensuite les
propositions utilisant les nouveaux chemins. Ne pas approuver de rattachement sur les anciens
chemins avant ce renommage. La série Code Quantum de 2022, dans son autre répertoire, reste
hors du périmètre indiqué ci-dessus.

La famille **Compléter les structures de séries documentées** présente toutes les séries,
leurs créations et réutilisations par saison, les corrections de rang, la langue héritée par
les nouvelles fiches, les sources et les cas laissés de côté. Une validation porte sur les
empreintes actuelles de cette famille, et n’approuve aucun dossier futur. L’ancienne règle
de qualification des hiérarchies existantes n’autorise pas ces créations.

L’application est une transaction par série : qualification, création, correction et reçu
réussissent ensemble ou sont annulés ensemble. Les titres et autres métadonnées existantes
restent intacts. Une modification manuelle, même annulée ensuite, bloque la reprise ; une
nouvelle fiche concurrente bloque également la création. Une reprise conserve les instantanés
approuvés et ignore les séries déjà appliquées. Les reçus gardent les identifiants créés/réutilisés
et les références des épisodes ; le dossier n’est pas jeté après application.

Après les changements du catalogue, le service renouvelle son observation et prépare les liens
avec le disque. Il les applique dans la même passe **uniquement si leur propre règle est déjà
approuvée** et si les contrôles habituels passent. Un épisode créé ne constitue donc pas encore
une copie confirmée. Les compteurs du catalogue et des copies doivent être lus séparément.

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

### Arbitrages groupés des copies

La famille de comparaison propose désormais, pour chaque épisode mesuré, « laisser à examiner » ou une copie à privilégier. Une suggestion peut être présélectionnée à partir de la date, de la taille, du nombre de pistes, de la durée et de la définition. Ce conseil ne garantit ni les langues ni la qualité visuelle et ne rend jamais une comparaison incertaine automatiquement applicable. Les codes réellement relevés, la durée, la définition et les détails des pistes restent consultables.

Le formulaire **Confirmer les choix de cette page** enregistre les choix sélectionnés en une transaction, avec une justification commune facultative. Il ne concerne que les propositions affichées sur cette page (30 au maximum) ; les autres restent à examiner. Un formulaire dont le périmètre a changé est refusé. L’arbitrage conserve l’utilisateur, la date, le choix, la justification, l’empreinte du cas source et celle de toutes les mesures examinées. Il crée des autorisations limitées à ces cas dans la famille **Choix de copies confirmés**, sans approuver la règle automatique ni attribuer une langue à `qaa`.

L’application reste en arrière-plan : contrôle du montage, identité physique, instantanés de fiches et de copies, nouvelles mesures strictement identiques à celles examinées, puis rattachement éventuel du candidat et préférence dans la même transaction SQL que la clôture du cas. Un changement bloque ce choix et laisse continuer les autres. Une reprise ne réimporte pas une copie déjà validée. Les anciennes copies et tous les fichiers restent conservés. Le planificateur préserve un choix humain autorisé en attente et la préférence manuelle appliquée.

## Conventions communes à toutes les séries

Les créations de saisons utilisent `Saison 3` dans le catalogue, même si le répertoire
du disque s’appelle `Saison 03`. Le rapprochement repose sur le rang numérique.
Le planificateur prépare aussi la famille `generated_season_titles` pour corriger
les anciens titres avec zéro initial créés par l’atelier, toutes séries confondues.
Les reçus d’application attestent la création ; une saison préexistante ou un titre
personnalisé est exclu. La validation groupée ne couvre que les propositions affichées.
Les instantanés bloquent une modification manuelle postérieure, même annulée ensuite.
Aucun nom de répertoire ni fichier n’est modifié par cette famille.
