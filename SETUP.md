# Guide de Configuration du Projet iOS Essensys

## Création du projet Xcode

### Option 1 : Créer un nouveau projet Xcode

1. Ouvrir Xcode
2. Créer un nouveau projet : `File > New > Project`
3. Sélectionner `iOS > App`
4. Configurer le projet :
   - **Product Name** : `EssensysApp`
   - **Interface** : `SwiftUI`
   - **Language** : `Swift`
   - **Bundle Identifier** : `com.essensys.app` (ou votre identifiant)
   - **Minimum Deployment** : `iOS 15.0`

5. Choisir l'emplacement du projet et créer

### Option 2 : Utiliser les fichiers existants

Si vous avez déjà créé le projet, copiez les fichiers de ce dépôt dans votre projet Xcode :

1. Créer les groupes suivants dans Xcode :
   - `Models`
   - `Services`
   - `Views`

2. Ajouter les fichiers correspondants :
   - `EssensysApp/EssensysApp.swift` → Remplacer le fichier `App.swift` généré
   - `EssensysApp/Models/ConnectionConfig.swift` → Groupe `Models`
   - `EssensysApp/Services/ConnectionManager.swift` → Groupe `Services`
   - `EssensysApp/Services/EssensysAPI.swift` → Groupe `Services`
   - `EssensysApp/Views/ContentView.swift` → Groupe `Views`
   - `EssensysApp/Views/HomeView.swift` → Groupe `Views`
   - `EssensysApp/Views/LightingView.swift` → Groupe `Views`
   - `EssensysApp/Views/AlarmView.swift` → Groupe `Views`
   - `EssensysApp/Views/ConfigurationView.swift` → Groupe `Views`

3. Remplacer `Info.plist` par celui fourni dans ce dépôt

## Configuration requise

### Info.plist

Assurez-vous que votre `Info.plist` contient les clés suivantes pour permettre les connexions HTTP/HTTPS :

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

### Capabilities

Aucune capability spéciale n'est requise pour cette version de base.

## Test de l'application

1. Sélectionner un simulateur iOS ou un appareil physique
2. Compiler et exécuter (⌘R)
3. L'application devrait démarrer avec l'onglet "Accueil" sélectionné

## Configuration de la connexion

### Mode Local (par défaut)

- URL : `http://mon.essensys.fr`
- Aucune authentification requise
- Fonctionne sur le réseau WiFi local

### Mode WAN

1. Aller dans l'onglet "Configuration"
2. Cliquer sur "Modifier"
3. Sélectionner "WAN"
4. Entrer l'URL du domaine DNS (ex: `https://essensys.example.com`)
5. Entrer le mot de passe WAN
6. Cliquer sur "Enregistrer"

## Dépannage

### Erreur de connexion

- Vérifier que le backend Essensys est accessible
- Vérifier l'URL configurée dans l'onglet Configuration
- Pour le mode WAN, vérifier le mot de passe et le domaine DNS

### Erreurs de compilation

- Vérifier que tous les fichiers sont ajoutés au target
- Vérifier que SwiftUI est bien importé dans tous les fichiers de vues
- Vérifier la version minimale d'iOS (15.0)


