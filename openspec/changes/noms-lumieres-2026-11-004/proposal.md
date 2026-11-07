> Ticket : [essensys-hub/essensys-feature-lifecycle#41](https://github.com/essensys-hub/essensys-feature-lifecycle/issues/41). Feature ID : `noms-lumieres-2026-11-004`. Sub-issue de ce dépôt : [essensys-hub/essensys-ios-phone-apps#45](https://github.com/essensys-hub/essensys-ios-phone-apps/issues/45).
> Feature répartie sur plusieurs dépôts. Le change commun (contexte, décisions, **contrat d'API**) est dans `essensys-feature-lifecycle/openspec/changes/noms-lumieres-2026-11-004/` (`proposal.md`, `design.md`). Ce change ne décrit que le code de **essensys-ios-phone-apps**.

## Why

Les 33 lumières portent des noms d'origine (« Dressing », « WC 1 »…) qui ne correspondent pas toujours à l'usage de la maison. L'administrateur de l'armoire doit pouvoir les renommer, et l'app iPhone doit afficher partout le nom choisi.

## What Changes

- **Modèle `LightName`** et lecture des noms : `GET /api/portal/lights/names` (cloud) ou `GET /api/lights/names` (réseau local). Si la lecture échoue, les noms d'origine restent affichés, sans message bloquant.
- **Nom affiché partout** : listes d'éclairage (principal et indirect), fiche, écran « Temporisations » (qui n'utilise plus le libellé d'origine), éditeur de scénarios (les bits qui désignent une lumière), confirmations et messages de dernière action. Texte brut, jamais interprété.
- **Champ « Nom »** dans la ligne de chaque lumière, réservé à l'administrateur (même règle que les temporisations : `isAdmin` relu à chaque connexion, jamais persisté ; le mode local sans IAM ne donne pas le droit). 1 à 40 caractères, validés avant l'envoi ; boutons « Enregistrer » et « Nom d'origine ».
- **Écriture** : `PUT /api/portal/admin/lights/names/{id}` (cloud) ou `PUT /api/admin/lights/names/{id}` (local), corps `{"name":"WC 3"}` ou `{"name":null}`. Messages clairs pour 400, 403 et 503. Mode test : en-tête dry-run comme pour les autres écritures.
- **Aucun ordre vers l'armoire** : un renommage ne touche ni `inject` ni `web/actions` (test `NR-ios-25`).
- **Version 2.6.0** : `MARKETING_VERSION` n'est pas modifié dans le projet ; la version est passée à l'archive (`MARKETING_VERSION=2.6.0 CURRENT_PROJECT_VERSION=1`). L'envoi TestFlight reste à la charge du propriétaire.

## Capabilities

### New Capabilities

- `light-names-clients` : nom affiché partout et modification par l'administrateur (spec copiée du change commun).

### Modified Capabilities

Aucune.

## Impact

- `Data/Control/LightNames.swift` (modèle, règle du nom, lecture, écriture), `Data/Control/ComfortRepository.swift` (utilisé).
- `UI/FeatureModels.swift` (`LightNamesModel`, `LightTimersModel`), `UI/Screens/LightTimersScreen.swift` (`LightNameDisclosure`), `UI/Screens/ControlScreens.swift`, `UI/Screens/FeatureScreens.swift`, `UI/EssensysRoot.swift`.
- `Debug/UITestBackend.swift` (routes des noms, `UITEST_LIGHT_NAMES`, `UITEST_NAMES_READ_FAIL`, `UITEST_NAMES_WRITE`), tests Swift Testing et `LightNamesUITests`.
- **Legacy IoT** : aucun endpoint `serverinfos`, `mystatus`, `myactions` ni `done` n'est modifié ; la table d'échange n'est pas touchée.
- **Dépendance** : les backends (cloud et gateway) doivent exposer les routes avant la livraison de l'app ; sans elles, les noms d'origine restent affichés.
