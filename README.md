# Essensys iPhone

L'application iPhone officielle pour piloter une installation domotique Essensys. Elle reprend l'apparence et le fonctionnement du portail web, en **cloud** (`mon.essensys.fr`) ou directement sur le **réseau local** (gateway `mon.essensys.local`). C'est la jumelle de l'[app Android](https://github.com/essensys-hub/essensys-android-phone-apps) : mêmes écrans, mêmes commandes.

> **Version 2.1.0** (en cours, change OpenSpec `mobile-portal-parity-2026-10-010`, ticket [essensys-feature-lifecycle#35](https://github.com/essensys-hub/essensys-feature-lifecycle/issues/35)) : toutes les fonctions du portail utiles à l'occupant, identiques à l'Android 2.1.0. La v2.0.0 (refonte complète de la v1) venait du change `ios-portal-refresh-2026-10-003` ([#13](https://github.com/essensys-hub/essensys-feature-lifecycle/issues/13)).

## Fonctionnalités

- **Connexion cloud** avec votre compte du portail (email et mot de passe), y compris le changement obligatoire d'un mot de passe temporaire.
- **Connexion réseau local** directement à la gateway, en HTTPS uniquement. Le certificat de la gateway est confirmé une seule fois, à la première connexion.
- **Liaison de l'armoire** : un compte sans armoire liée peut demander la liaison depuis l'application.
- **Accueil** : scénarios rapides (Je sors, Je rentre, Je vais me coucher, Je me lève) et une tuile par fonction.
- **Éclairage** : par pièce, éclairage principal et indirect, « tout allumer » et « tout éteindre ».
- **Volets et stores** : par volet, par groupe ou tous ; temps de course de chaque volet affiché et réglable (1 à 255 secondes).
- **Chauffage** : planning hebdomadaire des 4 zones (jour, nuit, salles de bain), modifiable heure par heure, et mode immédiat (automatique, anticipé, forçages, hors gel, arrêt). En réseau local, le planning peut être relu directement depuis l'armoire.
- **Scénarios** : lancement des scénarios 2 à 8, retour aux réglages d'usine (2 à 6) et choix des lumières et volets commandés.
- **Chauffe-eau** : marche permanente, heures creuses ou arrêt.
- **Arrosage** : automatique, 15, 30 ou 60 minutes, ou arrêt.
- **Prises de sécurité** : état (coupées, pilotées ou inconnu), « Couper » avec confirmation et « Rétablir », en cloud comme en réseau local. Un scénario peut aussi couper ou rétablir les prises (éditeur de scénarios).
- **Armoire en ligne** : le badge « Armoire en ligne » et les commandes suivent la gateway **ou** l'armoire elle-même (dernier contact de moins de 2 min), pour les installations avec ou sans gateway. En réseau local, les commandes restent actives.
- **Alarme** (cloud seulement) : mise en service et arrêt avec le code à 4 chiffres, jamais conservé par l'application. Masquée dans les builds Release (TestFlight) tant que la commande n'a pas été validée sur une armoire de test.
- **État de l'armoire** (en ligne ou hors ligne) et **dernière action** en cloud. Les commandes sont désactivées quand l'armoire est hors ligne ; les plannings restent consultables.
- **Mode test** : le serveur valide les commandes sans que l'armoire les exécute.
- **Support** (Réglages, ou sous l'écran de connexion) : l'application teste votre iPhone, le réseau, le serveur Essensys et votre armoire, en lecture seule, sans envoyer aucune commande. Elle prépare ensuite un email vers le support avec le résumé et un fichier zip (résultats et journal de l'application, sans mot de passe ni jeton). Vous le relisez avant de l'envoyer.
- **Thème** Système, Clair ou Sombre, avec la charte du portail.

Les notifications SMS et email et les caméras UniFi Protect restent accessibles depuis le portail web.

## Aperçu

| Connexion | Accueil | Éclairage | Volets |
|---|---|---|---|
| ![Connexion](img/v2/01-login-light.png) | ![Accueil](img/v2/02-home-light.png) | ![Éclairage](img/v2/03-lighting-light.png) | ![Volets](img/v2/04-shutters-light.png) |

| Mot de passe temporaire | Liaison armoire | Éclairage (sombre) | Réglages (sombre) |
|---|---|---|---|
| ![Mot de passe](img/v2/05-password-change.png) | ![Liaison](img/v2/06-link.png) | ![Éclairage sombre](img/v2/07-lighting-dark.png) | ![Réglages](img/v2/08-settings-dark.png) |

| Chauffage | Chauffage (sombre) | Scénarios | Chauffe-eau |
|---|---|---|---|
| ![Chauffage](img/v2/09-heating-light.png) | ![Chauffage sombre](img/v2/13-heating-dark.png) | ![Scénarios](img/v2/11-scenarios-light.png) | ![Chauffe-eau](img/v2/12-water-heater-light.png) |

## Installation (testeurs, via TestFlight)

1. Installez l'application **TestFlight** depuis l'App Store (gratuite, éditée par Apple).
2. Ouvrez l'**invitation** reçue par email depuis votre iPhone, puis appuyez sur **Voir dans TestFlight** et **Accepter**.
3. Dans TestFlight, appuyez sur **Installer** à côté de **Essensys**. Les mises à jour arrivent ensuite automatiquement.
4. Ouvrez l'application et choisissez le mode de connexion :
   - **Cloud** (recommandé) : connectez-vous avec le compte de votre portail `mon.essensys.fr`.
   - **Réseau local** : à utiliser chez vous, sur le Wi-Fi de l'installation. Adresse par défaut : `https://mon.essensys.local`. À la première connexion, l'application affiche l'**empreinte du certificat de la gateway**. Comparez-la avec celle que vous a transmise l'installateur, puis confirmez seulement si elle est identique.
5. Le badge vert **« Armoire en ligne »** confirme que votre installation est reliée. Après chaque appui, l'application confirme l'envoi, et l'armoire exécute la commande en environ 5 secondes.

Si vous aviez installé l'ancienne version (v1), vous pouvez la supprimer. Ses identifiants, qui étaient stockés en clair, sont effacés par la v2.

## Développement

Swift 6 (concurrence stricte) et SwiftUI, iOS 18 minimum, Xcode 26.6. Le projet Xcode `essensys-iphone.xcodeproj` est à la racine du dépôt (attendu par Xcode Cloud).

### Prérequis

- Xcode 26.6 avec la plateforme iOS 26.5 (`xcodebuild -downloadPlatform iOS`).
- Si `simctl` bloque ou que Xcode signale « CoreSimulator is out of date », lancez une fois `sudo xcodebuild -runFirstLaunch`.

### Publier une build TestFlight

```bash
xcodebuild -project essensys-iphone.xcodeproj -scheme essensys-iphone -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/essensys.xcarchive archive -allowProvisioningUpdates
# PATH système : le rsync de Homebrew (3.x) casse la création de l'IPA (« Copy failed »).
env PATH=/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -exportArchive -archivePath build/essensys.xcarchive \
  -exportOptionsPlist ExportOptions.plist -exportPath build/export -allowProvisioningUpdates
```

`ExportOptions.plist` : `method` = `app-store-connect`, `destination` = `upload`, `teamID` = `J32285QB9J`, signature automatique. Il faut le compte Apple connecté dans Xcode et l'accord de licence du programme à jour. Incrémentez `CURRENT_PROJECT_VERSION` avant chaque nouvel envoi.

### Commandes

```bash
xcodebuild -project essensys-iphone.xcodeproj -scheme essensys-iphone \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```

- **Tests unitaires** (Swift Testing) : la couche data est testée contre un backend simulé (`URLProtocol`, hôtes `*.essensys.test`).
- **Tests UI** (XCUITest) : l'app tourne avec un backend simulé embarqué (`UITEST_BACKEND=1`, builds DEBUG seulement).

Les tests ne pilotent **jamais** une armoire réelle : `NoArmoireGuard` fait échouer toute commande envoyée vers un hôte réel.

Les tests de non-régression portent l'identifiant `NR-ios-<n>` et la référence de leur issue. Ils reprennent les mêmes couples (k, v) que l'Android, et se consolident avec :

```bash
python3 ../essensys-feature-lifecycle/scripts/feature_lifecycle/xcresult_to_junit.py <résultat>.xcresult --out junit/unit.xml
python3 ../essensys-feature-lifecycle/scripts/feature_lifecycle/nonreg_report.py --sources . \
  --out nonreg.json --markdown nonreg.md junit
```

### Architecture

| Dossier | Rôle |
|---|---|
| `Data/HTTP` | `APIClient` (async/await), erreurs normalisées, garde no-armoire, TLS épinglé en LAN (`LanTrust`) |
| `Data/Auth` | Connexion cloud (JWT) et LAN (cookie de session), changement de mot de passe, déconnexion |
| `Data/Control` | `IndexTable` (indices et masques du portail, verrouillés par les tests NR) et envoi des commandes |
| `Data/Session` | Session (Keychain, purge de la configuration v1), liaison, état de la gateway, dernière action |
| `UI` | Thème du portail, composants, écrans, modèles observables |
| `Debug` | Backend simulé pour les tests UI (DEBUG uniquement) |

Gouvernance : chaque modification part d'un ticket du [GitHub Project Essensys](https://github.com/orgs/essensys-hub/projects/6), voir `essensys-feature-lifecycle/claude/GOVERNANCE.md`.

Les documents `INDICES.md`, `LAMPES_LISTE.md`, `SETUP.md`, `STRUCTURE.md`, `TROUBLESHOOTING.md` et `VERIFICATION.md` décrivent la **v1** et sont conservés pour l'historique.
