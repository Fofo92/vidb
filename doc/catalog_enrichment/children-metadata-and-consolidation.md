# Qualification des enfants et consolidation

Le bouton « Qualifier les enfants » ouvre une seule vue pour tous les enfants
directs, y compris ceux dont la nature est déjà qualifiée. Les enfants encore à
déterminer sont sélectionnés initialement ; les autres peuvent être cochés.

Les valeurs communes ne changent que les champs cochés « Appliquer ». Les
corrections par enfant prennent priorité pour ces champs. Genres, pays et
supports remplacent la liste existante ; une liste vide l’efface explicitement.
Le rang, le titre et le placement restent conservés.

L’année et son origine sont modifiables ensemble. Une modification conserve
l’ancien état dans l’historique des années et renseigne une provenance manuelle.
Une année et une origine identiques préservent la provenance existante.

La version et les supports de la fiche sont distincts de ceux des copies.
« Version des copies » et « Support des copies » modifient toutes les copies
présentes concernées ; les copies supprimées sont conservées. La qualification
linguistique précédente est archivée dans les détails techniques.

« Vu » et « Vérifié » portent sur les épisodes sous les enfants sélectionnés.
Une valeur « Non » pour « Vu » est une confirmation explicite. « Inconnu »
retire cette confirmation. Enregistré et disponible sont calculés depuis les
copies. Les états des séries et saisons restent agrégés depuis leurs épisodes.

Chaque enregistrement est vérifié à nouveau sous verrou avant l’application.
Un formulaire périmé est rejeté. Toute erreur annule l’ensemble du lot. Cette
extension ne nécessite aucune migration et ne déclenche pas de scan disque
dans la requête web.

## Liste des cas à consolider

Après rafraîchissement du suivi, en production :

```bash
bin/rails runner script/reconciliation_consolidation_cases.rb /srv/vidb/shared
```

La commande écrit `reconciliation-consolidation-cases.json` et
`reconciliation-consolidation-cases.md`. Elle ne modifie ni les fiches ni les
copies. Les motifs sont regroupés par dossier de série (les saisons sont
réunies), avec actions attendues, fiches candidates et exemples. Les ambiguïtés,
conflits de numérotation et conflits de titre figurent en premier ; les cas
d’identification et de hiérarchie suivent. Les 126 exceptions linguistiques
du lot de films sont incluses tant que leurs copies restent à qualifier.

Le bilan de réconciliation compte des fichiers : « Série à identifier » signifie
que le dossier n’a pas été associé à une fiche unique ; « Hiérarchie à compléter »
et « Saison non retrouvée » signifient que le rapprochement ne peut pas suivre
la structure attendue. Une seule consolidation de série peut résoudre de
nombreux fichiers. Les candidats ne sont pas nécessairement ambigus : ils sont
des propositions non encore importées. Les langues manquantes des copies déjà
confirmées ne diminuent pas le nombre de fichiers confirmés.

## Bilan des fiches

L’accueil distingue les fiches incomplètes, celles à consolider et leur union
(chaque fiche compte une seule fois). Les manques par champ se recoupent.
Les pays, genres et résumés sont propres à chaque fiche ; années, versions et
supports des ensembles sont évalués sur leurs vidéos. Les copies présentes
font autorité pour version et support ; sans copie, les champs de la fiche
sont utilisés. Les genres absents sont un manque, plus de deux genres une
consolidation. L’origine inconnue d’une année conservée reste à préciser.
Le bilan ne prouve pas l’identité d’une œuvre ni l’exactitude des métadonnées.

```bash
bin/rails runner script/record_metadata_audit.rb /srv/vidb/shared
```

Cette lecture seule écrit un JSON exhaustif et un Markdown listant les ID,
titres, champs manquants et motifs de consolidation. Les cas d’identité et
les exceptions des fichiers restent dans le rapport de réconciliation.
Le cache de l’accueil dure au maximum une minute. Les tableaux présentent
uniquement les valeurs, un tiret pour une valeur absente, et deux genres au
maximum ; les informations supplémentaires restent dans les vues de détail.
