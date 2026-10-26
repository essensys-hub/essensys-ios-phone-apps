## 1. Règle armoire en ligne (#24)

- [ ] 1.1 Ajouter `online` à `ArmoireInfo` et `armoireOnline` à `PortalSession` ; l'utiliser dans `PortalRepository` et `SessionModel` ; vérifier par `NR-ios-19` (Swift Testing, cas A à F) et un test `PortalRepository` avec et sans gateway
- [ ] 1.2 Faire servir à `UITestBackend` une session sans gateway et un `last_seen` récent ou ancien ; vérifier par des tests XCUITest (cas D et E : badge et boutons)

## 2. Qualité et livraison (#25)

- [ ] 2.1 CI iOS verte, `/checkup` vert, README et `MARKETING_VERSION` 2.2.1
- [ ] 2.2 Validation sur le banc BP par un humain, puis build TestFlight 2.2.1 (groupe famille)
