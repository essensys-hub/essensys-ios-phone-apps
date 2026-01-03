# Guide de Dépannage - Essensys iOS

## Erreur : "No such process" lors du lancement

### Problème
L'application ne démarre pas dans le simulateur avec l'erreur :
```
Simulator device failed to launch essensys.essensys-iphone
Domain: NSPOSIXErrorDomain
Code: 3
Failure Reason: No such process
```

### Solutions

#### 1. Vérifier les fichiers du projet Xcode

Assurez-vous que tous les fichiers sont ajoutés au target :

1. Ouvrir Xcode
2. Dans le navigateur de projet (panneau de gauche), vérifier que tous les fichiers sont présents :
   - `essensys_iphoneApp.swift` (fichier principal avec `@main`)
   - `ContentView.swift` (dans `essensys-iphone/`)
   - Tous les fichiers dans `Models/`
   - Tous les fichiers dans `Services/`
   - Tous les fichiers dans `Views/`

3. Pour chaque fichier, vérifier dans l'inspecteur de fichiers (panneau de droite) :
   - ✅ Cocher "Target Membership" → `essensys-iphone`

#### 2. Vérifier qu'il n'y a qu'un seul point d'entrée `@main`

**IMPORTANT** : Il ne doit y avoir qu'**un seul** fichier avec `@main` dans tout le projet.

- ✅ **Garder** : `essensys-iphone/essensys-iphone/essensys_iphoneApp.swift` (avec `@main`)
- ❌ **Supprimer** : `EssensysApp/EssensysApp.swift` (s'il existe encore)

#### 3. Nettoyer le build

1. Dans Xcode : `Product > Clean Build Folder` (⇧⌘K)
2. Fermer Xcode complètement
3. Supprimer le dossier `DerivedData` :
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData
   ```
4. Rouvrir Xcode et le projet
5. Recompiler : `Product > Build` (⌘B)

#### 4. Vérifier la configuration du projet

1. Sélectionner le projet dans le navigateur (icône bleue en haut)
2. Sélectionner le target `essensys-iphone`
3. Onglet "General" :
   - **Bundle Identifier** : `essensys.essensys-iphone` (ou votre identifiant)
   - **Minimum Deployments** : iOS 15.0 ou supérieur
   - **Supported Destinations** : iPhone

4. Onglet "Build Settings" :
   - Rechercher "Swift Language Version" → Doit être 5.0 ou supérieur
   - Rechercher "iOS Deployment Target" → Doit être 15.0 ou supérieur

#### 5. Vérifier les erreurs de compilation

1. Ouvrir le panneau de rapport (⌘9)
2. Vérifier s'il y a des erreurs de compilation
3. Corriger toutes les erreurs avant de relancer

#### 6. Réinitialiser le simulateur

1. Dans Xcode : `Window > Devices and Simulators`
2. Sélectionner le simulateur utilisé
3. Clic droit → "Erase All Content and Settings"
4. Relancer l'application

#### 7. Vérifier que tous les fichiers sont compilés

Dans le navigateur de projet, vérifier que tous les fichiers Swift ont une icône (pas de point d'interrogation ou d'erreur).

Si un fichier n'est pas reconnu :
1. Clic droit sur le fichier → "Delete" → "Remove Reference" (ne pas supprimer le fichier)
2. Faire glisser le fichier depuis Finder dans Xcode
3. Cocher "Copy items if needed" et "Add to targets: essensys-iphone"

## Structure de fichiers attendue

```
essensys-iphone/
├── essensys-iphone/
│   ├── essensys_iphoneApp.swift    ← Point d'entrée (@main)
│   ├── ContentView.swift           ← Vue principale
│   ├── Assets.xcassets/
│   └── Info.plist
├── Models/
│   └── ConnectionConfig.swift
├── Services/
│   ├── ConnectionManager.swift
│   └── EssensysAPI.swift
└── Views/
    ├── HomeView.swift
    ├── LightingView.swift
    ├── AlarmView.swift
    └── ConfigurationView.swift
```

## Vérifications finales

Avant de lancer l'application, vérifier :

- [ ] Un seul fichier avec `@main` (essensys_iphoneApp.swift)
- [ ] Tous les fichiers sont dans le target "essensys-iphone"
- [ ] Aucune erreur de compilation
- [ ] Info.plist est présent et configuré
- [ ] Le simulateur est bien sélectionné
- [ ] iOS 15.0+ est supporté

## Si le problème persiste

1. Créer un nouveau projet Xcode vierge
2. Copier uniquement les fichiers Swift (pas les fichiers de projet)
3. Ajouter les fichiers au nouveau projet un par un
4. Vérifier après chaque ajout que le projet compile


