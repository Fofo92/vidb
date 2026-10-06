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
présent dans `Tv::MultiplexCapacityGuard::MULTIPLEXES`.
L’Équipe est rattachée à R10, à partir du relevé local confirmé par Pascal
le 6 octobre 2026 : 642,166 MHz, TS10. Elle partage ce multiplex avec TF1
Séries Films, RMC Story, RMC Découverte et RMC Life. Les graphies « L'Equipe »,
« L’Équipe » et « L'Équipe » sont reconnues sans modifier les noms Kaffeine.
Cette table est utilisée par la colonne Mux, la prévision et le contrôle final.
BFM TV, LCI et franceinfo restent sans correspondance confirmée dans ce relevé.
