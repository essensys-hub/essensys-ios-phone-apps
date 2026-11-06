## Purpose

Garantir que les noms personnalisés s'affichent comme sur les autres clients, qu'ils respectent les droits, et qu'ils ne touchent jamais l'armoire, sans armoire réelle.

## ADDED Requirements

### Requirement: Tests sans armoire
Les tests des noms SHALL s'exécuter sans armoire réelle : serveurs simulés et horloge contrôlée. Aucun test ne MUST envoyer de commande à une armoire.

#### Scenario: Suite des tests
- **WHEN** les tests des noms s'exécutent avec `NO_ARMOIRE=1`
- **THEN** aucune commande n'atteint une armoire réelle et tous les tests passent

### Requirement: Mêmes résultats que les autres clients
L'app SHALL jouer les vecteurs de test communs `names_vectors.json` (résolution du nom affiché, validation d'un nom) avec Swift Testing, et tous les cas MUST passer. Le catalogue de l'app SHALL être identique à celui des autres dépôts : mêmes types, clés, pièces, patrons et noms d'origine. Le test de parité MUST échouer dès que le catalogue diverge.

#### Scenario: Vecteurs
- **WHEN** les tests unitaires jouent `names_vectors.json`
- **THEN** chaque cas de résolution et de validation donne le résultat attendu

#### Scenario: Catalogue divergent
- **WHEN** une clé du catalogue de l'app est modifiée
- **THEN** le test de parité échoue

### Requirement: Non-régression
Les tests `NR-ios-24`, `NR-ios-25` et `NR-ios-26` SHALL vérifier respectivement qu'un utilisateur sans droit n'a pas l'écran « Noms » et que le serveur refuse son écriture, que les noms d'origine s'affichent quand l'API des noms est absente, et que renommer ne change aucun indice ni masque de la table d'indices.

#### Scenario: NR-ios-24
- **WHEN** un utilisateur sans droit de renommer ouvre les Réglages, puis envoie une écriture à un serveur simulé
- **THEN** l'écran « Noms » est absent et le serveur simulé refuse l'écriture

#### Scenario: NR-ios-25
- **WHEN** l'app interroge un serveur simulé qui répond 404 aux noms
- **THEN** tous les objets s'affichent avec leur nom d'origine

#### Scenario: NR-ios-26
- **WHEN** un test renomme chaque objet du catalogue
- **THEN** les indices et masques de la table d'indices sont identiques à ceux d'avant

### Requirement: Tests d'application
Les scénarios principaux (écran « Noms », renommer une pièce, forcer puis rétablir un objet, utilisateur ordinaire, serveur sans les noms) SHALL être couverts par des tests UI sur simulateur, en mode Cloud et en mode Réseau local.

#### Scenario: Les deux modes
- **WHEN** la suite de tests UI s'exécute sur le simulateur
- **THEN** chaque scénario de noms passe en mode Cloud et en mode Réseau local
