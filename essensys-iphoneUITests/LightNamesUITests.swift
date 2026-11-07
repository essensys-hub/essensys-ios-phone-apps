//
//  LightNamesUITests.swift
//  Noms personnalisés des lumières (spec light-names-clients) sur simulateur, contre le backend simulé
//  embarqué : aucune armoire réelle. Feature noms-lumieres-2026-11-004, tâches 8.2 et 8.3 (NR-ios-25).
//

import XCTest

final class LightNamesUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launch(_ env: [String: String] = [:]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment = ["UITEST_BACKEND": "1", "UITEST_TOKEN": "1", "UITEST_EXCHANGE": "521=15,555=30"].merging(env) { $1 }
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
        while !element.isHittable && tries < 8 { app.swipeUp(); tries += 1 }
        element.tap()
    }

    private func openLighting(_ env: [String: String] = [:]) -> XCUIApplication {
        let app = launch(env)
        app.tabBars.buttons["Éclairage"].tap()
        XCTAssertTrue(app.buttons["light-dressing-primary"].waitForExistence(timeout: 5))
        return app
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Ouvre le champ de nom d'une lumière, le remplit, puis appuie sur « Enregistrer ».
    private func rename(_ app: XCUIApplication, _ id: String, to text: String, save: Bool = true) {
        tap(app, app.buttons["light-\(id)-name-toggle"])
        let field = app.textFields["light-\(id)-name-field"]
        tap(app, field)
        field.typeText(text)
        if save { tap(app, app.buttons["light-\(id)-name-save"]) }
    }

    @MainActor func test_nom_personnalise_dans_les_listes_les_temporisations_et_les_confirmations() {
        let app = openLighting(["UITEST_LIGHT_NAMES": "dressing=WC 3;wc1=WC Haut;idressing=Placards <b>"])
        XCTAssertTrue(app.staticTexts["WC 3"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Dressing"].exists)
        XCTAssertTrue(app.staticTexts["Placards <b>"].exists) // texte brut, jamais interprété
        XCTAssertTrue(app.staticTexts["Salle de Bain 1"].exists) // sans nom personnalisé : nom d'origine
        attach(app, "23-light-names-lighting")
        // Confirmation / dernière action avec le nom affiché.
        tap(app, app.buttons["light-wc1-primary"])
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'WC Haut : commande'")).firstMatch.waitForExistence(timeout: 5))
        // Écran Temporisations : le nom affiché, et non le libellé d'origine.
        app.tabBars.buttons["Accueil"].tap()
        tap(app, app.buttons["open-LIGHT_TIMERS"])
        XCTAssertTrue(app.staticTexts["timer-menu-dressing-current"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["WC 3"].exists)
        XCTAssertTrue(app.staticTexts["WC Haut"].exists)
        XCTAssertFalse(app.staticTexts["Dressing"].exists)
        XCTAssertFalse(app.staticTexts["WC 1"].exists)
        attach(app, "24-light-names-timers")
    }

    @MainActor func test_nom_dans_l_editeur_de_scenarios() {
        let app = launch(["UITEST_LIGHT_NAMES": "isalonind=Canapé"])
        tap(app, app.buttons["open-SCENARIOS"])
        tap(app, app.buttons["edit-4"])
        let named = app.switches["bit-605-2"]
        XCTAssertTrue(named.waitForExistence(timeout: 10))
        var tries = 0
        while !named.isHittable && tries < 8 { app.swipeUp(); tries += 1 }
        XCTAssertTrue(waitFor { named.label == "Canapé" }, named.label)
        XCTAssertEqual(app.switches["bit-605-1"].label, "Entrée") // sans nom : libellé inchangé
    }

    @MainActor func test_l_administrateur_renomme_puis_revient_au_nom_d_origine() {
        let app = openLighting()
        rename(app, "dressing", to: "WC 3")
        XCTAssertTrue(waitFor { !self.log(app, "uitest-mutations").isEmpty })
        XCTAssertEqual(log(app, "uitest-mutations"), [#"PUT /api/portal/admin/lights/names/dressing {"name":"WC 3"}"#])
        XCTAssertTrue(waitFor { app.buttons["light-dressing-name-toggle"].label.contains("WC 3") })
        XCTAssertTrue(app.staticTexts["WC 3"].exists) // sans rechargement
        attach(app, "25-light-name-saved")
        tap(app, app.buttons["light-dressing-name-reset"])
        XCTAssertTrue(waitFor { self.log(app, "uitest-mutations").count == 2 })
        XCTAssertEqual(log(app, "uitest-mutations").last, #"PUT /api/portal/admin/lights/names/dressing {"name":null}"#)
        XCTAssertTrue(waitFor { app.buttons["light-dressing-name-toggle"].label.contains("Dressing") })
        // NR-ios-25 : aucun ordre vers l'armoire.
        XCTAssertTrue(log(app, "uitest-injections").isEmpty)
    }

    @MainActor func test_nom_trop_long_refuse_sans_requete() {
        let app = openLighting()
        rename(app, "dressing", to: String(repeating: "a", count: 41))
        XCTAssertTrue(app.staticTexts["light-dressing-name-error"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["light-dressing-name-error"].label.contains("1 à 40"))
        usleep(500_000)
        XCTAssertTrue(log(app, "uitest-mutations").isEmpty)
        XCTAssertTrue(log(app, "uitest-injections").isEmpty)
    }

    @MainActor func test_erreur_503_affiche_un_message_clair() {
        let app = openLighting(["UITEST_NAMES_WRITE": "503"])
        rename(app, "dressing", to: "WC 3")
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'stockage indisponible'")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Dressing"].exists) // aucun changement
    }

    @MainActor func test_erreur_403_affiche_un_message_clair() {
        let app = openLighting(["UITEST_NAMES_WRITE": "403"])
        rename(app, "dressing", to: "WC 3")
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Réservé à l'administrateur")).firstMatch.waitForExistence(timeout: 5))
    }

    @MainActor func test_lecture_impossible_affiche_les_noms_d_origine() {
        let app = openLighting(["UITEST_NAMES_READ_FAIL": "1", "UITEST_LIGHT_NAMES": "dressing=WC 3"])
        usleep(800_000)
        XCTAssertTrue(app.staticTexts["Dressing"].exists)
        XCTAssertFalse(app.staticTexts["WC 3"].exists)
        XCTAssertFalse(app.alerts.firstMatch.exists) // pas de message bloquant
    }

    @MainActor func test_masque_pour_un_utilisateur_simple_mais_noms_affiches() {
        let app = openLighting(["UITEST_ROLE": "guest_local", "UITEST_LIGHT_NAMES": "dressing=WC 3"])
        XCTAssertTrue(app.staticTexts["WC 3"].waitForExistence(timeout: 5))
        usleep(500_000)
        XCTAssertFalse(app.buttons["light-dressing-name-toggle"].exists)
        XCTAssertFalse(app.buttons["light-wc1-name-toggle"].exists)
    }

    @MainActor func test_mode_local_ecrit_sur_la_route_locale() {
        let app = openLighting(["UITEST_MODE": "lan", "UITEST_ROLE": "lan_admin"])
        rename(app, "wc1", to: "WC Haut")
        XCTAssertTrue(waitFor { !self.log(app, "uitest-mutations").isEmpty })
        XCTAssertEqual(log(app, "uitest-mutations"), [#"PUT /api/admin/lights/names/wc1 {"name":"WC Haut"}"#])
    }

    @MainActor func test_mode_local_sans_droit_administrateur_ne_propose_pas_le_champ() {
        let app = openLighting(["UITEST_MODE": "lan", "UITEST_ROLE": "lan_user"])
        usleep(800_000)
        XCTAssertFalse(app.buttons["light-dressing-name-toggle"].exists)
    }
}
