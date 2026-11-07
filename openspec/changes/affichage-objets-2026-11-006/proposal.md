> Ticket : [essensys-hub/essensys-feature-lifecycle#55](https://github.com/essensys-hub/essensys-feature-lifecycle/issues/55). Feature ID : `affichage-objets-2026-11-006`. Sub-issue de ce dépôt : [essensys-hub/essensys-ios-phone-apps#49](https://github.com/essensys-hub/essensys-ios-phone-apps/issues/49).
> Feature répartie sur plusieurs dépôts. Le change commun (contexte, décisions, **contrat d'API**) est dans `essensys-feature-lifecycle/openspec/changes/affichage-objets-2026-11-006/` (`proposal.md`, `design.md`). Ce change ne décrit que le code de **essensys-ios-phone-apps**.

## Why

Toutes les installations n'ont pas les mêmes équipements : le catalogue compte 33 lumières et 16 volets et stores, dont certains n'existent pas chez un client, mais ils apparaissent quand même partout et dans un ordre imposé. Après les noms personnalisés (`noms-lumieres-2026-11-004` #41, `noms-volets-2026-11-005` #52), l'administrateur de l'armoire doit pouvoir activer, désactiver et ordonner les objets, et l'app iPhone doit appliquer ce choix.

## What Changes

- **Modèle `ObjectLayout`** (`Data/Control/ObjectLayout.swift`) : document `{order, disabled, version, updated_at}` par genre, règle commune d'ordre effectif (identifiants de `order` d'abord, puis les identifiants connus absents dans l'ordre du catalogue, identifiants inconnus ignorés), brouillon de l'écran de gestion (`ObjectLayoutDraft` : interrupteur, Monter/Descendre dans le groupe, « Ordre d'origine »), validation avant l'envoi.
- **Lecture** : `GET /api/portal/{lights|shutters}/layout` (cloud) ou `GET /api/{lights|shutters}/layout` (réseau local). Échec ou 404 (ancien serveur) : catalogue complet dans l'ordre d'origine, sans message bloquant ; après une lecture réussie, une coupure conserve la dernière disposition lue. `ObjectLayoutModel` (un par genre : lumières et volets) dans `UI/FeatureModels.swift`.
- **Filtre et ordre appliqués une fois**, là où la liste d'un groupe est construite (`ControlScreens.swift`) : les boutons de groupe et les lignes reçoivent la même liste, donc un objet désactivé n'est jamais commandé par « Tout allumer / éteindre » ni « Tout ouvrir / fermer ». Groupe sans objet actif : texte « Aucune lumière activée » / « Aucun volet activé », boutons masqués. Écran Temporisations (`LightTimersScreen.swift`) et carte « Temps de course » (lecture des temps dans `ControlModel.swift` limitée aux volets actifs) : objets désactivés absents, ordre global. Scénarios et éditeur de scénarios : catalogue complet, inchangés.
- **Écran de gestion** (feuille, `UI/Screens/ObjectLayoutManager.swift`), réservé à l'administrateur de l'armoire (`admin_local`/`admin_global` en cloud, `lan_admin` en local) : tous les objets du genre, désactivés compris, par groupe, avec le nom affiché en texte brut, un interrupteur, Monter/Descendre, « Ordre d'origine » et un seul « Enregistrer » (`PUT /api/portal/admin/{genre}/layout` ou `PUT /api/admin/{genre}/layout`, `order` complet et `disabled`, ou `{"reset":true}`). Messages clairs pour 400, 403 et 503, l'écran reste ouvert avec les modifications. Mode test : en-tête dry-run.
- **Aucun ordre vers l'armoire** : la disposition n'est jamais écrite dans la table d'échange (`NR-ios-27` : ni `inject`, ni `web/actions`, indices, noms d'origine et noms personnalisés inchangés).
- **Version 2.8.0** : `MARKETING_VERSION` n'est pas modifié dans le projet ; la version est passée à l'archive (`MARKETING_VERSION=2.8.0 CURRENT_PROJECT_VERSION=1`). L'envoi TestFlight reste à la charge du propriétaire.

## Capabilities

### New Capabilities

- `object-layout-clients` : filtre et ordre appliqués partout, écran de gestion de l'administrateur (spec copiée du change commun).

### Modified Capabilities

Aucune.

## Impact

- `Data/Control/ObjectLayout.swift`, `Data/Control/ComfortRepository.swift` (utilisé).
- `UI/FeatureModels.swift` (`ObjectLayoutModel`), `UI/ControlModel.swift`, `UI/EssensysRoot.swift`, `UI/Screens/ControlScreens.swift`, `UI/Screens/LightTimersScreen.swift`, `UI/Screens/ObjectLayoutManager.swift`.
- `Debug/UITestBackend.swift` (routes des dispositions, `UITEST_LIGHT_LAYOUT`, `UITEST_SHUTTER_LAYOUT`, `UITEST_LAYOUT_READ`, `UITEST_LAYOUT_WRITE`), tests Swift Testing (`ObjectLayoutTests`) et `ObjectLayoutUITests`.
- **Legacy IoT** : aucun endpoint `serverinfos`, `mystatus`, `myactions` ni `done` n'est modifié ; la table d'échange n'est pas touchée. Les noms (#41, #52) et les temporisations (#45) ne changent pas.
- **Dépendance** : les backends (cloud puis gateway) doivent exposer les routes avant la livraison de l'app ; sans elles, le catalogue complet reste affiché.
