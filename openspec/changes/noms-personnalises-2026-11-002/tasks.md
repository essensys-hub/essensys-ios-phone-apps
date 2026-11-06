## 1. Référentiel, cache et API (#39)

- [ ] 1.1 Ajouter à l'app la copie du catalogue des noms (`catalog.json`) et les vecteurs communs `names_vectors.json`, puis les rejouer ; vérifier par un test qui reconstruit chaque libellé actuel d'`IndexTable` à l'identique, par les vecteurs en Swift Testing et par le script de parité de la feature
- [ ] 1.2 Ajouter le référentiel de noms (acteur) : lecture cloud et réseau local avec `If-None-Match`, `since` et réponse 404, un seul rafraîchissement à la fois, écriture et rétablissement, cache dans les préférences par installation et par mode, effacé à la déconnexion ; vérifier par des tests avec un serveur simulé (304, changements depuis une révision, 404 mémorisé, demandes simultanées réduites à un appel, changement de mode, déconnexion)
- [ ] 1.3 Implémenter la règle de nom affiché et la validation (40 points de code, NFC, caractères interdits) ; vérifier par le passage de tous les vecteurs communs

## 2. Écran Noms et affichage (#40)

- [ ] 2.1 Ajouter l'écran « Noms » aux Réglages (catégories, origine de chaque nom, feuille de modification avec compteur, rétablissement, aperçu d'une pièce, refus hors ligne, masqué sans `can_rename`) ; vérifier par des XCUITest (administrateur, utilisateur ordinaire, refus du serveur, hors ligne)
- [ ] 2.2 Remplacer les libellés d'`IndexTable` par `displayName` dans l'éclairage, les volets, le chauffage, les prises de sécurité, le chauffe-eau, l'arrosage, les scénarios et l'éditeur, et dans les confirmations ; vérifier par un XCUITest qui renomme une pièce et contrôle chaque écran, et par un test que le journal et le bundle Support ne contiennent aucun nom
- [ ] 2.3 Rafraîchir les noms au retour au premier plan et toutes les 30 s écran visible, tâche arrêtée en arrière-plan ; vérifier par des tests (changement venu d'un autre environnement visible en moins d'une minute, arrêt en arrière-plan)

## 3. Qualité et livraison (#41)

- [ ] 3.1 Ajouter `NR-ios-24` (utilisateur sans droit : pas d'écran « Noms », écriture refusée), `NR-ios-25` (noms d'origine si l'API est absente) et `NR-ios-26` (renommer ne change aucun indice ni masque), plus les tests UI sur simulateur dans les deux modes, sans armoire réelle ; vérifier par leur passage, puis par la suite complète des tests existants toujours verte
- [ ] 3.2 CI verte, `/checkup` vert, captures de l'écran « Noms » et d'un écran renommé sur #41, README et version 2.5.0
- [ ] 3.3 Une fois le cloud, la gateway et les portails déployés : vérification réelle par un humain avec un compte administrateur sur TestFlight (renommer une pièce, voir le nom sur les autres clients en moins d'une minute), puis tag `ios-v2.5.0`
