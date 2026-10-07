# Application du lot linguistique du 8 octobre 2026

Le manifeste contient exactement 61 copies : 54 VF et 7 VMST. Les 6 copies
du pilote Europe restent inchangées. Parmi les VF, 13 confirmations directes
de Pascal couvrent les 8 épisodes de L'Amie prodigieuse, La Traque d'Alex Hugo
et les 4 épisodes de Cassandre. Les 48 autres propositions proviennent du
rapport version 2 : pistes observées, indications des noms et politique de
video_encoder. Aucun autre fichier n'est sélectionné par ce manifeste.

Le service réobserve toutes les copies avant la transaction. Il vérifie leurs
propriétaires, chemins, tailles, langues audio, identité du volume, dates de
modification et ancienneté minimale de 24 heures. Il recalcule les propositions
automatiques sur les pistes fraîches. Un changement ou une qualification
préexistante incompatible arrête le lot entier. Toutes les modifications de
base sont effectuées dans une transaction. Relancer exactement le même
manifeste laisse les qualifications déjà appliquées inchangées.

La provenance est conservée dans `technical_details.language_qualification`,
avec l'auteur de la décision, sa date, la raison, les pistes vérifiées et
l'empreinte du manifeste. Les informations techniques, confirmations
antérieures, supports et durées restent conservés. Seule la version
linguistique de la copie est qualifiée ; la fiche Record n'est pas réécrite.

```sh
bin/rails runner script/apply_video_asset_languages.rb doc/catalog_enrichment/language-batch-2026-10-08.json
bin/rails runner script/apply_video_asset_languages.rb doc/catalog_enrichment/language-batch-2026-10-08.json --apply
```

## Règles à conserver pour les futurs lots

Pascal distingue les anciens encodages Kdenlive des extractions DVD HandBrake.
Pour les Kdenlive identifiés à piste audio unique : VF, sauf VO/VOST explicite
dans le nom ; VOST peut avoir des sous-titres incrustés sans piste séparée.
L'absence de JSON ne suffit pas à identifier un encodage Kdenlive.

Les dossiers suivants sont des exceptions possibles HandBrake à examiner :

- `/videos/Séries TV/_incomplet/Code Quantum (V - 93_96)`
- `/videos/Séries TV/_incomplet/CSI-NY (IX)`
- `/videos/Séries TV/_incomplet/Doctor Who`
- `/videos/Séries TV/_incomplet/Elementary (VII - 149_154)`
- `/videos/Séries TV/_incomplet/Fringe`
- `/videos/Séries TV/_complet/Bones`

Le fichier précis suivant est confirmé VMST par Pascal ; il ne fait pas partie
du lot actuel et sera qualifié lorsqu'il aura une copie rapprochée :

`/videos/Séries TV/_complet/Columbo (XVIII - c - 69)/02 - S00 E01 - Rançon pour un homme mort (Ransom for a Dead Man).mkv`

Les fichiers AVI fournis sont à examiner ultérieurement. Pour les films, les
exceptions HandBrake ne sont pas exhaustivement recensées : examiner les
pistes finales. Les projets JSON en attente ou en cours d'Enquêtes au paradis
ne permettent pas de qualifier une copie finale inexistante.
