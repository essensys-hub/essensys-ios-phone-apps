## Purpose

Garantit que l'app iPhone est versionnée dans le dépôt, construite sur une base à jour, testée automatiquement sur simulateur sans jamais piloter d'armoire réelle, vérifiable par `/checkup`, et distribuée aux testeurs via TestFlight.

## ADDED Requirements

### Requirement: Sources versionnées
Les sources de l'app (projet Xcode, code, tests, ressources) SHALL être suivies directement par le dépôt `essensys-ios-phone-apps` avec leur historique ; aucun sous-module sans `.gitmodules` ni remote NE SHALL subsister.

#### Scenario: Clone neuf
- **WHEN** on clone `essensys-ios-phone-apps` sur une machine vierge
- **THEN** le projet Xcode et tout le code sont présents et `xcodebuild build` réussit sans autre dépôt

### Requirement: Base à jour
L'app SHALL compiler avec le Xcode courant en Swift 6 (concurrence stricte), cibler iOS 18 minimum et ne contenir aucun avertissement de compilation bloquant.

#### Scenario: Build propre
- **WHEN** on exécute `xcodebuild -scheme essensys-iphone -destination 'platform=iOS Simulator,name=iPhone 17' build`
- **THEN** le build réussit

### Requirement: Tests unitaires et UI
Le dépôt SHALL contenir des tests XCTest unitaires (couche data : auth, 401/409, table d'indices, anti-rebond, trust LAN) contre un `URLProtocol` simulé, et des tests UI XCUITest (connexion, éclairage, volets, thème) contre un backend simulé, exécutés sur simulateur.

#### Scenario: Suite locale
- **WHEN** on lance `xcodebuild test` sur un simulateur iPhone
- **THEN** tous les tests passent sans accès réseau à un serveur Essensys réel

### Requirement: Garde no-armoire
En test, toute requête de mutation (`/api/portal/inject`, `/api/admin/inject`, `/web/actions`, `/scenarios/*/launch`) vers un hôte autre que le serveur simulé local SHALL échouer immédiatement avec un message « no-armoire ».

#### Scenario: Fuite vers un hôte réel
- **WHEN** un test tente une injection vers `mon.essensys.fr`
- **THEN** l'appel échoue avec « no-armoire : mutation réelle interdite »

### Requirement: Non-régression alignée sur Android
Les comportements critiques SHALL être couverts par des tests `NR-ios-<n>` référençant l'issue d'origine, au minimum les mêmes que `NR-android-1` à `NR-android-8` (garde, 401, 409, pas de mode démo, couples (k, v) éclairage et volets identiques à `IndexTable` Android, dry-run, double appui), consolidés par `nonreg_report.py`.

#### Scenario: Parité des indices
- **WHEN** la table d'indices iOS diverge d'un couple (k, v) de la table Android / portail
- **THEN** le test `NR-ios-*` correspondant échoue

### Requirement: Checkup
`/checkup essensys-ios-phone-apps` SHALL être vert avant toute PR : build, tests unitaires, NR, tests UI sur simulateur et captures des écrans connexion, éclairage, volets et réglages (clair et sombre).

#### Scenario: Rapport sur l'issue
- **WHEN** le checkup est vert
- **THEN** le rapport et les captures sont postés sur l'issue Feature #13

### Requirement: Distribution TestFlight
Une build signée de l'équipe Apple Essensys SHALL être téléversée sur App Store Connect et distribuée aux testeurs via TestFlight ; aucun certificat, profil, clé d'API App Store Connect ni mot de passe NE SHALL être versionné dans le dépôt (secrets SOPS / secrets CI uniquement).

#### Scenario: Invitation testeur
- **WHEN** un testeur reçoit l'invitation TestFlight
- **THEN** il installe l'app depuis l'application TestFlight sans manipulation technique
