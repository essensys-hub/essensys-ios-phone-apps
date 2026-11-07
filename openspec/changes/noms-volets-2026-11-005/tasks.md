## 6. App iPhone (essensys-ios-phone-apps) (#47)

- [x] 6.1 Ajouter la lecture des noms de volets (cloud et réseau local, repli sur les noms d'origine) et le nom affiché dans `ComfortRepository` ; vérifier par des tests unitaires
- [x] 6.2 Afficher le nom partout dans `ControlScreens.swift` : liste des deux groupes, confirmations, carte « Temps de course » ; vérifier par XCUITest (iPhone SE inclus pour un nom de 40 caractères)
- [x] 6.3 Ajouter le champ « Nom » et « Nom d'origine » pour l'administrateur avec les écritures cloud et local, et les messages d'erreur ; vérifier par tests unitaires et XCUITest (`NR-ios-26`)
- [x] 6.4 Préparer la version 2.7.0 (`MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`) ; vérifier par build et tests sur simulateur (la version est passée à l'archive, `MARKETING_VERSION=2.7.0 CURRENT_PROJECT_VERSION=1` ; aucun envoi TestFlight)
