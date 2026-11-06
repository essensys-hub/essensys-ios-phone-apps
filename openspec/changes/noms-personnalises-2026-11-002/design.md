## Context

Voir `proposal.md` (Why) et le change `noms-personnalises-2026-11-002` d'`essensys-memory` (règle de nom affiché, validation, droits, API, synchronisation : décisions 1, 2, 3, 5, 6, 9 et 10). État actuel de l'app :

- `IndexTable` est le référentiel unique des lumières, volets et zones de chauffage ; les libellés y sont en dur, identiques à ceux de l'Android et des portails. Ses clés (`ptchamb3`, `volet1ptchamb`, `sdb1`…) sont stables.
- Les secrets sont dans le Keychain (`KeychainPersistence`) ; les préférences non sensibles sont dans `UserDefaults`.
- `APIClient` fait les appels, avec une garde « pas d'armoire » en test ; l'app change de serveur selon le mode (cloud ou réseau local).
- Les Réglages sont dans `MainScreens`, le bundle Support dans `SupportBundle`.

## Goals / Non-Goals

**Goals:**
- Afficher les noms du serveur du mode courant, identiques à ceux des autres clients.
- Permettre à l'administrateur de renommer depuis l'app.

**Non-Goals:**
- Écrire hors ligne ou mettre des modifications en file (la gateway le fait, pas l'app).
- Raccourci de renommage depuis l'écran d'un objet.
- Noms dans les notifications ou l'assistant MCP.

## Decisions

**1. Un référentiel de noms qui possède l'état.** Un `NamesRepository` détient `{ révision, entrées, peutRenommer }` et le cache. Il est un **acteur** : les rafraîchissements demandés en même temps (retour au premier plan, minuteur, après une écriture) se réduisent à un seul appel en cours. Il expose `displayName(kind, key)` qui applique la règle (nom forcé, patron rempli avec la pièce, nom d'origine). L'interface le lit par un modèle observable, sans appeler le réseau elle-même. *Alternative écartée :* un cache de noms dans `IndexTable` (mélange des données figées et des données vivantes).

**2. Catalogue copié, vecteurs communs.** `IndexTable` garde ses indices et masques, **inchangés** (verrouillés par `NR-ios-5` et `NR-ios-6`). Le catalogue des noms (types, clés, pièces, patrons, noms d'origine) est une copie du `catalog.json` canonique de la plateforme, en ressource de l'app ; un test compare les libellés qu'il reconstruit à ceux d'`IndexTable` et le script de parité de la feature compare les copies entre dépôts. Les vecteurs `names_vectors.json` sont joués en Swift Testing.

**3. Cache dans `UserDefaults`.** Les noms ne sont pas des secrets : ils vont dans les préférences, par installation et par mode, sous une clé qui porte le mode. La déconnexion supprime la clé. Au démarrage, le cache s'affiche tout de suite et le rafraîchissement part en parallèle. *Alternative écartée :* le Keychain (inutile, et il survit à la désinstallation, ce qui laisserait des noms personnels).

**4. ETag et révision.** Chaque lecture envoie `If-None-Match` avec la dernière révision. Une réponse 304 ne change rien. Un 404 (serveur ancien) est mémorisé le temps de la session pour ne pas réinterroger chaque 30 s, sauf au changement de mode ou à la reconnexion. Une erreur réseau garde les noms et réessaie au prochain cycle.

**5. Rafraîchissement.** À la connexion et au démarrage ; au retour au premier plan (phase de scène active) ; toutes les 30 s tant qu'une scène est visible, par une tâche annulée quand l'app passe en arrière-plan. Après une écriture, l'app reprend l'entrée et la révision renvoyées.

**6. Écran « Noms ».** Affiché seulement si le serveur répond `can_rename`. Catégories repliables ; une ligne par pièce ou objet avec le nom affiché et une puce d'origine ; une feuille de modification avec champ limité à 40 caractères et compteur, boutons « Enregistrer » et « Rétablir » ; pour une pièce, un aperçu des objets qui changent. L'écriture est refusée sans connexion, avec un message. Les codes d'erreur `name_invalid`, `names_forbidden` et `name_unknown_object` ont chacun un message.

**7. Remplacement des libellés.** Les écrans qui affichent un objet appellent `displayName` à la place des libellés d'`IndexTable` : éclairage, volets, chauffage, prises de sécurité, chauffe-eau, arrosage, scénarios et éditeur, confirmations, état et dernière action. Le journal et le bundle Support ne reçoivent jamais de nom.

## Risks / Trade-offs

- **Le propriétaire n'a peut-être pas le rôle d'administrateur** → l'app suit `can_rename` du serveur ; la plateforme vérifie les rôles en production.
- **Quatre implémentations de la règle de nom** (Go, TypeScript, Kotlin, Swift) → vecteurs communs et parité du catalogue.
- **Un serveur ancien répond 404 aux noms** → noms d'origine, aucune erreur ; mémorisé pour la session.
- **Coût réseau** : un appel court toutes les 30 s par écran visible → 304 sans corps ; arrêt en arrière-plan.
- **Clés inconnues reçues d'un serveur plus récent** → ignorées sans erreur.

## Migration Plan

1. Le cloud, la gateway et les portails sortent d'abord ; l'app actuelle ne les appelle pas.
2. App 2.5.0 : sans nom enregistré, rien ne change à l'écran ; l'écran « Noms » n'apparaît que pour un administrateur.
3. Version 2.5.0 passée à l'archive (`MARKETING_VERSION`), build TestFlight, puis tag `ios-v2.5.0`.
4. Retour arrière : le serveur désactive la route ; l'app retombe sur les noms d'origine sans migration.
