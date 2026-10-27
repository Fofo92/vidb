# Préremplissage des épisodes

Une série unique lance la consultation des sources dans la page de préparation.
Pour plusieurs séries, sélectionner la bonne fiche et demander le préremplissage.
Wikipédia est présenté en premier ; TMDB peut fournir une proposition distincte,
à partir des identifiants de série déjà confirmés dans les liens catalogue de vidb.
Aucun rapprochement mondial par seul titre d’épisode n’est effectué.

Le lecteur Wikipédia prend en charge les pages « Saison N de Série » avec sections
« Épisode N : Titre ». Les années proviennent du bloc de première diffusion de cet
épisode, pas de la date globale de saison ; la plus ancienne année observée est retenue.
Une page non reconnue ou une panne ne bloque pas la saisie manuelle. Les champs absents
restent signalés « À compléter ». Les structures de pages non prises en charge peuvent
donc nécessiter une saisie manuelle ou une future extension du lecteur.

Le formulaire propose titre, année, résumé, pays, deux genres principaux maximum et
version linguistique prévue. Chaque proposition porte sa référence et une signature
liée au compte, au projet, à la série et aux numéros locaux. Les champs laissés vides
conservent les valeurs proposées. Les champs encore inconnus peuvent rester inconnus.
Une erreur de validation conserve les valeurs saisies pour permettre leur correction.

Les valeurs locales déjà présentes sont prioritaires sur une source externe. Une
correction explicite est possible ; les valeurs signées servent de contrôle avant
remplacement. Les effacements volontaires utilisent le formulaire normal de la fiche.
Les pays et genres manquants complètent la série ; des choix différents explicites
peuvent constituer une exception sur l’épisode. Les associations explicites existantes
ne sont pas écrasées par une proposition externe non modifiée.

Pour une nouvelle proposition, un genre explicite déjà renseigné sur l’épisode
reste prioritaire. Sinon, les genres propres de la série sont proposés avant
ceux de la saison ou des sources externes ; si la série n’en a pas, les valeurs
effectives de la saison servent de repli. Le formulaire reste modifiable et
limité à deux genres. Lorsqu’une saison porte un autre genre, la confirmation
peut enregistrer le genre de la série sur l’épisode afin que ce choix soit effectif.
Les fiches qui ne sont pas préparées ne sont pas modifiées par cette règle.

Le lien « Compléter la fiche dans vidb » reste disponible depuis video_encoder même
lorsque l’épisode est déjà associé au montage. Il ne crée pas une deuxième fiche.
La réponse de présentation utilise les pays et genres effectifs (héritage compris).

Le support HD et la durée réelle ne sont pas inventés avant encodage. L’import existant
renseigne le support HD de la copie finale et sa durée mesurée, ainsi que sa version
linguistique d’après les pistes réellement produites. Un nouvel épisode reste non vu,
non enregistré et indisponible tant qu’aucune copie n’est importée.

Pas de migration ni de nouvelle configuration. Cache TMDB technique dans tmp/catalogue-episodes,
conformément au client existant ; pas de rapport ajouté dans le répertoire personnel.
