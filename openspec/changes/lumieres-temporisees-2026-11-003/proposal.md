> Ticket : [essensys-hub/essensys-feature-lifecycle#45](https://github.com/essensys-hub/essensys-feature-lifecycle/issues/45). Feature ID : `lumieres-temporisees-2026-11-003`. Sub-issue de ce dépôt : [essensys-hub/essensys-ios-phone-apps#43](https://github.com/essensys-hub/essensys-ios-phone-apps/issues/43).
> Feature répartie sur plusieurs dépôts. Le change commun (contexte, décisions, **contrat d'API**) est dans `essensys-feature-lifecycle/openspec/changes/lumieres-temporisees-2026-11-003/` (`proposal.md`, `design.md`). Ce change ne décrit que le code de **essensys-ios-phone-apps**.

## Why

Le délai d'extinction automatique de six lumières ne se règle que sur l'écran tactile de l'armoire. L'app iPhone doit permettre à l'administrateur de l'armoire de le régler à distance (cloud) ou en réseau local.

## What Changes

- Écran **« Temporisations »** (tuile d'accueil, `Feature.lightTimers`) : les six lumières (Dressing, WC 1, WC 2, Service, Annexe 1, Annexe 2) avec leur délai courant, raccourcis 15 min, 30 min, 1 h, Jamais et valeur libre de 1 à 255 minutes.
- Le **même réglage** dans la ligne de chacune des six lumières de l'écran Éclairage (ligne repliable), partagé avec l'écran « Temporisations » (même modèle, même valeur).
- **Rôle administrateur** (neuf dans l'app) : décodé à la connexion cloud (`user.role`) et LAN (`user.role`), relu à chaque session (`/api/portal/session`, `/api/user/me`), conservé dans `SessionState.isAdmin` **sans être persisté** dans le trousseau. Administrateur : `admin_local` ou `admin_global` en cloud, `lan_admin` en LAN. Une session restaurée n'est pas administrateur avant la première relecture. Le masquage n'est pas une protection : le serveur reste l'autorité (403).
- Appels : `GET /api/portal/lights/timers` (cloud) ou `/api/admin/lights/timers` (LAN) ; `PUT /api/portal/admin/lights/timers/{id}` (cloud) ou `/api/admin/lights/timers/{id}` (LAN), corps `{"minutes":n}`. Mode test : en-tête dry-run comme pour les autres écritures.
- Relecture à 5, 10 puis 20 s après un envoi ; contrôles désactivés hors ligne.
- La version (`MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`) et l'envoi TestFlight (tâche 7.4) sont traités à part, avec le propriétaire.

## Capabilities

### New Capabilities

- `light-timers-clients` : menu central et réglage par lumière (spec copiée du change commun).

### Modified Capabilities

Aucune.

## Impact

- `Data/Control/LightTimers.swift` (catalogue, format, lecture, écriture), `Data/Control/ComfortRepository.swift`.
- `Data/HTTP/DTO.swift`, `Data/Auth/AuthRepository.swift`, `Data/Session/SessionStore.swift`, `Data/Session/PortalRepository.swift`, `Data/AppContainer.swift` (rôle).
- `UI/FeatureModels.swift` (`LightTimersModel`), `UI/Screens/LightTimersScreen.swift`, `UI/Screens/ControlScreens.swift`, `UI/Screens/MainScreens.swift`, `UI/EssensysRoot.swift`.
- `Debug/UITestBackend.swift` (rôle simulé `UITEST_ROLE`, routes des temporisations), tests Swift Testing et `LightTimersUITests`.
- **Legacy IoT** : aucun endpoint `serverinfos`, `mystatus`, `myactions` ni `done` n'est modifié.
- **Dépendance** : les backends (cloud et gateway) doivent exposer les routes avant la livraison de l'app ; sans elles, l'écran affiche « Inconnue » et le réglage échoue proprement.
