> Ticket : [essensys-hub/essensys-feature-lifecycle#41](https://github.com/essensys-hub/essensys-feature-lifecycle/issues/41). Feature ID : `noms-personnalises-2026-11-002`.
> Feature répartie sur 3 changes du même nom : apps Android et iPhone (un change dans chaque dépôt) et la plateforme (cloud, gateway, portails, installations CM5 et Raspberry Pi 4, change dans `essensys-memory`). Ce change ne décrit que le code de **essensys-ios-phone-apps**.

## Why

Les noms des objets (« Petite Chambre 3 », « Volet 1 Salon », « Salle de Bain 1 ») sont des libellés codés en dur dans la table d'indices de l'app, jumelle de celle de l'Android et des portails. Un occupant ne peut pas les adapter à sa maison : « Petite Chambre 3 » ne devient jamais « Chambre de Nico ». Les règles de nom, de droits et d'API sont décidées dans le change `noms-personnalises-2026-11-002` d'`essensys-memory` ; ce change dit ce que l'app en fait.

## What Changes

- L'app **lit les noms personnalisés** du serveur de son mode (cloud ou réseau local), les garde en cache et les rafraîchit au démarrage, au retour au premier plan et toutes les 30 s écran visible.
- Chaque libellé d'objet devient un **nom affiché** : nom forcé, sinon patron rempli avec le nom de la pièce, sinon nom d'origine.
- Écran **« Noms »** dans les Réglages, réservé aux administrateurs de l'armoire : modification, rétablissement, aperçu avant de renommer une pièce.
- Sans les noms (serveur ancien, erreur, hors ligne), l'app affiche les noms d'origine ou les derniers connus, sans erreur et sans bloquer les commandes.
- Aucune écriture hors ligne. Aucun indice ni commande modifié.
- Version 2.5.0, tag `ios-v2.5.0`.

## Capabilities

### New Capabilities

- `custom-names-app` : référentiel et rafraîchissement des noms, écran « Noms », affichage partout, secours.
- `custom-names-app-quality` : tests sans armoire, vecteurs communs, parité du catalogue, test NR, checkup.

### Modified Capabilities

Aucune (les specs existantes de ce dépôt ne sont pas archivées sous `openspec/specs/`).

## Impact

- **Code** : `Data/Control` (table d'indices : libellés remplacés par le nom affiché), nouveau référentiel de noms dans `Data/`, `Data/HTTP` (appels des noms), `UI/Screens` (Réglages, écran « Noms » et écrans qui affichent un objet), `Data/Support` (noms exclus du bundle).
- **Serveur** : routes `/api/names` du cloud et de la gateway, décrites dans le change de la plateforme. **Les apps ne sortent qu'après les backends et les portails.**
- **Compatibilité** : un serveur sans les noms répond 404 ; l'app affiche alors les noms d'origine.
- **Données** : les noms sont gardés dans les préférences de l'app, pas dans le Keychain (ce ne sont pas des secrets).
- **Dépendances** : aucune nouvelle.
