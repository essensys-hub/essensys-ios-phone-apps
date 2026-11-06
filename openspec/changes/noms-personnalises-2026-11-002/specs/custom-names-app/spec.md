## Purpose

Faire afficher à l'app iPhone les noms personnalisés des pièces et des objets, et permettre à l'administrateur de l'armoire de les modifier, sur le serveur du mode de connexion courant.

## ADDED Requirements

### Requirement: Noms du serveur du mode courant
L'app SHALL lire les noms personnalisés auprès du cloud en mode Cloud et auprès de la gateway en mode Réseau local, et appliquer la règle de nom affiché du change de la plateforme : nom forcé de l'objet, sinon patron rempli avec le nom de sa pièce, sinon nom d'origine. Les noms d'origine MUST rester identiques aux libellés actuels de l'app.

#### Scenario: Mode Cloud
- **WHEN** l'utilisateur est connecté au cloud
- **THEN** l'app affiche les noms enregistrés dans le cloud pour son armoire

#### Scenario: Mode Réseau local
- **WHEN** l'utilisateur est connecté à la gateway
- **THEN** l'app affiche les noms enregistrés dans la gateway

#### Scenario: Aucun nom personnalisé
- **WHEN** aucun nom n'a été saisi
- **THEN** chaque objet garde son libellé actuel, par exemple « Volet Petite Chambre 3 »

#### Scenario: Propagation d'une pièce
- **GIVEN** la pièce « Petite Chambre 3 » renommée « Chambre de Nico »
- **WHEN** l'app affiche ses objets sans nom forcé
- **THEN** elle montre « Chambre de Nico », « Chambre de Nico (chevet) » et « Volet Chambre de Nico »

### Requirement: Rafraîchissement
L'app SHALL rafraîchir les noms à la connexion et au démarrage, au retour au premier plan et toutes les 30 secondes tant qu'un écran est visible. Un rafraîchissement sans changement MUST ne transférer presque rien. Un changement fait sur un autre environnement MUST apparaître en moins d'une minute sans action de l'utilisateur. Plusieurs rafraîchissements demandés en même temps MUST se réduire à un seul appel.

#### Scenario: Retour au premier plan
- **GIVEN** une lumière renommée depuis le portail pendant que l'app était en arrière-plan
- **WHEN** l'utilisateur rouvre l'app
- **THEN** le nouveau nom s'affiche

#### Scenario: Écran visible
- **WHEN** un nom change sur un autre environnement pendant que l'écran est ouvert
- **THEN** l'app montre le nouveau nom en moins d'une minute

#### Scenario: Rien de nouveau
- **WHEN** le serveur répond que rien n'a changé
- **THEN** l'app garde ses noms et n'affiche aucun indicateur

#### Scenario: Demandes simultanées
- **WHEN** le retour au premier plan et le minuteur demandent un rafraîchissement ensemble
- **THEN** un seul appel part au serveur

### Requirement: Cache persistant
L'app SHALL garder les derniers noms reçus dans ses préférences, et non dans le trousseau, puisque ce ne sont pas des secrets. Elle MUST les afficher dès le démarrage, avant la réponse du serveur, et ne MUST PAS les mélanger entre deux installations, ni entre deux modes de connexion. Se déconnecter MUST effacer ce cache.

#### Scenario: Démarrage hors ligne
- **GIVEN** des noms reçus lors d'une session précédente
- **WHEN** l'utilisateur ouvre l'app sans réseau
- **THEN** l'app affiche ces noms

#### Scenario: Changement de mode
- **WHEN** l'utilisateur passe du mode Cloud au mode Réseau local
- **THEN** l'app n'affiche pas les noms de l'autre mode avant d'avoir reçu ceux du nouveau

#### Scenario: Déconnexion
- **WHEN** l'utilisateur se déconnecte
- **THEN** le cache des noms est effacé

### Requirement: Écran « Noms » réservé aux administrateurs
Les Réglages SHALL proposer un écran « Noms » quand le serveur indique que l'utilisateur peut renommer. L'écran SHALL lister les pièces et les objets par catégorie (pièces, lumières, volets, chauffage, prises de sécurité, chauffe-eau et arrosage, scénarios), chaque ligne montrant le nom affiché et son origine : personnalisé, hérité de la pièce ou d'origine. Un utilisateur qui ne peut pas renommer MUST NE voir ni cet écran ni aucun contrôle de renommage.

