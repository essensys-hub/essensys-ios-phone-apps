# Liste Complète des Lampes dans l'Application

## Résumé

- **Total de pièces** : 23
- **Total de lumières principales (directes)** : 21
- **Total de lumières indirectes** : 12

## Liste par Catégorie

### Chambres (4 pièces)

1. **Grande Chambre**
   - Directe : Grande Chambre
   - Indirectes : Chevet 1, Chevet 2

2. **Petite Chambre 1**
   - Directe : Petite Chambre 1
   - Indirectes : Chevet 1, Chevet 2

3. **Petite Chambre 2**
   - Directe : Petite Chambre 2
   - Indirecte : Chevet

4. **Petite Chambre 3**
   - Directe : Petite Chambre 3
   - Indirecte : Chevet

### Bureau (1 pièce)

5. **Bureau**
   - Directe : Bureau

### Salles de bain (2 pièces)

6. **Salle de Bain 1**
   - Directe : Salle de Bain 1
   - Indirecte : Miroir

7. **Salle de Bain 2**
   - Directe : Salle de Bain 2
   - Indirecte : Miroir

### Toilettes (2 pièces)

8. **WC 1**
   - Directe : WC 1

9. **WC 2**
   - Directe : WC 2

### Annexes (2 pièces)

10. **Annexe 1**
    - Directe : Annexe 1

11. **Annexe 2**
    - Directe : Annexe 2

### Escalier (1 pièce)

12. **Escalier**
    - Directe : Escalier

### Autres pièces (11 pièces)

13. **Salon**
    - Directe : Salon
    - Indirectes : Indirect 1, Indirect 2

14. **Salle à Manger**
    - Directe : Salle à Manger

15. **Cuisine**
    - Directe : Cuisine
    - Indirecte : Plans de travail

16. **Entrée**
    - Directe : Entrée

17. **Dégagement 1**
    - Directe : Dégagement 1

18. **Dégagement 2**
    - Directe : Dégagement 2

19. **Dressing**
    - Directe : Dressing
    - Indirecte : Placards

20. **Pièce de service**
    - Directe : Pièce de service

21. **Terrasse**
    - Directe : Terrasse

## Vérification

Si vous ne voyez pas toutes ces pièces dans l'application :

1. **Vérifier que le fichier `LightingModels.swift` est dans le projet Xcode**
   - Le fichier doit être dans le groupe `Models`
   - Il doit être ajouté au target `essensys-iphone`

2. **Nettoyer et recompiler**
   - `Product > Clean Build Folder` (⇧⌘K)
   - `Product > Build` (⌘B)
   - `Product > Run` (⌘R)

3. **Vérifier les erreurs de compilation**
   - Ouvrir le panneau de rapport (⌘9)
   - Vérifier qu'il n'y a pas d'erreurs liées à `LightingModels` ou `LightingView`

4. **Les cartes sont maintenant ouvertes par défaut**
   - Toutes les lampes devraient être visibles directement
   - Vous pouvez les replier en cliquant sur la flèche


