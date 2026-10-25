# Préparation d’un épisode d’une série absente de vidb

Le formulaire cherche d’abord une série locale qualifiée. En son absence, il
recherche les séries candidates dans TMDB, puis consulte Wikipédia et TMDB pour
l’épisode demandé. Plusieurs identités restent présentées séparément ; aucune
série ni aucun épisode n’est créé à la consultation. Le bouton de recherche
extérieure permet aussi de demander ces propositions lorsqu’une autre série
locale correspond partiellement au texte recherché.

Chaque proposition indique l’identité de la série, son année et une estimation
du nombre de saisons et d’épisodes. **Créer la série complète et préparer cet
épisode** confirme la série et la création de son catalogue documenté. Le catalogue
complet TMDB est actualisé et lu avant toute transaction d’écriture. Wikipédia
reste prioritaire pour la proposition de l’épisode demandé lorsqu’elle est disponible.

La confirmation crée les saisons, y compris les hors-série documentés en Saison 00,
et tous les épisodes fournis par la source. Les titres français et originaux sont
séparés. Les dates déjà diffusées qualifient l’année de première diffusion ; les
durées catalogue restent des références dans les liens externes, sans devenir des
durées mesurées. Pays et genres communs sont portés par la série et hérités par
les épisodes. La version linguistique reste IND tant qu’une copie ne la qualifie pas.

Les nouveaux épisodes sont **non enregistrés, non disponibles et non visionnés
par défaut**, sans copie, sans support ni durée réelle inventés. La création du
catalogue n’importe aucun fichier vidéo. L’épisode demandé seul est associé au
projet video_encoder ; la copie réelle est importée après l’encodage réussi.

Une série homonyme non qualifiée est signalée et ne devient pas automatiquement
une série. Un autre type de fiche, des rangs ambigus ou une identité externe
contradictoire bloquent l’écriture. Une série qualifiée correspondant déjà à
l’identité est réutilisée. Des liens catalogue concordants protègent les corrections
manuelles des titres. Les états et résumés manuels existants ne sont pas réinitialisés.

L’écriture, les liens catalogue et l’association du projet sont atomiques : un
échec annule les ajouts de cette confirmation. Rejouer une confirmation concordante
réutilise les fiches et les liens. La mise en place ne nécessite pas de migration.

Ce complément vient après le lot des titres originaux. Il concerne vidb uniquement ;
le parcours de fenêtre modale et de mise en file de video_encoder utilise ensuite
l’association confirmée via la passerelle existante.
