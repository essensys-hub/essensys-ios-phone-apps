## 1. Commande et état

- [ ] 1.1 Ajouter à `IndexTable` les indices 623 et 440, la commande et le décalage 31 ; vérifier par `NR-ios-18` (mêmes données que `NR-android-18`)
- [ ] 1.2 Ajouter au `ComfortRepository` la commande des prises et la lecture de 440 ; vérifier par des tests `MockBackend` en cloud et en LAN

## 2. Écran Prises de sécurité

- [ ] 2.1 Écran poussé depuis une tuile d'accueil (état, confirmation avant coupure, rétablissement, hors ligne) ; vérifier par des tests XCUITest
- [ ] 2.2 Choix « Prises de sécurité » dans l'éditeur de scénarios ; vérifier par un test XCUITest

## 3. Qualité et livraison

- [ ] 3.1 CI iOS verte, `/checkup` vert, captures sur #36, README et `MARKETING_VERSION` 2.2.0
- [ ] 3.2 Validation sur le banc BP par un humain, puis build TestFlight 2.2.0 (groupe famille)
