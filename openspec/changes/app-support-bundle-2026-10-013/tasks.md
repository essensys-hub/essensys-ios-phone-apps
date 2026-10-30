## 1. Journal et diagnostics (#28)

- [ ] 1.1 Ajouter `AppLog` (actor, anneau de 500 entrées, persisté en JSON lignes) et l'alimenter depuis `APIClient.get`/`send` ; vérifier par des tests XCTest (rotation, relecture après redémarrage, aucun en-tête ni corps enregistré)
- [ ] 1.2 Ajouter `SupportDiagnostics` (appareil, réseau, temps de réponse HTTPS, portail, gateway, réglages) avec délais par test ; vérifier par des tests `URLProtocol` simulé (health OK, délai dépassé, 401, LAN injoignable, mode test) et l'absence de tout appel `inject`

## 2. Bundle, écran Support et email (#29)

- [ ] 2.1 Ajouter `SupportBundle` (zip `resume.txt`, `diagnostics.json`, `journal.jsonl` via `NSFileCoordinator`) ; vérifier par un test qui décompresse le zip, et par `NR-ios-20` (aucun token, cookie, mot de passe ni clé d'accès dans le zip)
- [ ] 2.2 Ajouter l'écran Support (depuis Réglages et l'écran de connexion), le résumé et le composeur Mail vers `EssensysSupportEmail` avec repli sur le partage ; vérifier par `SupportUITests` (simulateur) et un test des paramètres du composeur

## 3. Qualité et livraison (#30)

- [ ] 3.1 CI verte, `/checkup` vert, captures de l'écran Support sur #38, README, `PRIVACY.md` et version 2.3.0
- [ ] 3.2 Vérification réelle par un humain (Wi-Fi puis 4G, Mail et partage vers Gmail) avec réception du zip à l'adresse support, puis TestFlight et release `ios-v2.3.0`
