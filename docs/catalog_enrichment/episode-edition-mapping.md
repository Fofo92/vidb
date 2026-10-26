# Épisodes entiers et parties du catalogue

La numérotation locale reste distincte de celle du catalogue externe. Une liste
ordonnée sous un titre de saison Wikipédia peut définir la convention locale.
La préparation affiche la correspondance lorsque TMDB divise une histoire en
plusieurs parties ; la confirmation valide cette convention.

Exemple : pour Sandhamn, saison 10, les épisodes locaux Madeleine, Nikki et
Evelina et Birgitta correspondent respectivement aux épisodes TMDB 1 + 2,
3 + 4 et 5 + 6. Aucun calcul systématique sur les numéros n'est utilisé.

Le rapprochement exige des titres compatibles, des marqueurs de parties
explicites et consécutifs et une couverture complète sans doublon. Un cas
incomplet ou ambigu est refusé. Une partie isolée courte dans une édition
découpée ne suffit pas à établir une histoire entière. Les durées ne prouvent
jamais à elles seules une correspondance.

La première partie sert d'ancrage dans CatalogueEpisodeLink. Son champ evidence
conserve toutes les parties (identifiants, numéros, titres et durées de référence),
la source de numérotation et le titre local. Les autres parties ne peuvent pas
être attribuées simultanément à une autre fiche par cette complétion. La convention
enregistrée permet de retrouver un épisode connu même si Wikipédia est indisponible.
Un nouveau rang sans correspondance établie exige une nouvelle consultation.

Avant la création complète, la liste est relue et la correspondance de l'épisode
choisi est comparée à la proposition confirmée. Les conflits annulent la
transaction entière. Les erreurs indiquent saison et épisode, sans présenter
comme existant l'identifiant d'une fiche annulée.

Les fichiers et leurs noms ne changent pas. Les durées additionnées restent
des références catalogue ; elles ne renseignent pas la durée réelle. Les états,
titres et résumés manuels existants sont préservés. Les épisodes créés sans
fichier sont non enregistrés, non disponibles et non visionnés, avec une version
linguistique indéterminée et sans support ni durée mesurés.

Cette première prise en charge concerne les listes de saison reconnues et les
parties explicitement nommées. Elle ne résout pas automatiquement les éditions
dont les titres, saisons ou frontières diffèrent sans preuve suffisante.
