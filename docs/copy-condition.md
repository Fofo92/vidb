# État des copies et anciens marqueurs

L'état est porté par `VideoAsset.condition_details` (JSONB), indépendamment du chemin, du statut physique et des relevés `technical_details`. Un scan technique ou un renommage de la même copie ne l'efface pas.

| Ancien marqueur | Qualification |
| --- | --- |
| `(d)` | Détérioration légère, consultable sans grand désagrément |
| `(dd)` | Détérioration plus importante, copie néanmoins conservée |
| `(i)` | Copie incomplète, partie conservée non précisée |
| `(début)` | Début conservé, fin manquante ; durée non renseignée |
| `(fin)` | Fin conservée, début manquant ; durée non renseignée |
| `(début 41')` | Début conservé, fin manquante ; 2 460 secondes conservées |
| `(fin 41')` | Fin conservée, début manquant ; 2 460 secondes conservées |

Sans signalement explicite, une copie est **présumée complète et sans détérioration signalée**. Cette convention n’est pas une vérification du fichier : `presumed_fields` distingue les champs présumés des qualifications explicites. Une incertitude manuelle reste conservée. Les noms de dossiers et les chiffres romains majuscules ne sont pas interprétés.

Les durées sont comprises entre 1 seconde et 24 heures. Les minutes portent une unité explicite (`'`, `’`, `′`, `min`, `mn`, `minutes`) ; elles peuvent être suivies de secondes, par exemple `39'31` = 2 371 secondes. La notation heures/minutes `1h09` = 4 140 secondes est également reconnue. Les minutes après `h` et les secondes doivent rester entre 0 et 59. Une durée sans unité ou des indications contradictoires sont signalées à qualifier. Elles ne sont pas importées automatiquement. Le lecteur de couverture reconnaît néanmoins le caractère incomplet annoncé par le marqueur.

## Effet sur les compteurs

- `is_recorded`, `is_available` et les nombres de copies présentes gardent leur sens physique. Une copie partielle reste présente.
- `RecordCompleteness`, relatif aux épisodes connus de vidb, exclut les copies explicitement incomplètes. Deux morceaux `début` et `fin` ne sont jamais assemblés implicitement. Une autre copie sans signalement de troncature peut couvrir l'épisode ; les parties de diffusion déclarées gardent leurs règles existantes.
- Une détérioration `(d)` ou `(dd)` ne prouve pas un manque de contenu et n'exclut donc pas à elle seule la couverture.
- La couverture historique des copies non qualifiées est conservée. Le résultat « complet » de ce filtre ne certifie ni une vérification manuelle de chaque copie ni une complétude confrontée à un catalogue externe. `integrality_verified?` exige un état explicitement `complete`, sans présomption sur ce champ.
- Aucune durée manquante n'est calculée à partir d'une durée intégrale incertaine.

## Qualification manuelle

Le formulaire garde séparément les minutes et les secondes, sans arrondi lors d’un enregistrement.

Le tableau des copies affiche l'intégralité, la détérioration, la partie et la durée conservées. « Qualifier la copie » ouvre un formulaire authentifié, limité à une copie de la fiche. Le formulaire protège contre les modifications concurrentes et conserve la provenance des anciens marqueurs, les qualifications successives et l'utilisateur.

Une qualification explicite existante ne sera jamais écrasée par un marqueur du nom. Les nouvelles copies reçoivent la convention à leur création, en conservant les défauts reconnus. Les références explicitement qualifiées sont protégées contre le nettoyage automatique des références redondantes ; une pure présomption par défaut ne bloque pas ce mécanisme existant.

## Import des anciennes copies

La migration ajoute uniquement une colonne vide ; elle ne parcourt pas les fichiers et ne qualifie pas rétroactivement les copies. Les marqueurs existants sont immédiatement visibles en lecture, sans écriture automatique à l'affichage.

Après déploiement, lancer sous l'environnement de production habituel :

```bash
bundle _2.7.1_ exec ruby bin/rails runner script/import_legacy_copy_conditions.rb
```

Le rapport distingue `proposed`, `preserved` et `needs_review`. Il concerne les références de films et d'épisodes, y compris l'historique absent ou supprimé. Pour enregistrer les seules propositions non ambiguës après revue :

```bash
VIDB_APPLY_COPY_CONDITIONS=YES bundle _2.7.1_ exec ruby bin/rails runner script/import_legacy_copy_conditions.rb
```

L'import est idempotent, verrouille la fiche puis la copie et revalide le nom. Chaque copie est enregistrée séparément : une interruption laisse les précédentes importées et permet une relance. Il ne touche pas au chemin, au fichier, à la langue, à la durée technique, aux états de visionnage ni à la durée déclarée sur l'œuvre.

Les anciens marqueurs ne sont pas retirés des noms par ce patch. Leur retrait appartiendra au plan de renommage, après contrôle de leur conservation en base. Les plans de renommage établis avant les qualifications doivent être régénérés, car l'empreinte des copies change.

## Requalification des copies existantes selon la convention

Après déploiement du correctif, produire un nouveau plan en lecture seule :

```bash
cd ~/code/Fofo92/vidb &&
vidb_condition_plan="/tmp/vidb-convention-copies-$(date +%Y%m%d-%H%M%S).json" &&
bash bin/qualify-copy-conditions > "$vidb_condition_plan" &&
python3 - "$vidb_condition_plan" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as source:
    report = json.load(source)
print(json.dumps({key: report[key] for key in ("format", "mode", "counts", "plan_digest", "needs_review")},
                 ensure_ascii=False, indent=2))
print("Plan complet :", sys.argv[1])
PY
```

Les données explicitement qualifiées sont préservées. Seuls les champs manquants
d’une copie sans état ou d’une ancienne interprétation automatique sont complétés.
Les marqueurs ambigus ou non reconnus et les défauts indiqués sur la fiche sont
laissés à examiner. Les fiches sans copie indexée, dont les deux Star Wars de
l’audit, ne sont pas modifiées.

Après examen du plan, appliquer exactement ce fichier, dans le même terminal :

```bash
cd ~/code/Fofo92/vidb &&
bash bin/qualify-copy-conditions --apply - < "$vidb_condition_plan"
```

L’application verrouille la fiche puis sa copie et vérifie les conditions ainsi
que le chemin. Un changement concurrent ou un plan altéré annule toute la
transaction : aucun lot partiellement requalifié n’est conservé. Une réapplication
du même plan est idempotente. Les seules colonnes écrites sont `condition_details`
et `updated_at` de la copie ; aucun état physique, de visionnage ou de fiche n’est
recalculé. Aucun fichier vidéo n’est ouvert, déplacé ou supprimé. Aucun ancien lot
de rapprochement ou de renommage n’est lancé.
