# Préparer un montage depuis une fiche vidb

Ce premier lot vise l’utilisation sur Zeus : dans la fiche d’un film autonome
ou d’un épisode dont la nature et le placement sont cohérents, « Préparer un
montage » donne accès au lanceur local video_encoder. La présomption de bon état
ou de complétude n’intervient pas dans cette condition de placement.

Le navigateur ouvre un lien `vidb-encoder://prepare`. Le lanceur enregistré sur
le poste reçoit une demande signée, liée à une fiche, à un compte et à une instance
vidb. Le secret de la passerelle n’est jamais présent dans ce lien. Le navigateur
peut demander une autorisation d’ouverture de l’application externe.

L’éditeur demande le fichier source et conserve le choix de fiche dans le montage.
L’association effective passe ensuite par la passerelle existante au moment de
l’identification ou de l’enregistrement, sans recherche automatique par titre.
Aucune copie disponible n’est créée avant l’import habituel du résultat terminé.
La qualification de l’état du montage et le choix des pistes conservent leurs
étapes actuelles. Aucune nouvelle file de travaux d’encodage n’est introduite.

Le choix de fiche reste enregistré dans le projet tant que l’association n’a
pas abouti, même si le montage est repris plus tard. Il disparaît ensuite du
JSON au profit de la liaison signée habituelle. La demande signée n’est pas un
identifiant de connexion : la passerelle doit toujours s’authentifier et la
nature et le placement de la fiche sont revalidés. Une demande refusée n’est
jamais remplacée silencieusement par une identification par titre.

## Installation

Après application et validation des patches dans les deux dépôts, enregistrer
le lanceur pour le compte graphique de Pascal sur Zeus :

```bash
cd ~/code/Fofo92/video_encoder &&
python3 bin/install-vidb-launcher
```

Cette commande utilise `xdg-mime` et un fichier `.desktop` dans les applications
de l’utilisateur. Elle ne demande pas sudo et ne lance pas l’éditeur. Elle réutilise
la configuration de passerelle actuelle (`~/.config/video_encoder/vidb.json`).
`--dry-run` montre le fichier `.desktop` sans l’enregistrer.

Déployer ensuite le commit vidb selon la procédure habituelle, puis fermer
l’ancienne version de l’interface video_encoder après la fin des encodages et
la relancer. Une ancienne interface sans point d’entrée local est détectée ;
une seconde instance n’est pas ouverte à sa place.

Si la passerelle n’est pas configurée, utiliser son installateur existant :

```bash
cd ~/code/Fofo92/vidb &&
bash bin/install-encoder-project-bridge https://zeus.fodiman.fr
```

Ne pas relancer cet installateur si la passerelle actuelle fonctionne déjà.
Le compte connecté dans vidb doit correspondre à l’opérateur configuré pour elle.

## Vérification manuelle après déploiement

1. Depuis Zeus, ouvrir une fiche de film ou d’épisode, puis « Préparer un montage ».
2. Choisir « Ouvrir video_encoder » et une source vidéo existante.
3. Réaliser le montage puis demander son identification : la fiche choisie doit
   être conservée, même si le nom du fichier source désigne une autre œuvre.
4. Vérifier aussi l’annulation du choix de source et le refus de fermer un
   montage déjà ouvert : aucune association ni mise en file ne doit en résulter.
5. Cliquer à nouveau sur le même lien pendant que ce montage est ouvert :
   sa fenêtre doit revenir au premier plan sans remplacer sa source.

## Périmètre

Le lien ouvre l’éditeur sur le poste où se trouve le navigateur, pas sur un
ordinateur distant. Le pilotage distant de Zeus et un éditeur web sont hors de
ce lot. Les sources DVD restent accessibles par leur parcours actuel. Les fichiers
vidéo, leurs supports, leurs états de visionnage et la convention de complétude
ne sont pas modifiés par l’ouverture de l’éditeur.
