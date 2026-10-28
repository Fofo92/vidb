# Durée indicative transmise à video_encoder

L’identification d’un film ou d’un épisode ajoute
`metadata.reference_runtime_minutes`, issue de la durée catalogue existante
`Record.length_in_mn`. Si cette durée manque, l’identification ne lance pas
une nouvelle requête externe : le champ est nul et video_encoder omet le contrôle.

Lors de la confirmation d’une proposition, la durée catalogue absente peut être
complétée par la durée de la source sélectionnée : TMDB (`runtime`), Wikipédia
(durée explicite du film dans l’infobox) ou SensCritique (durée ISO du bloc Movie).
Les durées inconnues, ambiguës ou incompatibles avec les validations de la fiche
ne sont pas importées. Aucune durée existante n’est remplacée.

Une proposition Wikipédia peut reprendre la durée d’une proposition de film
concordante (titre et année identiques, durée unique). Les épisodes suivent la
concordance déjà utilisée pour leur proposition TMDB ; les correspondances
regroupant plusieurs parties conservent la durée cumulée déjà calculée.

Ce complément ne crée aucune copie, ne change aucun état et n’écrit aucune durée
mesurée dans VideoAsset. Il ne s’agit pas d’une reprise globale des anciennes
fiches. Les mesures des fichiers restent indépendantes de la durée indicative.

video_encoder utilise ce champ pour avertir avant l’écriture du projet lorsque
la somme des segments s’écarte de plus de 10 % ou trois minutes (la plus grande
tolérance est retenue). Le retour au montage reste le choix par défaut.
