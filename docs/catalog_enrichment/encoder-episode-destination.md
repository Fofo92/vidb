# Association et destination d’un épisode

La confirmation de la série et de l’épisode crée une association signée pour le montage,
au moyen des règles de revue habituelles. Les décisions différées ne sont pas écrasées.
La transaction annule les créations si l’association ne peut pas être confirmée.
La réponse d’identification inclut les titres de série et les rangs saison/épisode
permettant à video_encoder de proposer un dossier et un nom canoniques.
Aucune copie physique n’est créée avant la réception de l’export terminé.
Un épisode préparé avant ce complément peut être confirmé à nouveau dans le formulaire :
les fiches sont réutilisées et l’association est alors établie.
