//
//  ShutterNamesUITests.swift
//  Noms personnalisés des volets et stores (spec shutter-names-clients) sur simulateur, contre le backend simulé
//  embarqué : aucune armoire réelle. Feature noms-volets-2026-11-005, tâches 6.2 et 6.3 (NR-ios-26).
//

import XCTest

final class ShutterNamesUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launch(_ env: [String: String] = [:]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment = ["UITEST_BACKEND": "1", "UITEST_TOKEN": "1", "UITEST_EXCHANGE": "566=90,585=200"].merging(env) { $1 }
        app.launch()
        XCTAssertTrue(app.buttons["quick-2"].waitForExistence(timeout: 10))
        return app
    }

    private func log(_ app: XCUIApplication, _ id: String) -> [String] {
        let value = app.staticTexts[id].value as? String ?? ""
        return value.isEmpty ? [] : value.components(separatedBy: "|")
    }

    private func waitFor(_ timeout: TimeInterval = 5, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline { if condition() { return true }; usleep(200_000) }
        return condition()
    }

    private func tap(_ app: XCUIApplication, _ element: XCUIElement) {
        XCTAssertTrue(element.waitForExistence(timeout: 5), "\(element)")
        var tries = 0
        while !element.isHittable && tries < 10 { app.swipeUp(); tries += 1 }
        element.tap()
    }

    private func openShutters(_ env: [String: String] = [:]) -> XCUIApplication {
        let app = launch(env)
        app.tabBars.buttons["Volets"].tap()
        XCTAssertTrue(app.buttons["shutter-volet1salon-primary"].waitForExistence(timeout: 5))
        return app
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func rename(_ app: XCUIApplication, _ id: String, to text: String, save: Bool = true) {
        tap(app, app.buttons["shutter-\(id)-name-toggle"])
        let field = app.textFields["shutter-\(id)-name-field"]
        tap(app, field)
        field.typeText(text)
        if save { tap(app, app.buttons["shutter-\(id)-name-save"]) }
    }

    @MainActor func test_nom_personnalise_dans_les_listes_la_confirmation_et_le_temps_de_course() {
        let app = openShutters(["UITEST_SHUTTER_NAMES": "volet1salon=Volet baie vitrée;store=Store terrasse;voletstore=Store \"nord\" <b>"])
        XCTAssertTrue(app.staticTexts["Volet baie vitrée"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Volet 1 Salon"].exists)
        XCTAssertTrue(app.staticTexts["Volet 2 Salon"].exists) // sans nom personnalisé : nom d'origine
        attach(app, "26-shutter-names-list")
        // Confirmation / dernière action avec le nom affiché.
        tap(app, app.buttons["shutter-volet1salon-primary"])
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'Volet baie vitrée : commande'")).firstMatch.waitForExistence(timeout: 5))
        // Carte « Temps de course » : le nom affiché, et non le libellé d'origine.
        let travel = app.staticTexts["time-name-volet1salon"]
        tap(app, travel)
        XCTAssertEqual(travel.label, "Volet baie vitrée")
        XCTAssertEqual(app.staticTexts["time-name-store"].label, "Store terrasse")
        XCTAssertEqual(app.staticTexts["time-name-voletstore"].label, #"Store "nord" <b>"#) // texte brut
        XCTAssertEqual(app.staticTexts["time-current-volet1salon"].label, "Actuel : 90 s") // temps de course inchangé
        attach(app, "27-shutter-names-travel-time")
    }

    @MainActor func test_lecture_impossible_affiche_les_noms_d_origine() {
        let app = openShutters(["UITEST_NAMES_READ_FAIL": "1", "UITEST_SHUTTER_NAMES": "volet1salon=Volet baie vitrée"])
        usleep(800_000)
        XCTAssertTrue(app.staticTexts["Volet 1 Salon"].exists)
        XCTAssertFalse(app.staticTexts["Volet baie vitrée"].exists)
        XCTAssertFalse(app.alerts.firstMatch.exists) // pas de message bloquant
    }

    @MainActor func test_l_administrateur_renomme_puis_revient_au_nom_d_origine() {
        let app = openShutters()
        rename(app, "volet1salon", to: "Volet baie vitrée")
        XCTAssertTrue(waitFor { !self.log(app, "uitest-mutations").isEmpty })
        XCTAssertEqual(log(app, "uitest-mutations"), [#"PUT /api/portal/admin/shutters/names/volet1salon {"name":"Volet baie vitrée"}"#])
        XCTAssertTrue(waitFor { app.buttons["shutter-volet1salon-name-toggle"].label.contains("Volet baie vitrée") })
        XCTAssertTrue(app.staticTexts["Volet baie vitrée"].exists) // sans rechargement
        attach(app, "28-shutter-name-saved")
        tap(app, app.buttons["shutter-volet1salon-name-reset"])
        XCTAssertTrue(waitFor { self.log(app, "uitest-mutations").count == 2 })
        XCTAssertEqual(log(app, "uitest-mutations").last, #"PUT /api/portal/admin/shutters/names/volet1salon {"name":null}"#)
        XCTAssertTrue(waitFor { app.buttons["shutter-volet1salon-name-toggle"].label.contains("Volet 1 Salon") })
        // NR-ios-26 : aucun ordre vers l'armoire.
        XCTAssertTrue(log(app, "uitest-injections").isEmpty)
    }

    @MainActor func test_nom_trop_long_refuse_sans_requete() {
        let app = openShutters()
        rename(app, "volet1salon", to: String(repeating: "a", count: 41))
        XCTAssertTrue(app.staticTexts["shutter-volet1salon-name-error"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["shutter-volet1salon-name-error"].label.contains("1 à 40"))
        usleep(500_000)
        XCTAssertTrue(log(app, "uitest-mutations").isEmpty)
        XCTAssertTrue(log(app, "uitest-injections").isEmpty)
    }

    @MainActor func test_nom_de_40_caracteres_reste_lisible_dans_le_temps_de_course() {
        let long = "Volet très long de la baie vitrée sud"  // 37 + complété ci-dessous
        let name = String((long + "xxxxxxxxxx").prefix(40))
        let app = openShutters(["UITEST_SHUTTER_NAMES": "volet1salon=\(name)"])
        let travel = app.staticTexts["time-name-volet1salon"]
        tap(app, travel)
        XCTAssertEqual(travel.label, name)
        XCTAssertTrue(app.buttons["time-save-volet1salon"].isHittable) // le bouton n'est pas masqué
        XCTAssertTrue(app.textFields["time-input-volet1salon"].isHittable)
        attach(app, "29-shutter-name-40-travel-time")
    }

    @MainActor func test_erreur_503_affiche_un_message_clair() {
        let app = openShutters(["UITEST_NAMES_WRITE": "503"])
        rename(app, "volet1salon", to: "Volet baie vitrée")
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'stockage indisponible'")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Volet 1 Salon"].exists) // aucun changement
    }

    @MainActor func test_erreur_403_affiche_un_message_clair() {
        let app = openShutters(["UITEST_NAMES_WRITE": "403"])
        rename(app, "volet1salon", to: "Volet baie vitrée")
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Réservé à l'administrateur")).firstMatch.waitForExistence(timeout: 5))
    }

    @MainActor func test_masque_pour_un_utilisateur_simple_mais_noms_affiches() {
        let app = openShutters(["UITEST_ROLE": "guest_local", "UITEST_SHUTTER_NAMES": "volet1salon=Volet baie vitrée"])
        XCTAssertTrue(app.staticTexts["Volet baie vitrée"].waitForExistence(timeout: 5))
        usleep(500_000)
        XCTAssertFalse(app.buttons["shutter-volet1salon-name-toggle"].exists)
    }

    @MainActor func test_mode_local_ecrit_sur_la_route_locale() {
        let app = openShutters(["UITEST_MODE": "lan", "UITEST_ROLE": "lan_admin"])
        rename(app, "store", to: "Store terrasse")
        XCTAssertTrue(waitFor { !self.log(app, "uitest-mutations").isEmpty })
        XCTAssertEqual(log(app, "uitest-mutations"), [#"PUT /api/admin/shutters/names/store {"name":"Store terrasse"}"#])
    }

    @MainActor func test_mode_local_sans_droit_administrateur_ne_propose_pas_le_champ() {
        let app = openShutters(["UITEST_MODE": "lan", "UITEST_ROLE": "lan_user"])
        usleep(800_000)
        XCTAssertFalse(app.buttons["shutter-volet1salon-name-toggle"].exists)
    }
}
