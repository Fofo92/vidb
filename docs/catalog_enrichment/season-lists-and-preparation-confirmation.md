# Listes de saison et confirmation de préparation

La consultation Wikipédia essaie la page de saison et la page principale de la série. Une liste ordonnée située sous un titre « Saison N » peut fournir le titre et l’année indiquée par ce titre. Les limites de la section, la numérotation explicite et l’absence de synopsis sont respectées. Les descriptions sans titre et les listes imbriquées de parties ne servent pas à inventer une correspondance.

Cette lecture couvre notamment la saison 10 de Meurtres à Sandhamn, dont le deuxième élément est « Nikki et Evelina ». Les propositions restent soumises à confirmation ; les titres, genres et résumés déjà saisis ne sont pas réécrits automatiquement par ce correctif. Un texte anglais retourné par TMDB ne constitue pas une traduction française et doit être corrigé explicitement si nécessaire.

Les formulaires de préparation de films et d’épisodes transmettent un indicateur de fenêtre intégrée. Après validation et association réussies, la redirection vers la fiche contient `encoder_prepared=1`. Cet indicateur décrit la fin du formulaire, pas un fichier présent, et ne modifie aucun état de visionnage ou de disponibilité.

video_encoder attend cette validation avant de fermer automatiquement la fenêtre de préparation. Pour le parcours vers la file, il vérifie aussi que la réponse de la passerelle associe le même montage à la même fiche. Une simple reconnaissance automatique, un changement de métadonnées ou une réponse indisponible ne valent pas validation. La poursuite explicite sans association reste possible.

L’option ne change pas les anciens appels qui n’envoient pas l’indicateur, ni le mécanisme d’application différée des décisions dans l’atelier de réconciliation. Aucune migration n’est nécessaire. Déployer vidb puis recharger video_encoder pour bénéficier des deux volets.
