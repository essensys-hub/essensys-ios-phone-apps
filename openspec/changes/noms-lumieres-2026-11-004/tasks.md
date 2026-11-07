## 8. App iPhone (essensys-ios-phone-apps) (#45)

- [x] 8.1 Ajouter la lecture des noms (cloud et réseau local, repli sur les noms d'origine) et le nom affiché dans `ComfortRepository` ; vérifier par des tests unitaires
- [x] 8.2 Afficher le nom partout : listes d'éclairage, fiche, écran Temporisations, éditeur de scénarios, confirmations ; vérifier par XCUITest
- [x] 8.3 Ajouter le champ « Nom » et « Nom d'origine » pour l'administrateur avec les écritures cloud et local, et les messages d'erreur ; vérifier par tests unitaires et XCUITest (`NR-ios-25`)
- [x] 8.4 Préparer la version 2.6.0 (`MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`) ; vérifier par build et tests sur simulateur (la version est passée à l'archive, `MARKETING_VERSION=2.6.0 CURRENT_PROJECT_VERSION=1` ; aucun envoi TestFlight)
