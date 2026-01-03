# Checklist de Vérification - Projet Xcode

## ✅ Étapes à suivre dans Xcode

### 1. Vérifier la structure du projet

Ouvrir Xcode et vérifier que la structure suivante existe :

```
essensys-iphone (projet)
└── essensys-iphone (target)
    ├── essensys_iphoneApp.swift ✅
    ├── ContentView.swift ✅
    ├── Models/
    │   └── ConnectionConfig.swift ✅
    ├── Services/
    │   ├── ConnectionManager.swift ✅
    │   └── EssensysAPI.swift ✅
    └── Views/
        ├── HomeView.swift ✅
        ├── LightingView.swift ✅
        ├── AlarmView.swift ✅
        └── ConfigurationView.swift ✅
```

### 2. Vérifier que tous les fichiers sont dans le target

Pour chaque fichier Swift :

1. Sélectionner le fichier dans le navigateur
2. Ouvrir l'inspecteur de fichiers (panneau de droite, ⌘⌥1)
3. Section "Target Membership" :
   - ✅ Cocher `essensys-iphone`

**Fichiers à vérifier :**
- [ ] `essensys_iphoneApp.swift`
- [ ] `ContentView.swift`
- [ ] `Models/ConnectionConfig.swift`
- [ ] `Services/ConnectionManager.swift`
- [ ] `Services/EssensysAPI.swift`
- [ ] `Views/HomeView.swift`
- [ ] `Views/LightingView.swift`
- [ ] `Views/AlarmView.swift`
- [ ] `Views/ConfigurationView.swift`

### 3. Ajouter les fichiers manquants (si nécessaire)

Si un fichier n'apparaît pas dans Xcode :

1. Clic droit sur le groupe de destination (Models, Services, ou Views)
2. "Add Files to essensys-iphone..."
3. Naviguer vers le fichier
4. ✅ Cocher "Copy items if needed"
5. ✅ Cocher "Add to targets: essensys-iphone"
6. Cliquer "Add"

### 4. Vérifier la configuration du projet

1. Sélectionner le projet (icône bleue) dans le navigateur
2. Sélectionner le target `essensys-iphone`
3. Onglet "General" :
   - **Display Name** : Essensys
   - **Bundle Identifier** : essensys.essensys-iphone
   - **Version** : 1.0
   - **Build** : 1
   - **Minimum Deployments** : iOS 15.0

4. Onglet "Build Settings" :
   - Rechercher "Swift Language Version" → Doit être 5.0 ou supérieur
   - Rechercher "iOS Deployment Target" → Doit être 15.0 ou supérieur

### 5. Vérifier Info.plist

1. Vérifier que `Info.plist` existe dans le projet
2. Ouvrir le fichier
3. Vérifier que la clé suivante existe (pour permettre HTTP) :

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

### 6. Nettoyer et compiler

1. `Product > Clean Build Folder` (⇧⌘K)
2. `Product > Build` (⌘B)
3. Vérifier qu'il n'y a **aucune erreur** dans le panneau de rapport (⌘9)

### 7. Lancer l'application

1. Sélectionner un simulateur iOS (iPhone 15, iPhone 16, etc.)
2. `Product > Run` (⌘R)
3. L'application devrait démarrer avec l'onglet "Accueil"

## 🔍 Vérifications supplémentaires

### Vérifier qu'il n'y a qu'un seul `@main`

Rechercher dans tout le projet (⌘⇧F) :
- Rechercher : `@main`
- Résultat attendu : **1 occurrence** dans `essensys_iphoneApp.swift`

### Vérifier les imports

Tous les fichiers doivent avoir les imports nécessaires :
- `import SwiftUI` pour les vues
- `import Foundation` pour les services
- `import Combine` pour ConnectionManager

### Vérifier les erreurs de compilation

Si des erreurs apparaissent :

1. Lire le message d'erreur complet
2. Vérifier que tous les fichiers sont dans le target
3. Vérifier que les imports sont corrects
4. Vérifier que les noms de classes/structs correspondent

## 🚨 Problèmes courants

### "Cannot find 'ConnectionManager' in scope"

**Solution** : Vérifier que `ConnectionManager.swift` est dans le target `essensys-iphone`

### "Ambiguous use of 'ContentView'"

**Solution** : Il ne doit y avoir qu'un seul fichier `ContentView.swift` dans le projet

### "Multiple 'main' entry points found"

**Solution** : Supprimer tous les fichiers avec `@main` sauf `essensys_iphoneApp.swift`

### L'application se lance mais l'écran est vide

**Solution** : Vérifier que `ContentView` utilise bien les vues (HomeView, etc.) et que le ConnectionManager est passé en environmentObject


