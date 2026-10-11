# Rangement Hercule Poirot

Cible générale : `Série française (titre original)/Saison XX/SXX EYY - Titre français (titre original).mkv`.

Ce premier lot range les 70 fichiers existants en 13 saisons. Il conserve les titres et les extensions `.m4v` : un changement d’extension ne convertit pas un conteneur. Les titres absents, le nom du dossier racine et une éventuelle conversion en MKV seront traités séparément après rapprochement avec des sources externes. Le numéro global de 01 à 70 est retiré ; les numéros SXX EYY restent inchangés.

Depuis la racine du dépôt, sous le compte propriétaire des fichiers :

```sh
python3 script/relocate_video_files.py data/catalog_enrichment/poirot-file-relocation.json
python3 script/relocate_video_files.py data/catalog_enrichment/poirot-file-relocation.json --apply
```

La première commande ne modifie rien. Le plan vérifie les tailles du relevé précédent, les destinations, les chemins et l’ancienneté des fichiers (24 heures). Des sous-titres externes de même nom suivent leur vidéo. La présence d’un projet JSON bloque le rangement : ses chemins internes nécessitent une analyse distincte.

Le déplacement utilise une création de lien physique sans écrasement puis retire l’ancien chemin ; les contenus et dates sont conservés. Le journal `poirot-relocation-journal.json` reste dans le dossier racine. Une erreur déclenche une restauration des opérations déjà effectuées ; toute restauration incomplète est signalée dans le journal. Une interruption brutale nécessite de consulter ce journal avant de reprendre.

Aucune fiche ni copie confirmée n’est modifiée dans la base. Un nouvel inventaire disque est nécessaire après le rangement avant de poursuivre les rapprochements. Ne pas déplacer le dossier racine avec ce lot.
