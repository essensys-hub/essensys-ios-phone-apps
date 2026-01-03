# Essensys iOS Application

Application iOS native pour contrôler le système Essensys depuis un iPhone.

## Fonctionnalités

- **Connexion WiFi locale** : Connexion sans mot de passe au réseau local Essensys
- **Connexion WAN** : Connexion sécurisée avec authentification et domaine DNS personnalisé
- **Scènes d'éclairage** : Contrôle rapide des scènes prédéfinies (Réveil, Soirée, Nuit, Départ)
- **Éclairage par pièce** : Contrôle des lumières directes et indirectes groupées par pièce :
  - Chambres (Grande Chambre, Petites Chambres 1, 2, 3)
  - Bureau
  - Salles de bain (SDB 1, SDB 2)
  - Toilettes (WC 1, WC 2)
  - Annexes (Annexe 1, Annexe 2)
  - Escalier
  - Autres pièces (Salon, Cuisine, Salle à Manger, Entrée, Dégagements, Dressing, Terrasse, Pièce de service)
- **Configuration** : Gestion de la connexion backend et des paramètres

## Structure du projet

```
EssensysApp/
├── essensys-iphone/
│   ├── essensys-iphone.xcodeproj/  # Projet Xcode
│   └── essensys-iphone/
│       ├── essensys_iphoneApp.swift # Point d'entrée de l'application
│       └── ContentView.swift       # Vue principale avec onglets
├── Models/
│   ├── ConnectionConfig.swift      # Modèle de configuration de connexion
│   └── LightingModels.swift        # Modèles pour l'éclairage par pièce
├── Services/
│   ├── ConnectionManager.swift      # Gestionnaire de connexion
│   └── EssensysAPI.swift            # Service API pour communiquer avec le backend
├── Views/
│   ├── HomeView.swift               # Vue d'accueil avec scènes
│   ├── LightingView.swift           # Vue de contrôle de l'éclairage par pièce
│   ├── AlarmView.swift              # Vue de contrôle de l'alarme
│   ├── ConfigurationView.swift      # Vue de configuration
│   └── SharedComponents.swift       # Composants partagés (InfoBanner, etc.)
└── Info.plist                       # Configuration de l'application
```

## Configuration

### Connexion locale (WiFi)

Par défaut, l'application se connecte en mode local via `http://mon.essensys.fr` sans authentification.

### Connexion WAN

Pour utiliser la connexion WAN :
1. Aller dans l'onglet "Configuration"
2. Sélectionner le mode "WAN"
3. Entrer l'URL du domaine DNS (ex: `https://essensys.example.com`)
4. Entrer le mot de passe WAN
5. Enregistrer la configuration

## Développement

### Prérequis

- Xcode 14.0 ou supérieur
- iOS 15.0 ou supérieur
- Swift 5.7 ou supérieur

### Installation

1. Ouvrir le projet dans Xcode
2. Configurer le Bundle Identifier dans les paramètres du projet
3. Sélectionner un simulateur ou un appareil iOS
4. Compiler et exécuter (⌘R)

### API Backend

L'application communique avec le backend Essensys via les endpoints suivants :

- `GET /api/serverinfos` - Informations du serveur
- `POST /api/admin/inject` - Injection de commandes (k, v)

## Notes importantes

- L'application fonctionne en "boucle ouverte" : les équipements ne remontent pas leur état
- Les actions sont envoyées au backend mais l'état réel des équipements n'est pas connu
- La configuration est sauvegardée localement sur l'appareil

## Licence

Voir le fichier LICENSE pour plus d'informations.
