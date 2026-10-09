## Context

Voir `proposal.md`. La référence fonctionnelle est **l'Android v2.0.0** (`essensys-android-phone-apps`, change `android-portal-refresh-2026-10-002`). Ses contrats d'API sont lus dans le code Go (design D5 bis Android) :
- **login cloud** : 200 `{token, user, password_change_required}`, jamais de 409 au login ;
- **409** `password_change_required` sur `/api/portal/*` ;
- **LAN** : cookie `essensys_lan_session`, pas de session ni d'historique, et `PUT /api/user/me/password` ferme toutes les sessions ;
- **erreurs** majoritairement en `text/plain`, et 429 sans `Retry-After`.

État iOS au 2026-10-09 :
- SwiftUI, `URLSession` avec callbacks, singleton `EssensysAPI` ;
- configuration dans `UserDefaults` (`essensys_connection_config`, mot de passe WAN compris) ;
- iOS 18.2 minimum, Swift 5 ;
- équipe `J32285QB9J`, bundle `essensys.essensys-iphone` ;
- Xcode 26.6 installé.

## Goals / Non-Goals

**Goals** :
- Parité fonctionnelle et visuelle avec l'Android v2.0.0.
- Code versionné.
- Tests sans réseau réel.
- Distribution TestFlight.

**Non-Goals** :
- Écrans V2.
- App Store public.
- Widgets, notifications et Siri.
- Changement des backends.

## Decisions

### D1 — Réintégration des sources par `git subtree`-like merge
On importe l'historique du dépôt local `EssensysApp/essensys-iphone` (12 commits, dont la modification locale de `HomeView`) dans le dépôt parent, sous le même chemin :
1. supprimer le gitlink : `git rm --cached` ;
2. récupérer l'historique : `git fetch` du dépôt local ;
3. le fusionner avec `merge -s ours --allow-unrelated-histories` puis `read-tree --prefix`.

L'historique est conservé et il n'y a plus de sous-module. Le dossier `.git` interne est archivé hors du dépôt, puis supprimé.

*Alternative écartée* : créer un dépôt GitHub dédié et un vrai sous-module. Ce serait une complexité inutile pour une seule app, et la CI serait plus fragile.

### D2 — Architecture miroir de l'Android
Les couches reprennent celles de l'app Android, pour qu'une revue puisse comparer les deux apps paquet par paquet :

| Couche | Rôle |
|---|---|
| `Data/HTTP` | `APIClient` async/await, `APIError` tolérant JSON ou texte, `NoArmoireGuard` |
| `Data/Auth` | connexion cloud et LAN, changement de mot de passe, déconnexion |
| `Data/Control` | `IndexTable` et envoi des commandes |
| `Data/Session` | `SessionStore` sur Keychain, liaison, état de la gateway, dernière action |
| `UI` | thème, composants, écrans, `@Observable` ViewModels |

Injection : un `AppContainer`, comme sur Android.

### D3 — `IndexTable` générée depuis la même source
La table Swift est générée depuis les pages du portail, comme pour Android. Le test `NR-ios` compare chaque couple à une copie figée identique à celle de `IndexTableTest` Android. Un écart entre les deux apps fait donc échouer l'une des deux suites.

### D4 — TLS LAN : TOFU via `URLSessionDelegate`
- **Sondage** : `urlSession(_:didReceive:)` récupère la chaîne présentée et affiche l'empreinte SHA-256 du dernier certificat.
- **Après confirmation** : on évalue le `SecTrust` avec ce certificat comme unique ancre (`SecTrustSetAnchorCertificates` puis `SecTrustSetAnchorCertificatesOnly`), en gardant la politique SSL avec le nom d'hôte.
- **ATS** reste strict : aucune exception globale, `NSAllowsLocalNetworking` seulement si nécessaire.

### D5 — Stockage : Keychain
Jeton, cookie et certificat épinglé sont stockés dans le Keychain (`kSecClassGenericPassword`, `AfterFirstUnlockThisDeviceOnly`). Les préférences non sensibles (mode, thème, mode test) vont dans `UserDefaults`. Au premier lancement, on purge `essensys_connection_config`.

### D6 — Tests
- **Unitaires** : un `MockURLProtocol` injecté dans `URLSessionConfiguration`, avec les fixtures JSON reprises de l'Android (`src/test/resources/fixtures`).
- **UI** : XCUITest avec l'argument de lancement `-uiTestBackend <port>`, qui démarre un serveur simulé in-process. Dans ce mode, `NoArmoireGuard` est actif et seul `127.0.0.1` est autorisé.
- **Rapports** : `xcresult` converti en JUnit (`xcresulttool`) pour `nonreg_report.py`. Identifiant `NR_ios_<n>` dans le nom du test et `// NR:` dans le source, comme pour Kotlin.

### D7 — Distribution TestFlight
- Archive signée en automatic signing par l'équipe `J32285QB9J`, téléversée avec `xcodebuild -exportArchive` et la méthode `app-store-connect`.
- Phase 1, à la main depuis le Mac mini : `/checkup` puis archive et upload, sans secret dans la CI.
- Phase 2 : workflow GitHub macOS avec une clé d'API App Store Connect chiffrée SOPS (même modèle que la clé de signature Android).
- Version : `MARKETING_VERSION` 2.0.0, aligné sur Android. `CURRENT_PROJECT_VERSION` est incrémenté à chaque upload.

## Risks / Trade-offs

- [Compte Apple Developer ou accès App Store Connect indisponible] → la tâche TestFlight est bloquante pour la livraison, mais pas pour le code. Le risque est signalé dès le groupe 1.
- [Swift 6 en concurrence stricte sur un code existant fait de callbacks] → la couche data est réécrite en async/await. Les anciennes vues sont supprimées, pas migrées.
- [Divergence future entre iOS et Android] → `IndexTable` est verrouillée des deux côtés par des tests NR, et les contrats sont documentés dans les deux designs.
- [Simulateur lent ou `simctl` qui bloque sur ce poste, comme observé le 2026-10-09] → on démarre explicitement un simulateur nommé avant les tests, avec des timeouts.

## Migration Plan

1. Branche `feat/ios-portal-refresh-2026-10-003`, réintégration des sources (D1), puis le reste de la refonte.
2. Build TestFlight 2.0.0 (1), distribuée au groupe de testeurs existant (famille).
3. Rollback : l'ancienne app n'est pas sur l'App Store. Les testeurs peuvent garder la v1 installée en local tant que la v2 TestFlight n'est pas validée.

## Open Questions

- Liste exacte des testeurs TestFlight. Elle sera fournie au moment de l'invitation.
