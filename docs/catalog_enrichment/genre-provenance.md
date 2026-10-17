# Provenance des genres et protection des corrections

La migration ajoute `records.genre_provenance`, JSONB non nul, initialement `{}`.
Elle ne change aucun genre, aucune qualification passée, aucun chemin ou fichier.
Le contenu vide signifie que l'historique antérieur n'est pas connu ; il ne
constitue pas une confirmation de ces genres par une source externe.

Les changements des genres par les associations du modèle enregistrent une
protection conservatrice `manual_or_untracked`. Elle couvre le formulaire
`gender_ids`, l'ajout, le retrait, le remplacement, `clear` et `delete_all` du
proxy d'association. Un effacement suivi d'un rétablissement reste protégé.
La preuve antérieure est conservée dans `history`, avec les sélections concernées.
La prise de verrou ne recharge pas la fiche : les autres champs en cours
d'édition sont préservés. Les écritures d'associations et de provenance participent
à la même transaction. Le SQL direct et les écritures sur la table de jointure
en dehors de ces associations ne passent pas par ces callbacks.

`ReviewedGenreApplication` fournit l'entrée pour une décision documentée :

- sélection attendue et provenance attendue sous verrou de la fiche ;
- un ou deux genres existants, distincts et triés ;
- justification, sources et identifiant d'opération ;
- conservation de la sélection précédente ;
- refus des nouvelles applications dès qu'une provenance existe ;
- rejeu identique sans réécriture, refus d'un identifiant réutilisé autrement ;
- annulation des associations et de la preuve si la sauvegarde échoue.

Le contexte `with_reviewed_genre_assignment` est réservé aux services d'import
qui enregistrent leur propre preuve dans la même transaction. Un appelant
ordinaire n'a pas à l'utiliser. Il ne constitue pas une autorisation utilisateur.
Une décision existante protégée nécessite une procédure de révision explicite,
qui n'est pas fournie par ce service automatique.

L'ancien enrichissement initial conserve son comportement pour les années.
Il renseigne `initial_external_enrichment` lors du remplissage des genres vides.
Une provenance déjà présente empêche ce remplissage, même si les genres ont été
effacés ; la qualification de l'année peut cependant progresser indépendamment.
La vérification des champs préservés et ses tests admettent cette nouvelle preuve.

## Vocabulaire et rangement biographiques

Le référentiel courant utilise `Biopic`. Les propositions rédigées avec le
synonyme `Biographie` sont réconciliées avec cette référence lorsqu'elle existe.
Aucun genre n'est créé. Pour conserver l'arborescence déjà utilisée, le composant
de proposition emploie `Biographie` dans le chemin et `Biopic` dans les genres.
Les deux synonymes ne peuvent pas former deux genres dans une même sélection.
La règle est explicite dans `ReviewedClassificationProposal` ; le constructeur
historique et ses autres usages restent inchangés à ce stade.

Les huit reclassements documentés n'ont pas besoin d'un nouvel arbitrage humain.
Leur application doit toutefois contrôler de nouveau les métadonnées, l'identité
du fichier et les destinations. L'exécuteur actuel impose un même répertoire :
son extension avec journalisation, absence atomique d'écrasement et coordination
avec PostgreSQL reste nécessaire avant les déplacements entre répertoires.
