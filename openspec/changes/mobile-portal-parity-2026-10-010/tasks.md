## 1. Socle data et tests (#11)

- [ ] 1.1 Étendre `IndexTable` (zones de chauffage, modes immédiats, chauffe-eau 353, arrosage 363, formule de bloc des scénarios) ; vérifier par `IndexTableTests` et les tests `NR-ios-10` (indices des zones) et `NR-ios-11` (chauffe-eau et arrosage, aucun indice 400–402 ou 500–504)
- [ ] 1.2 Ajouter à `APIClient` la lecture `exchange` (cloud avec `stale`/`source`, LAN) et l'envoi par lots (cloud `inject/batch`, LAN `inject` en tableau) avec découpage à 30 ; vérifier par des tests `MockBackend` (découpage 40 → 30 + 10 = `NR-ios-12`)
- [ ] 1.3 Étendre `NoArmoireGuard` aux routes `inject/batch`, `web/actions`, `scenarios/*` et `heating/sync` ; vérifier par un test qui échoue sur chaque route vers `mon.essensys.fr`
- [ ] 1.4 Étendre `UITestBackend` et les fixtures JSON (copiées du dépôt Android) ; vérifier que les tests UI existants passent toujours

## 2. Chauffage (#12)

- [ ] 2.1 `ScheduleCodec` (décodage, encodage, diff, copie d'un jour) ; vérifier par `NR-ios-13` (lundi 6 h Confort + 7 h Éco en Zone Jour → `k=16, v="33"`) et des tests de diff
- [ ] 2.2 `HeatingRepository` cloud et LAN : lecture, envoi séquentiel annulable (`AsyncStream` de progression), synchronisation LAN (`heating/sync`, statut toutes les 3 s, 90 s, 409 busy) ; vérifier par des tests unitaires dont l'échec du second lot et l'annulation
- [ ] 2.3 Écran Chauffage : zones, grille 7 × 24 jour par jour, palette, « appliquer à toute la semaine », Annuler, Enregistrer avec compteur, progression, avertissement `stale` ; vérifier par un test UI et sur iPhone SE
- [ ] 2.4 Mode immédiat par zone (Anticipé absent des salles de bain) ; vérifier par `NR-ios-14` (`k=351, v="17"`) et un test UI

## 3. Scénarios (#13)

- [ ] 3.1 `ScenarioRepository` cloud et LAN : liste, définition, bitmasks, lancement, restauration, enregistrement, en-tête dry-run partout ; vérifier par des tests unitaires (dont dry-run en LAN)
- [ ] 3.2 Transposition des masques dans le bloc du scénario et refus local des indices hors bloc ; vérifier par `NR-ios-15` (indice méta 605 dans le scénario 4 → 728)
- [ ] 3.3 Écran Scénarios : liste 2 à 8, dernier lancé, Lancer, Réglages d'usine avec confirmation (2 à 6), éditeur à cases à cocher ; vérifier par des tests UI (annuler la confirmation n'envoie rien)

## 4. Chauffe-eau, arrosage et alarme (#14)

- [ ] 4.1 Écrans Chauffe-eau et Arrosage avec mode actuel lu dans `exchange` ou « Mode actuel inconnu » ; vérifier par des tests UI (`k=353, v="1"`, `k=363, v="30"`)
- [ ] 4.2 Écran Alarme cloud (`SecureField` numérique, confirmation de l'arrêt, rappel de boucle ouverte) et message « cloud seulement » en LAN ; vérifier par des tests UI en cloud et en LAN
- [ ] 4.3 Protection du code : `@State` seulement, effacement après envoi et hors `.active`, jamais journalisé, `validated_params` non affiché ; vérifier par `NR-ios-16` (code absent des journaux et du stockage)
- [ ] 4.4 Masquer l'écran Alarme en Release derrière un drapeau tant que la mise en service n'est pas validée par un humain sur le banc BP ; vérifier que la build Release n'affiche pas la tuile Alarme

## 5. Accueil et navigation (#15)

- [ ] 5.1 `TabView` à 5 onglets (Accueil, Éclairage, Volets, Chauffage, Réglages) et `NavigationStack` depuis l'accueil ; vérifier par un test UI de navigation
- [ ] 5.2 Accueil : scénarios rapides, tuiles de toutes les fonctions, suppression de « Bientôt disponible », commandes désactivées hors ligne ; vérifier par des tests UI (hors ligne : « Je sors » désactivé, planning lisible)
- [ ] 5.3 Réglages : compte et armoire lus dans `/api/portal/session` en cloud ; vérifier par un test UI

## 6. Qualité, CI et livraison (#16)

- [ ] 6.1 CI iOS verte sur la PR (build, unitaires, UI, NR) et rapport NR consolidé avec `NR-ios-10` à `NR-ios-16` ; vérifier sur le run GitHub
- [ ] 6.2 `/checkup essensys-ios-phone-apps` vert, captures clair et sombre des nouveaux écrans postées sur #35
- [ ] 6.3 README (fonctionnalités, captures) mis à jour et `MARKETING_VERSION` 2.1.0 ; vérifier le rendu du README
- [ ] 6.4 Build 2.1.0 envoyée sur TestFlight et distribuée au groupe famille ; vérifier dans App Store Connect
