> Ticket : [essensys-hub/essensys-feature-lifecycle#52](https://github.com/essensys-hub/essensys-feature-lifecycle/issues/52). Feature ID : `noms-volets-2026-11-005`. Sub-issue de ce dépôt : [essensys-hub/essensys-ios-phone-apps#47](https://github.com/essensys-hub/essensys-ios-phone-apps/issues/47).
> Feature répartie sur plusieurs dépôts. Le change commun (contexte, décisions, **contrat d'API**) est dans `essensys-feature-lifecycle/openspec/changes/noms-volets-2026-11-005/` (`proposal.md`, `design.md`). Ce change ne décrit que le code de **essensys-ios-phone-apps**.

## Why

Les 16 volets et stores portent des noms d'origine (« Volet 1 Salon », « Store (banne) »…) qui ne correspondent pas toujours à l'usage de la maison. L'administrateur de l'armoire doit pouvoir les renommer, et l'app iPhone doit afficher partout le nom choisi. C'est le jumeau de `noms-lumieres-2026-11-004` (#41).

## What Changes

- **Modèle `ShutterName`** et lecture des noms : `GET /api/portal/shutters/names` (cloud) ou `GET /api/shutters/names` (réseau local). Si la lecture échoue, les noms d'origine restent affichés, sans message bloquant.
- **Nom affiché partout** : liste des deux groupes (« Volets », « Volet Store et Store banne »), confirmations et messages de dernière action, carte « Temps de course » (qui n'utilise plus le libellé d'origine ; `saveTravelTime` reçoit le nom affiché). Texte brut, jamais interprété. Les titres de cartes et boutons génériques ne changent pas.
- **Champ « Nom »** dans la ligne de chaque volet, réservé à l'administrateur (même règle que les lumières : `isAdmin` relu à chaque connexion, jamais persisté). 1 à 40 caractères, validés avant l'envoi ; boutons « Enregistrer » et « Nom d'origine ».
- **Écriture** : `PUT /api/portal/admin/shutters/names/{id}` (cloud) ou `PUT /api/admin/shutters/names/{id}` (local), corps `{"name":"Volet baie vitrée"}` ou `{"name":null}`. Messages clairs pour 400 (`invalid_name`, `unknown_shutter`), 403 et 503. Mode test : en-tête dry-run comme pour les autres écritures.
- **Aucun ordre vers l'armoire** : un renommage ne touche ni `inject` ni `web/actions`, et les indices (`openIndex`, `closeIndex`, `mask`, `travelTimeIndex`) ne changent pas (test `NR-ios-26`).
- **Version 2.7.0** : `MARKETING_VERSION` n'est pas modifié dans le projet ; la version est passée à l'archive (`MARKETING_VERSION=2.7.0 CURRENT_PROJECT_VERSION=1`). L'envoi TestFlight reste à la charge du propriétaire.

## Capabilities

### New Capabilities

- `shutter-names-clients` : nom affiché partout et modification par l'administrateur (spec copiée du change commun).

### Modified Capabilities

Aucune.

## Impact

- `Data/Control/ShutterNames.swift` (modèle, règle du nom, lecture, écriture), `Data/Control/ComfortRepository.swift` (utilisé).
- `UI/FeatureModels.swift` (`ShutterNamesModel`), `UI/ControlModel.swift` (`saveTravelTime`), `UI/Screens/ShutterNameDisclosure.swift`, `UI/Screens/ControlScreens.swift`, `UI/EssensysRoot.swift`.
- `Debug/UITestBackend.swift` (routes des noms de volets, `UITEST_SHUTTER_NAMES`), tests Swift Testing et `ShutterNamesUITests`.
- **Legacy IoT** : aucun endpoint `serverinfos`, `mystatus`, `myactions` ni `done` n'est modifié ; la table d'échange n'est pas touchée. Les noms de lumières (#41) ne changent pas.
- **Dépendance** : les backends (cloud et gateway) doivent exposer les routes avant la livraison de l'app ; sans elles, les noms d'origine restent affichés.
