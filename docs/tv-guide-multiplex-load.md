# Charge des multiplex dans le guide

La colonne « Mux », à gauche des horaires, compte les multiplex des intentions
vidb sélectionnées pour la source affichée, avec les marges effectives de
capture. Elle inclut les chaînes masquées par les favoris et les observations
anciennes qui restent sélectionnées après un nouvel import. Elle ne consulte
pas Kaffeine : une programmation créée uniquement dans Kaffeine n’est pas
comptée. Le contrôle de capacité lors d’une programmation continue à consulter
Kaffeine et reste la vérification finale.

Plusieurs captures sur un même multiplex comptent pour un seul multiplex.
Chaque plage commence ou finit à une limite de capture, y compris les marges.
Les limites sont exclusives à droite : une capture terminée à 19 h et une autre
commençant à 19 h ne se chevauchent pas. Les changements d’heure et les captures
traversant minuit sont pris en compte ; les positions suivent la même projection
que les programmes, même lorsqu’une émission courte agrandit la grille.

Couleurs : 1 vert, 2 bleu, 3 orange, 4 rouge, plus de 4 noir opaque.
Les plages sans sélection restent blanches. Le chiffre donne le nombre exact
connu, y compris au-delà de quatre. Une chaîne non renseignée ajoute « +? »
(ou « ? » seul) et des hachures : le chiffre devient alors une borne inférieure.
Le détail est accessible au survol et au clic, avec les horaires, multiplex,
chaînes et programmes. Échap, le bouton de fermeture ou un clic extérieur
ferment le panneau. Aucun programme n’est modifié par cette vue.

La correspondance utilise le relevé Kaffeine de Zeus (septembre 2026) déjà
présent dans `Tv::MultiplexCapacityGuard::MULTIPLEXES`. BFM TV, LCI, franceinfo
et L’Équipe ne figurent pas dans ce relevé ; leurs multiplex ne sont pas déduits
sans preuve locale.
