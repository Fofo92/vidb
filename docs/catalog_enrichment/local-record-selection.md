# Choisir une fiche locale après création ou correction

Les pages d'identification externe et d'arbitrage d'association proposent un
accès à « Choisir une fiche vidb existante ». La recherche locale se relance
à chaque requête, indépendamment des résultats externes et des propositions
déjà présentes dans la file de consolidation.

Le titre français ou original est recherché après normalisation des accents,
de la casse et de la ponctuation. Tous les mots saisis doivent apparaître dans
un même titre. Les homonymes sont affichés séparément, avec leur numéro, leur
année et leur hiérarchie. La liste est limitée à 50 résultats ; un numéro ou
un lien `/records/ID` permet de choisir précisément. Les liens absolus ne sont
reconnus que pour l'hôte vidb courant et ne sont jamais téléchargés.

Un GET ne crée ni fiche, ni proposition, ni association. La sélection explicite
par POST conserve le contexte signé du montage et du compte. Elle crée une
proposition via Identification avec une correspondance délibérément non
automatique, puis utilise CandidateAssociation et son contrôle existant des
instantanés. La fiche doit être une œuvre individuelle ou un épisode qualifié
et correctement placé. Une association existante différente ne peut pas être
remplacée silencieusement.

La fiche, les métadonnées, les états d'acquisition et les copies ne sont pas
modifiés par ce choix. Le retour utilise `encoder_prepared=1`, comme les autres
confirmations, pour que video_encoder reprenne la préparation du montage.

Après une création ou une correction dans un autre onglet, « Rechercher /
Actualiser » recharge les données locales avec le même contexte. La durée de
validité du contexte signé reste celle déjà définie par CatalogueScope.


## Séries et saisons

Une fiche de série ou de saison propose « Choisir un épisode de cette série ».
La saison et l'épisode sont préremplis depuis le contexte explicite du montage
ou son nom de source ; la saison sélectionnée prend priorité, y compris la
saison 0. À défaut de numérotation, les champs proposent 1/1 et restent à vérifier.
Le contexte signé conserve le même projet, ses sources et sa destination.

Ce formulaire ouvre le parcours existant de préparation d'épisode, avec la
série choisie explicitement et sans recherche externe automatique (`enrich=0`).
Il reprend la fiche de l'épisode si elle existe ; sinon il propose sa préparation.
La consultation ne crée ni fiche ni association. La validation finale reste celle
du parcours épisode, jamais une association directe au conteneur série/saison.
