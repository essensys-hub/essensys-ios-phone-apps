# Documentation des Indices Essensys

## Vue d'ensemble

L'application iOS utilise les indices de la table d'échange Essensys pour contrôler les équipements. Les indices 605-622 sont utilisés pour les lumières et les volets.

## Indices utilisés dans l'application

### Éclairage

Les indices suivants sont utilisés dans l'application (à ajuster selon votre configuration) :

- **610** : Éteindre toutes les lumières (valeur: 4)
- **616** : Allumer certaines zones (valeur: 4)
- **617** : Salon indirect 1 (valeur: 4)
- **618** : Salon indirect 2 (valeur: 4)
- **619** : Couloir (valeur: 4)
- **620** : Salle de bain 1 - Éclairage miroir (valeur: 4)
- **621** : Grande chambre 1 (valeur: 4)
- **622** : Petite chambre 1 (valeur: 4)

### Notes importantes

⚠️ **Les indices utilisés dans le code sont des exemples** et doivent être ajustés selon votre configuration Essensys réelle.

Pour trouver les bons indices pour votre installation :

1. Consulter la documentation de votre installation Essensys
2. Utiliser l'interface web Essensys pour identifier les indices utilisés
3. Vérifier les fichiers de configuration du backend Essensys

## Format des commandes

Les commandes sont envoyées au backend via l'endpoint `/api/admin/inject` avec le format suivant :

```json
{
  "k": 616,
  "v": "4"
}
```

Où :
- `k` : L'indice de la table d'échange (605-622 pour les lumières)
- `v` : La valeur à envoyer (généralement "4" pour les lumières, mais peut varier)

## Modification des indices

Pour modifier les indices utilisés dans l'application :

1. Ouvrir `EssensysApp/Views/HomeView.swift` pour les scènes d'éclairage
2. Ouvrir `EssensysApp/Views/LightingView.swift` pour les zones individuelles
3. Modifier les valeurs dans les structures `LightingScene` et `LightingZone`

Exemple :

```swift
LightingZone(
    name: "Salon",
    onIndex: 617,    // Indice pour allumer
    offIndex: 610,   // Indice pour éteindre
    value: "4"      // Valeur à envoyer
)
```


