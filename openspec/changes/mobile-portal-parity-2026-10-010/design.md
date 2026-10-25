## Context

Motivation : voir `proposal.md`. Besoins : les 6 specs du change, identiques à celles du jumeau Android.

Ce design reprend les décisions du change jumeau `essensys-android-phone-apps/openspec/changes/mobile-portal-parity-2026-10-010/design.md` (contrats des backends, indices du firmware, transposition des scénarios, risques). On ne note ici que leur traduction iOS.

**État de départ** (2026-10-25) : app v2.0.0 (`ios-portal-refresh-2026-10-003`), Swift 6 en concurrence stricte, SwiftUI, iOS 18 minimum, `APIClient` async/await, `IndexTable`, `ControlRepository` cloud et LAN, `PortalRepository`, `NoArmoireGuard`, `UITestBackend` (DEBUG) et `MockBackend` (`URLProtocol`). Navigation par `TabView` à 4 onglets dans `EssensysRoot`.

## Goals / Non-Goals

**Goals :**
- Mêmes couples envoyés et mêmes tests NR que l'Android, aux mêmes numéros.
- Aucune nouvelle dépendance (pas de Swift Package ajouté).

**Non-Goals :**
- Les décisions propres à Android (Compose, `MockWebServer`, signature APK).
- Toute modification des backends, du portail ou des indices.

## Decisions

### D1 — Miroir de l'Android, groupe par groupe
Chaque groupe de `tasks.md` est porté après son équivalent Android, avec les mêmes fixtures JSON (copiées du dépôt Android) et les mêmes données de test NR. Une divergence fait échouer l'une des deux suites.

### D2 — `IndexTable` et codecs en types valeur
Zones de chauffage, modes immédiats, chauffe-eau (353), arrosage (363) et formule de bloc des scénarios s'ajoutent à `IndexTable`. `ScheduleCodec` et `chunk(_:size:)` sont des fonctions pures (`Sendable`), testées par Swift Testing.

### D3 — Repositories `actor` par fonction
`HeatingRepository`, `ScenarioRepository` et `ComfortRepository` suivent `ControlRepository` : un protocole, une implémentation cloud et une LAN, injectées par `AppContainer`. La progression de l'envoi du planning est un `AsyncStream` d'événements consommé par un modèle `@Observable` ; l'annulation de la tâche arrête l'envoi entre deux lots.

### D4 — Alarme : code éphémère
- Le code vit dans un `@State` de la vue (jamais `@SceneStorage`, `@AppStorage` ni Keychain), effacé après envoi et quand `scenePhase` quitte `.active`.
- Le champ est un `SecureField` avec `.keyboardType(.numberPad)` et `.textContentType(.oneTimeCode)` désactivé (pas de suggestion).
- Les journaux de debug (`Logger`) n'écrivent jamais le corps de `/web/actions`.
- L'écran Alarme est masqué en Release derrière un drapeau tant qu'un humain n'a pas validé la mise en service sur le banc BP (même règle qu'Android).

### D5 — Navigation à 5 onglets
`TabView` : Accueil, Éclairage, Volets, Chauffage, Réglages. L'accueil est dans un `NavigationStack` qui pousse Scénarios, Chauffe-eau, Arrosage et Alarme. La grille de chauffage défile par jour et doit rester utilisable sur iPhone SE (vérifié en test UI).

### D6 — Tests et NR
- **Unitaires** : Swift Testing avec `MockBackend` (`*.essensys.test`).
- **UI** : XCUITest contre `UITestBackend` étendu aux nouvelles routes (`UITEST_BACKEND=1`).
- **NR** : `NR-ios-10` et suivants, mêmes numéros et mêmes données que `NR-android-10` et suivants. Rapports via `xcresult_to_junit.py` puis `nonreg_report.py`.
- **Garde** : `NoArmoireGuard` étendu aux nouvelles routes de mutation.

### D7 — Version et livraison
`MARKETING_VERSION` 2.1.0, `CURRENT_PROJECT_VERSION` incrémenté, archive et envoi TestFlight selon le README (PATH système pour l'export), distribution au groupe famille.

## Risks / Trade-offs

Les risques fonctionnels (indices 353/363, encodage du code d'alarme, limite de débit, cache ancien) sont ceux du design Android.

- [Concurrence stricte Swift 6 sur un envoi long et annulable] → repositories `actor`, modèle `@MainActor`, tests d'annulation entre deux lots.
- [Grille 7 × 24 sur iPhone SE] → affichage jour par jour, test UI sur l'iPhone SE.
- [Simulateur lent ou bloqué sur le Mac mini] → simulateur nommé démarré explicitement avant les tests, comme en v2.0.0.

## Migration Plan

1. Branche `feat/mobile-portal-parity-2026-10-010`, PR par groupe ou lot de groupes, avec `Feature: mobile-portal-parity-2026-10-010` et `Refs`/`Closes` vers les sub-issues iPhone.
2. Build TestFlight 2.1.0 après `/checkup` vert.
3. Rollback : la build TestFlight 2.0.0 reste installable par les testeurs.
