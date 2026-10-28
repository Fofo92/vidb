# Langue originale des films et des séries pour video_encoder

Le contrôle ne déduit pas la langue du titre, du pays, de `qaa` ou d’une
qualification VF/VOST de copie. Une fiche externe compatible reste nécessaire
pour choisir automatiquement le parcours français seul.

Pour un film autonome, la recherche TMDB conserve la concordance titre + année.
Pour un épisode, vidb remonte sa propre hiérarchie épisode → saison → série.
La recherche porte sur la série, dans le catalogue TV, jamais sur le titre ni
l’année de l’épisode dans le catalogue des films.

Les identifiants TMDB déjà liés aux épisodes de la série sont utilisés en
priorité. Des identifiants contradictoires restent ambigus. Sans lien connu,
une recherche de série exige une correspondance unique de titre, et d’année
lorsque celle de la série est connue. Le détail est revérifié avant utilisation.

Le cache TMDB `tmp/catalogue-episodes` est partagé avec la préparation des
épisodes. La décision de langue est mise en cache dix minutes par série et non
par épisode. La clé change de version pour ne pas réutiliser un ancien résultat
« inconnu » issu du contrôle qui excluait toutes les séries.

La réponse reste `original_language_evidence`, avec `provider: tmdb`, le statut
`french` ou `foreign`, la langue et l’URL de la série `/tv/...`. Pour les séries,
`scope: series` précise le niveau de la référence. Le client video_encoder
existant sait déjà utiliser cette réponse.

Si l’identité, la langue ou les informations externes restent absentes,
contradictoires, multilingues ou indisponibles, le contrôle revient à la
validation manuelle. Une absence de réponse ne vaut jamais confirmation d’une
VO française. Aucun secret de configuration ne figure dans les réponses.

Exemple : pour `Joséphine, ange gardien - S10 E04 - Coupée du monde`, le contrôle
utilise la fiche de la série parente et sa date de début, pas le titre
`Coupée du monde` ni l’année de cet épisode comme identité d’un film.
