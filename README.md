# vidb

`vidb` est une application Rails de gestion d’une vidéothèque.

Elle permet de gérer les enregistrements, leurs titres français et originaux,
leurs années, genres, pays, supports, versions linguistiques et statuts de
consultation.

## Développement

Prérequis principaux :

- Ruby 4.0.6 ;
- PostgreSQL ;
- Node.js ;
- Bundler 2.7.1.

Installation des dépendances :

```sh
bundle install
```

Préparation de l’application :

```sh
bin/setup
```

Démarrage du serveur de développement :

```sh
bin/rails server
```

L’application est alors accessible sur <http://localhost:3000\>.

## Contrôles qualité

```sh
bin/check
```

Cette commande vérifie Zeitwerk, RuboCop, les vulnérabilités des dépendances,
Brakeman et la suite de tests.

## Production

Apache termine TLS et transmet les requêtes à Puma, limité à l’interface
locale.

La procédure d’exploitation et de déploiement sera décrite dans
[docs/production.md](docs/production.md).

Les secrets ne sont pas stockés dans le dépôt.
