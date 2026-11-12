# État des copies et anciens marqueurs

L'état est porté par `VideoAsset.condition_details` (JSONB), indépendamment du chemin, du statut physique et des relevés `technical_details`. Un scan technique ou un renommage de la même copie ne l'efface pas.

| Ancien marqueur | Qualification |
| --- | --- |
| `(d)` | Détérioration légère, consultable sans grand désagrément |
| `(dd)` | Détérioration plus importante, copie néanmoins conservée |
| `(i)` | Copie incomplète, partie conservée non précisée |
| `(début 41')` | Début conservé, fin manquante ; 2 460 secondes conservées |
| `(fin 41')` | Fin conservée, début manquant ; 2 460 secondes conservées |

Les états par défaut sont **intégralité inconnue** et **détérioration inconnue**. Aucun marqueur ne certifie l'intégralité ou l'absence de défaut. Les noms de dossiers et les chiffres romains majuscules ne sont pas interprétés.

Les durées sont comprises entre 1 seconde et 24 heures. Les minutes portent une unité explicite (`'`, `’`, `′`, `min`, `mn`, `minutes`) ; elles peuvent être suivies de secondes, par exemple `39'31` = 2 371 secondes. La notation heures/minutes `1h09` = 4 140 secondes est également reconnue. Les minutes après `h` et les secondes doivent rester entre 0 et 59. Une durée sans unité ou des indications contradictoires sont signalées à qualifier. Elles ne sont pas importées automatiquement. Le lecteur de couverture reconnaît néanmoins le caractère incomplet annoncé par le marqueur.

## Effet sur les compteurs

- `is_recorded`, `is_available` et les nombres de copies présentes gardent leur sens physique. Une copie partielle reste présente.
- `RecordCompleteness`, relatif aux épisodes connus de vidb, exclut les copies explicitement incomplètes. Deux morceaux `début` et `fin` ne sont jamais assemblés implicitement. Une autre copie sans signalement de troncature peut couvrir l'épisode ; les parties de diffusion déclarées gardent leurs règles existantes.
- Une détérioration `(d)` ou `(dd)` ne prouve pas un manque de contenu et n'exclut donc pas à elle seule la couverture.
- La couverture historique des copies non qualifiées est conservée. Le résultat « complet » de ce filtre ne certifie ni une vérification manuelle de chaque copie ni une complétude confrontée à un catalogue externe. `integrality_verified?` exige un état explicitement `complete`.
- Aucune durée manquante n'est calculée à partir d'une durée intégrale incertaine.

## Qualification manuelle

Le formulaire garde séparément les minutes et les secondes, sans arrondi lors d’un enregistrement.

Le tableau des copies affiche l'intégralité, la détérioration, la partie et la durée conservées. « Qualifier la copie » ouvre un formulaire authentifié, limité à une copie de la fiche. Le formulaire protège contre les modifications concurrentes et conserve la provenance des anciens marqueurs, les qualifications successives et l'utilisateur.

Une qualification existante ne sera jamais écrasée par un marqueur du nom. Les nouvelles copies sont qualifiées à leur création lorsqu'un marqueur est présent. Les références qualifiées sont protégées contre le nettoyage automatique des références redondantes ; leur retrait reste possible par les procédures manuelles existantes.

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
