# Scans DVD à reprendre plus tard

Cette première étape ajoute un dossier de préparation par EAN, indépendant des
fiches d’œuvres et des éditions DVD confirmées. Le menu **DVD à préparer** permet
de scanner les codes successivement, de retrouver les scans et de reprendre
une préparation. Le formulaire historique de scan enregistre également le code.

Le scan est enregistré avant l’appel à UPCitemdb. Une panne de cette recherche
n’efface pas le scan. Les résultats disponibles sont conservés, y compris si une
actualisation ultérieure échoue. Ils restent des propositions commerciales,
pas une confirmation du contenu des disques.

Chaque préparation permet de conserver un titre provisoire, un nombre de contenus
annoncé et des notes. Aucun `Record`, `DvdEdition` ou `DvdContent` n’est créé par
ce parcours. Le rattachement confirmé reste accessible via le parcours DVD
existant ; il est reconnu par l’EAN, y compris s’il a été fait avant le scan.
Le filtre « À identifier » exclut les préparations ayant ce rattachement.
Cela ne signifie pas que leurs disques ont été analysés ou encodés.

L’index unique en base empêche les doublons lors de scans concurrents. Un nouveau
scan du même EAN remet sa préparation en tête de liste sans remplacer les notes.
Les consultations GET ne lancent ni recherche externe ni écriture en base.

## Installation et validation

Appliquer la migration `20261108180000_create_dvd_preparations` via le parcours
habituel de déploiement. Le schéma de la base est régénéré par Rails : le patch
ne remplace pas `db/schema.rb`, qui contient déjà des migrations indépendantes.

Pour les tests, préparer la base de test puis exécuter :

```sh
RAILS_ENV=test bin/rails db:prepare
bin/rails test test/models/dvd_preparation_test.rb test/services/dvd_preparation_lookup_test.rb test/controllers/dvd_preparations_controller_test.rb
bin/check
```

Essai métier : scanner deux coffrets, rouvrir la page, retrouver leurs deux
préparations, noter un titre provisoire, puis rescanner un code. Sa préparation
doit être unique et sa note conservée. Reprendre ensuite l’identification via
le lien du dossier. Aucun lecteur DVD n’est nécessaire pour cet essai.

La collecte de codes stockés hors connexion dans le scanner, l’inventaire des
disques physiques, la reconnaissance des épisodes et l’encodage groupé relèvent
des étapes suivantes.
