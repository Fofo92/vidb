# Compléments automatiques du catalogue existant

Les mêmes règles s’appliquent aux copies anciennes, aux imports et aux nouvelles
sorties de video_encoder. Aucun réencodage ni déplacement de vidéo n’est requis.

## Pochettes

Le passage existant `vidb-posters-refresh` conserve les pochettes manuelles et
les identités TMDB déjà enregistrées. Pour une série sans identité, il recherche
des candidats puis exige une seule correspondance corroborée :

- titre de série concordant et recherche TMDB complète ;
- au moins deux épisodes locaux avec des titres informatifs ;
- titres français et originaux lorsqu’ils existent, années et numéros concordants
  pour tous les épisodes connus, dans toutes les saisons locales ;
- aucun conflit de référence, rang répété ou branche non qualifiée.

Une identification reste en attente si ces preuves manquent. Le traitement ne
crée pas de fiches, de liens d’épisodes ou de métadonnées éditoriales. L’identité
retenue est conservée dans la provenance de la pochette. Les saisons et épisodes
peuvent utiliser cette image par le mécanisme d’affichage déjà présent.

Les recherches de séries et les réponses de pochette expirent après six heures :
une absence de pochette n’est donc pas mémorisée indéfiniment. Une erreur est
journalisée par fiche et peut être retentée lors d’un passage ultérieur. Une
modification du catalogue pendant les requêtes bloque l’enregistrement de
l’identification devenue obsolète.

## Langues des copies

Après un scan valide et l’import des exports, le rapprochement existant traite
au maximum 50 copies présentes dont la version reste vide. Une moitié du budget
peut servir les imports des dernières 24 heures ; le reste avance dans les
anciennes copies avec un curseur persistant, y compris après un cas à arbitrer.

La qualification existante relit les pistes et vérifie le fichier et le volume
avant toute écriture. Elle conserve les versions déjà renseignées. La politique
du catalogue présume VF pour une piste unique sans indication VO/VOST ni
contradiction ; les cas non résolus restent en attente. La qualification est
tracée dans `technical_details`, sans modifier les pistes vidéo ou audio.

Le bilan du dernier lot se trouve dans `automatic-languages.json`, à côté du
suivi de rapprochement. Les erreurs sont aussi journalisées. Le curseur fait
partie du répertoire partagé et survit aux déploiements.

## Exploitation

Les timers existants restent les points d’entrée : pochettes toutes les trente
minutes, rapprochement toutes les quinze minutes. Le correctif ne crée pas de
nouveau service. Vérifier leur activation avec :

```bash
systemctl list-timers vidb-posters-refresh.timer vidb-reconciliation-refresh.timer
```

Les scripts `bin/install-posters-refresh` et `bin/install-reconciliation-refresh`
permettent d’installer ces unités si nécessaire. Un passage peut être déclenché
sans cibler une série particulière :

```bash
sudo systemctl start --no-block vidb-posters-refresh.service
sudo systemctl start --no-block vidb-reconciliation-refresh.service
```
