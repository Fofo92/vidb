# Titres français et originaux des épisodes

La préparation d’un épisode conserve `french_title` et `original_title` dans deux
champs distincts et modifiables. L’aperçu du nom et la destination d’encodage utilisent
`Titre français (Titre original)` lorsque le titre original est connu.

Le lecteur Wikipédia récupère la rubrique Titre original. TMDB est aussi consulté
dans la langue originale déclarée pour la série, avec contrôle de l’identifiant
et du numéro d’épisode. L’anglais n’est pas supposé être la langue originale.
Une proposition concordante peut compléter le titre original d’une autre source,
uniquement pour la même série, saison, numéro, année compatible et titre français.
Des titres originaux contradictoires ne sont pas fusionnés automatiquement.

Un titre original déjà renseigné est conservé. Sa modification explicite vérifie
la valeur connue au chargement du formulaire pour préserver une correction
concurrente. Une panne de la recherche du titre original conserve les autres
informations et laisse le champ disponible pour une saisie manuelle.

Les titres identiques sont répétés pour une œuvre étrangère : `Boston (Boston)`.
La répétition est omise seulement lorsque les pays de production renseignés sont
exclusivement la France. Si l’origine est inconnue, les deux titres connus sont
conservés. Cette règle concerne les épisodes et les films dans video_encoder.
Une chaîne contenant déjà le suffixe original ne reçoit pas une seconde paire
de parenthèses. Sans titre français connu, le titre original est utilisé seul.

Le complément s’applique aux nouvelles propositions et destinations. Il ne
renomme pas les fichiers déjà encodés.
