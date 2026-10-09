## 1. Sources, socle et outillage de test (#1)

- [x] 1.1 Réintégrer les sources (D1) : retirer le gitlink, importer l'historique local (dont `wip(home)`), supprimer le `.git` interne après archivage ; vérifier qu'un clone neuf contient `essensys-iphone.xcodeproj` et que `git submodule status` est vide
- [x] 1.2 Base : Swift 6 (concurrence stricte), iOS 18 minimum, cibles de tests unitaires et UI, schéma de test partagé ; vérifier `xcodebuild build` et `xcodebuild test` (suite vide) sur un simulateur iPhone
- [x] 1.3 Outillage : `MockURLProtocol`, fixtures JSON reprises de l'Android, `NoArmoireGuard`, conversion xcresult vers JUnit ; vérifier un test `NR_ios_1` (mutation vers un hôte réel bloquée) dans le rapport `nonreg_report.py`
- [ ] 1.4 Vérifier l'accès App Store Connect (équipe J32285QB9J, rôle permettant TestFlight) ; consigner le résultat sur #13

## 2. Couche data et authentification (#2)

- [x] 2.1 `APIClient` async/await, `APIError` (JSON ou texte), en-têtes de session et de dry-run ; tests unitaires
- [x] 2.2 `SessionStore` Keychain et purge de `essensys_connection_config` ; tests (migration v1)
- [x] 2.3 Auth cloud (login, drapeau mot de passe temporaire, 409, change, logout, 401/403) ; tests `NR_ios_2` (401 → déconnexion) et `NR_ios_3` (mot de passe obligatoire)
- [x] 2.4 Auth LAN (cookie, `PUT /api/user/me/password` ferme la session) et TOFU TLS (D4) ; tests avec certificat de test

## 3. Modes de connexion et session (#3)

- [x] 3.1 Écrans connexion (Cloud / Réseau local, refus de `http://`, confirmation de l'empreinte) et changement de mot de passe ; tests UI
- [x] 3.2 Liaison de l'armoire (statut, demande) ; test UI d'un compte sans armoire
- [x] 3.3 État de la gateway (60 s) et dernière action (2 s) au premier plan uniquement (`scenePhase`) ; test de cadence et d'arrêt
- [x] 3.4 Pas de mode démo : erreur « Connexion impossible » et « Réessayer » ; `NR_ios_4`

## 4. Commandes Éclairage et Volets (#4)

- [x] 4.1 `IndexTable` (D3) et envoi des commandes cloud et LAN ; `NR_ios_5` (éclairage) et `NR_ios_6` (volets), copies figées identiques à l'Android
- [x] 4.2 Écran Éclairage (groupes, tout allumer / éteindre, retour, anti-rebond) ; `NR_ios_8` (double appui = une seule commande)
- [x] 4.3 Écran Volets (temps de course) ; test UI de la fermeture du volet cuisine (622/1)
- [x] 4.4 Mode test dry-run (réglage, bandeau, message) ; `NR_ios_7`

## 5. Thème et finitions (#5)

- [x] 5.1 Thème du portail (tokens clair et sombre, formes), choix Système / Clair / Sombre ; test des tokens
- [x] 5.2 Navigation V1 (Accueil, Éclairage, Volets, Réglages ; « Bientôt disponible »), suppression des écrans factices et de l'ancienne couche API ; vérifier sur iPhone SE et Pro Max
- [x] 5.3 Réglages (mode, thème, mode test, déconnexion, version) ; test UI

## 6. Qualité, distribution et livraison (#6)

- [ ] 6.1 CI GitHub macOS : build, tests unitaires, rapport NR ; vérifier un run vert sur la PR
- [ ] 6.2 `/checkup essensys-ios-phone-apps` vert, captures postées sur #13 ; manifest à jour, gate `--strict` verte
- [ ] 6.3 Archive signée 2.0.0 et upload TestFlight (D7, phase 1) ; vérifier la build « Ready to Test » dans App Store Connect
- [x] 6.4 README, captures et guide testeur TestFlight (invitation, installation, connexion Cloud)
- [ ] 6.5 Inviter les testeurs (dont Bertrand Germain) et recueillir leurs retours sur #13