#### Scenario: Administrateur
- **WHEN** l'administrateur ouvre les Réglages
- **THEN** il voit « Noms » et, dans l'écran, toutes les catégories avec l'origine de chaque nom

#### Scenario: Utilisateur ordinaire
- **WHEN** un utilisateur sans droit de renommer ouvre les Réglages
- **THEN** il ne voit pas « Noms » et ne trouve aucun contrôle de renommage

### Requirement: Modification et rétablissement
L'administrateur SHALL pouvoir enregistrer un nom, limité à 40 caractères avec un compteur de caractères restants, et le rétablir. L'app MUST appliquer la règle de validité du change de la plateforme avant l'envoi et reprendre le nom renvoyé par le serveur sans attendre le prochain rafraîchissement. Un refus du serveur MUST laisser le texte saisi et afficher son message. L'app MUST NOT enregistrer de nom hors ligne : sans connexion, l'enregistrement est refusé avec un message clair.

#### Scenario: Renommer
- **WHEN** l'administrateur enregistre « Chambre de Nico » pour la pièce « Petite Chambre 3 »
- **THEN** l'app affiche aussitôt ce nom et la ligne passe à « personnalisé »

#### Scenario: Trop long
- **WHEN** l'administrateur dépasse 40 caractères
- **THEN** l'app empêche l'enregistrement et indique la limite

#### Scenario: Refus du serveur
- **WHEN** le serveur refuse l'écriture
- **THEN** l'app affiche son message et garde le texte saisi

#### Scenario: Rétablir
- **WHEN** l'administrateur rétablit le nom d'un volet forcé
- **THEN** il retrouve le nom hérité de sa pièce, ou son nom d'origine

#### Scenario: Hors ligne
- **WHEN** l'administrateur enregistre un nom sans connexion
- **THEN** l'app refuse avec un message clair et ne garde aucun nom en attente

### Requirement: Aperçu avant de renommer une pièce
Avant d'enregistrer le nom d'une pièce, l'app SHALL montrer les objets dont le nom affiché va changer, et ceux au nom forcé qui ne changeront pas.

#### Scenario: Aperçu
- **WHEN** l'administrateur saisit un nouveau nom pour « Petite Chambre 3 »
- **THEN** l'app liste la lumière de chevet et le volet qui prendront ce nom, et signale un objet au nom forcé qui ne changera pas

### Requirement: Noms affichés partout
L'app SHALL afficher le nom choisi partout où un objet apparaît : éclairage, volets, chauffage, prises de sécurité, chauffe-eau, arrosage, scénarios et éditeur de scénarios, messages de confirmation, état et dernière action. Aucun libellé d'origine ne MUST rester affiché à la place d'un nom choisi.

#### Scenario: Éclairage
- **GIVEN** la pièce « Petite Chambre 3 » renommée « Chambre de Nico »
- **WHEN** l'utilisateur ouvre l'éclairage
- **THEN** les lumières de cette pièce s'affichent avec ce nom

#### Scenario: Confirmation
- **WHEN** l'utilisateur coupe les prises de sécurité renommées « Prises du garage »
- **THEN** la confirmation emploie « Prises du garage »

### Requirement: Noms d'origine en secours
Quand le serveur ne fournit pas les noms (route absente, erreur, hors ligne), l'app SHALL afficher les derniers noms connus, ou à défaut les noms d'origine, sans erreur visible et sans bloquer les commandes.

#### Scenario: Serveur ancien
- **WHEN** l'app interroge un serveur qui répond 404 aux noms
- **THEN** elle affiche les noms d'origine et toutes les commandes restent utilisables

#### Scenario: Erreur passagère
- **WHEN** le serveur répond une erreur après des noms déjà reçus
- **THEN** l'app garde les noms reçus et réessaie au prochain rafraîchissement

### Requirement: Confidentialité
Les noms MUST NOT apparaître dans le journal de l'app ni dans le bundle Support.

#### Scenario: Bundle Support
- **WHEN** l'utilisateur génère le bundle Support avec des noms personnalisés
- **THEN** le zip ne contient aucun nom personnalisé

### Requirement: Aucun effet sur l'armoire
Lire ou enregistrer un nom MUST NOT modifier d'indice ni de masque de la table d'échange, ni envoyer de commande à l'armoire.

#### Scenario: Renommer
- **WHEN** l'administrateur renomme un volet
- **THEN** aucune commande n'est envoyée et la table d'indices est inchangée
