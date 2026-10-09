> Ticket : [essensys-hub/essensys-feature-lifecycle#13](https://github.com/essensys-hub/essensys-feature-lifecycle/issues/13). Feature ID : `ios-portal-refresh-2026-10-003`. Jumelle de `android-portal-refresh-2026-10-002` (Android v2.0.0, #11), qui sert de référence.

## Why

L'app iPhone (janvier 2026) a les mêmes défauts que l'Android v1 :
- Basic Auth, `/api/admin/inject` en cloud ;
- mot de passe en clair dans `UserDefaults`, HTTP en clair ;
- écrans en partie factices, aucun test.

Surtout, **ses sources n'existent que sur le poste du mainteneur** : un sous-module sans `.gitmodules` ni remote, que GitHub ne connaît que comme un pointeur.

Après la livraison de l'Android v2.0.0, les testeurs iPhone doivent avoir la même app.

## What Changes

- **Réintégration des sources** dans le dépôt, avec leur historique (11 commits, plus la modification locale de `HomeView` conservée).
- **BREAKING** — même contrat que l'Android v2 :
  - cloud : JWT `/api/auth/login` puis `/api/portal/*`, mot de passe temporaire et 409 ;
  - LAN : cookie `essensys_lan_session`, certificat de la gateway épinglé en TOFU ;
  - HTTPS uniquement, secrets dans le Keychain, purge de la configuration v1 en clair.
- **Écrans V1** : connexion Cloud / Réseau local, liaison de l'armoire, état de l'armoire et dernière action, Éclairage, Volets (temps de course), Réglages (mode, thème, mode test, déconnexion).
  - Couples (k, v) identiques au portail et à `IndexTable` Android.
  - Anti-rebond.
  - Suppression du mode démo et des écrans factices.
- **Charte du portail** en clair et en sombre, en SwiftUI.
- **Base** : Swift 6, iOS 18 minimum.
- **Qualité** :
  - tests XCTest et XCUITest sur simulateur, contre un backend simulé ;
  - `NR-ios-*` alignés sur `NR-android-*` ;
  - garde no-armoire ;
  - `/checkup` vert.
- **Distribution TestFlight** (équipe Apple `J32285QB9J`) sans secret dans le dépôt.
- **Hors V1** : chauffage, scénarios, chauffe-eau, arrosage, alarme, App Store public.

## Capabilities

### New Capabilities

- `mobile-auth` : connexion cloud (JWT) et LAN (session gateway), Keychain, expiration, changement de mot de passe, déconnexion.
- `connection-modes` : choix cloud / LAN, HTTPS et certificat LAN épinglé, liaison de l'armoire, état de la gateway, dernière action, pas de mode démo.
- `domotic-controls` : éclairage et volets V1, mêmes indices que le portail et Android, retour utilisateur, anti-rebond, dry-run.
- `portal-theme` : charte du portail en clair et en sombre.
- `ios-quality` : sources versionnées, base Swift 6, tests unitaires, UI et NR, garde no-armoire, `/checkup`, TestFlight.

### Modified Capabilities

<!-- Aucune spec existante dans ce dépôt (OpenSpec initialisé par ce change). -->

## Impact

- `EssensysApp/essensys-iphone/**` : de gitlink orphelin à fichiers suivis ; réécriture des couches `Services`/`Models` (API, auth, Keychain, TLS LAN) et `Views` (SwiftUI).
- Projet Xcode : Swift 6, cibles de tests, schéma de test, `Info.plist` (ATS strict).
- `features/` et `scripts/feature_lifecycle/` (gate), workflow CI macOS, workflow TestFlight.
- `essensys-ansible/secrets/cloud/` : clé d'API App Store Connect et matériel de signature (SOPS) si la CI téléverse.
- Backends : aucun changement (mêmes API que l'Android v2).
