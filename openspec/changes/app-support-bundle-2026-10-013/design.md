## Context

Motivation : voir `proposal.md`. État des lieux (2026-10-30) : l'appli ne tient aucun journal exploitable par le support ; la version n'est visible que dans Réglages (corrigé à part par essensys-hub/essensys-ios-phone-apps#27) ; toutes les requêtes passent par `APIClient` (`get` et `send`, deux `URLSession` éphémères, cloud et LAN épinglé) ; le portail cloud expose `GET /api/portal/health` sans authentification, la gateway `GET /health`.

**Décisions communes aux 2 dépôts** (le détail propre à chaque dépôt suit) :
- **C1 — Même diagnostic** : mêmes tests, mêmes libellés, mêmes statuts (`ok`, `warning`, `error`, `n/a`) et même schéma de `diagnostics.json` sur Android et iPhone. Le champ `platform` les distingue.
- **C2 — Temps de réponse plutôt que ping** : l'iPhone n'autorise pas l'ICMP. Les deux apps mesurent 5 requêtes `GET /api/portal/health` (HTTPS), ce qui teste aussi DNS, TLS et le reverse proxy.
- **C3 — Lecture seule** : les diagnostics n'appellent que `health`, `session`, `gateway/status`, `history/latest` (cloud) et `health` (LAN). Jamais d'injection.
- **C4 — Liste blanche** : le bundle est construit à partir de champs explicitement choisis, jamais en sérialisant un objet de session ou une requête entière. Le journal n'enregistre jamais de corps ni d'en-tête.
- **C5 — Envoi par l'appli email de l'utilisateur** : pas de serveur de collecte. L'utilisateur voit et peut modifier le message. L'adresse support est une constante de build, changeable sans toucher au code des écrans.

## Goals / Non-Goals

**Goals :** voir les specs de ce change.

**Non-Goals :** envoi automatique ou en arrière-plan ; collecte côté serveur ; diagnostic de l'armoire elle-même (bus I2C, BA) ; rapports de crash (MetricKit, à traiter à part si besoin).

## Decisions

### D1 — Journal : `AppLog` en anneau, persisté
`Data/Support/AppLog.swift` : classe `Sendable` protégée par un verrou (appelable de façon synchrone depuis `APIClient`), avec un tampon de 500 entrées, écrit en JSON lignes dans `Application Support/support/journal.jsonl` (à la mise en arrière-plan et toutes les 50 entrées). `APIClient.get`/`send` notent méthode, chemin (sans paramètres), code, durée et type d'`APIError`, **après** avoir construit la requête mais sans jamais lire ses en-têtes ni son corps. Les modèles (`SessionModel`, `ControlModel`) notent les événements (connexion, état en ligne, mode test).
*Alternative écartée* : `os.Logger`, dont la lecture par `OSLogStore` depuis l'appli est limitée et peu fiable selon les versions d'iOS.

### D2 — Diagnostics : `SupportDiagnostics`
Un `TaskGroup` avec un délai par test (8 s ; 25 s au total). Réseau par `NWPathMonitor` (Wi-Fi, cellulaire, autre/VPN), DNS par `getaddrinfo`, horloge par l'en-tête `Date` de `health`. Les requêtes passent par des `URLSession` dédiées (délai de 3 s, même backend simulé en test, épinglage LAN en production), qui n'écrivent pas dans le journal. L'état « en ligne » est lu dans `SessionModel` avec la règle appliquée (voir armoire-online-sans-gateway-2026-10-012).

### D3 — Bundle : `SupportBundle`
Les trois fichiers sont écrits dans un dossier temporaire, puis zippés sans dépendance par `NSFileCoordinator.coordinate(readingItemAt:options: .forUploading)`, qui produit un `.zip` du dossier. Copie dans `tmp/support/` sous le nom de la spec ; les anciens bundles sont supprimés.
*Alternative écartée* : une librairie zip (ZIPFoundation), dépendance inutile pour trois petits fichiers.

### D4 — Email : `MFMailComposeViewController`
Si `MFMailComposeViewController.canSendMail()` : destinataire, objet, corps (résumé) et pièce jointe `application/zip`. Sinon : `ShareLink`/`UIActivityViewController` avec le zip et le résumé. Adresse dans `Info.plist` (`EssensysSupportEmail` = `support_essensys@rhinosys.fr`).

### D5 — Écran Support
Écran poussé depuis Réglages et depuis l'écran de connexion : liste des tests avec leur statut au fil de l'eau, puis « Envoyer au support » et « Relancer ». Accessible en release.

### D6 — Tests
Swift Testing (`SupportTests` : `AppLog`, assemblage du bundle relu par un lecteur zip minimal, statuts), tests avec `URLProtocol` simulé (health OK, délai, 401, LAN), `NR-ios-20` (non-fuite des secrets), XCUITest `SupportUITests` sur `UITestBackend` (écran, résumé, aucun appel `inject` ; la feuille Mail n'étant pas pilotable en simulateur, l'envoi est relevé en mode UI-test par la sonde `uitest-support-mail`, et `SupportMail.parameters` est testé à part).

## Risks / Trade-offs

- [Fuite d'un secret dans le journal ou le bundle] → C4 (liste blanche), journal alimenté par méthode et chemin seulement, `NR-ios-20`.
- [Pas de compte Mail sur l'iPhone (Gmail, Outlook seuls)] → repli sur la feuille de partage, qui propose Gmail et Outlook.
- [`.forUploading` change de comportement selon la version d'iOS] → test unitaire qui décompresse le zip produit et vérifie les trois fichiers.
- [Les tests durent trop en 4G faible] → délais par test et total plafonné à 25 s ; résultat partiel envoyé quand même.
- [Données personnelles (email du compte, numéro de série de l'armoire)] → nécessaires au support, envoyées par l'utilisateur depuis sa propre boîte ; décrites dans `PRIVACY.md` et dans le résumé affiché avant envoi.

## Migration Plan

1. Une PR sur essensys-ios-phone-apps avec `Feature: app-support-bundle-2026-10-013` et `Refs`/`Closes` vers les sub-issues.
2. Vérification réelle par un humain (Wi-Fi puis 4G, Mail puis Gmail via le partage), puis build TestFlight et release `ios-v2.3.0`.
3. Rollback : masquer le bouton Support ; le journal reste local et sans effet sur le reste de l'appli.
