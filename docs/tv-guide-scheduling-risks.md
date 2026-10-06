# Aperçu de capacité avant programmation

À l’ouverture de la grille, une requête authentifiée en lecture seule récupère
la liste Kaffeine une seule fois, puis examine les programmes non sélectionnés
visibles. Aucun appel n’est fait au survol. La grille reste utilisable pendant
le calcul, et le panneau (i) signale que la vérification est en cours.

Un petit drapeau rouge sur (i) indique un dépassement connu de quatre multiplex.
Le drapeau orange signifie que la capacité n’est pas vérifiable : chaîne sans
correspondance, multiplex inconnu, répétition ou session Kaffeine inaccessible.
Le panneau donne le message du contrôle et les captures chevauchantes. Des
horaires identiques de fin et de début ne créent pas de chevauchement.

Le calcul réutilise `MultiplexCapacityGuard`, avec les marges effectives d’une
ancienne sélection annulée, ou les marges par défaut d’une nouvelle sélection.
Il tient compte des programmations créées directement dans Kaffeine. Il ne
modifie ni les sélections ni les programmations. La colonne Mux reste la charge
des sélections vidb : ses données et cet aperçu ont donc des périmètres distincts.

Les répétitions ne sont pas développées en occurrences : une répétition ayant
déjà commencé peut rendre la prévision incertaine même si son premier créneau
est passé. Le contrôle final reste exécuté au clic ; la prévision est seulement
un instantané au chargement. Recharger le guide actualise cet instantané.

Le temps écoulé côté service (lecture Kaffeine et calcul) est renvoyé en
`elapsed_ms`, puis exposé sur la grille via `data-tv-guide-capacity-elapsed-ms`.
Pour le consulter dans la console du navigateur après le chargement :

```javascript
document.querySelector("[data-tv-guide-capacity-elapsed-ms]")?.dataset.tvGuideCapacityElapsedMs
```

Les journaux Rails donnent le temps complet de la requête POST
`/tv_guide_scheduling_risks`. La performance doit être mesurée sur le guide et
la liste Kaffeine réels. Aucune migration ni nouvelle unité système nécessaire.
