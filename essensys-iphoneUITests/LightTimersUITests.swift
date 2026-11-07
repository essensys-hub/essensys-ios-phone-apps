//
//  LightTimersUITests.swift
//  Temporisations des lumières (spec light-timers-clients) sur simulateur, contre le backend simulé embarqué :
//  aucune armoire réelle. Feature lumieres-temporisees-2026-11-003, tâche 7.3.
//

import XCTest

final class LightTimersUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private static let exchange = "521=15,556=0,557=60,562=7"

    private func launch(_ env: [String: String] = [:]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment = ["UITEST_BACKEND": "1", "UITEST_TOKEN": "1", "UITEST_EXCHANGE": Self.exchange].merging(env) { $1 }
        app.launch()
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

    private func text(_ app: XCUIApplication, _ id: String) -> String { app.staticTexts[id].label }

    private func openMenu(_ env: [String: String] = [:]) -> XCUIApplication {
        let app = launch(env)
        XCTAssertTrue(app.buttons["quick-2"].waitForExistence(timeout: 10))
        tap(app, app.buttons["open-LIGHT_TIMERS"])
        XCTAssertTrue(app.staticTexts["timer-menu-dressing-current"].waitForExistence(timeout: 5))
        return app
    }

    @MainActor func test_liste_des_six_lumieres_avec_valeur_courante() {
        let app = openMenu()
        XCTAssertTrue(waitFor { self.text(app, "timer-menu-dressing-current") == "15 min" }, text(app, "timer-menu-dressing-current"))
        XCTAssertEqual(text(app, "timer-menu-wc1-current"), "Inconnue") // jamais lue : jamais 0
        XCTAssertEqual(text(app, "timer-menu-wc2-current"), "Jamais")
        XCTAssertEqual(text(app, "timer-menu-pieceserv-current"), "1 h")
        XCTAssertEqual(text(app, "timer-menu-ann1-current"), "Inconnue")
        XCTAssertEqual(text(app, "timer-menu-ann2-current"), "7 min") // valeur libre affichée telle quelle
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "21-light-timers-menu-light"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor func test_raccourci_30_min_depuis_le_menu_envoie_le_put() {
        let app = openMenu()
        tap(app, app.buttons["timer-menu-wc1-30"])
        XCTAssertTrue(waitFor { !self.log(app, "uitest-mutations").isEmpty })
        XCTAssertEqual(log(app, "uitest-mutations"), [#"PUT /api/portal/admin/lights/timers/wc1 {"minutes":30}"#])
    }

    @MainActor func test_dressing_dans_la_lumiere_puis_meme_valeur_dans_le_menu() {
        let app = launch()
        XCTAssertTrue(app.buttons["quick-2"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Éclairage"].tap()
        tap(app, app.buttons["light-dressing-timer-toggle"])
        XCTAssertTrue(waitFor { self.buttonLabel(app, "light-dressing-timer-toggle").contains("Temporisation : 15 min") })
        tap(app, app.buttons["timer-light-dressing-60"])
        XCTAssertTrue(waitFor { !self.log(app, "uitest-mutations").isEmpty })
        XCTAssertEqual(log(app, "uitest-mutations"), [#"PUT /api/portal/admin/lights/timers/dressing {"minutes":60}"#])
        // Relecture à 5 s : le menu central montre la même valeur.
        XCTAssertTrue(waitFor(15) { self.buttonLabel(app, "light-dressing-timer-toggle").contains("Temporisation : 1 h") })
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "22-light-timer-dressing-light"
        attachment.lifetime = .keepAlways
        add(attachment)
        app.tabBars.buttons["Accueil"].tap()
        tap(app, app.buttons["open-LIGHT_TIMERS"])
        XCTAssertTrue(app.staticTexts["timer-menu-dressing-current"].waitForExistence(timeout: 5))
        XCTAssertTrue(waitFor { self.text(app, "timer-menu-dressing-current") == "1 h" }, text(app, "timer-menu-dressing-current"))
    }

    private func buttonLabel(_ app: XCUIApplication, _ buttonId: String) -> String { app.buttons[buttonId].label }

    @MainActor func test_valeur_libre_7_minutes() {
        let app = openMenu()
        let field = app.textFields["timer-menu-dressing-field"]
        tap(app, field)
        field.typeText("7")
        tap(app, app.buttons["timer-menu-dressing-apply"])
        XCTAssertTrue(waitFor { !self.log(app, "uitest-mutations").isEmpty })
        XCTAssertEqual(log(app, "uitest-mutations"), [#"PUT /api/portal/admin/lights/timers/dressing {"minutes":7}"#])
        XCTAssertTrue(waitFor(15) { self.text(app, "timer-menu-dressing-current") == "7 min" }, text(app, "timer-menu-dressing-current"))
    }

    @MainActor func test_300_et_0_sont_refuses_sans_requete() {
        let app = openMenu()
        let field = app.textFields["timer-menu-dressing-field"]
        for value in ["300", "0"] {
            tap(app, field)
            field.typeText(value)
            tap(app, app.buttons["timer-menu-dressing-apply"])
            XCTAssertTrue(app.staticTexts["timer-menu-dressing-error"].waitForExistence(timeout: 5), value)
            XCTAssertTrue(app.staticTexts["timer-menu-dressing-error"].label.contains("1 à 255"))
            // Vide le champ pour la valeur suivante.
            field.press(forDuration: 1.0)
            if app.menuItems["Select All"].waitForExistence(timeout: 2) { app.menuItems["Select All"].tap() }
            field.typeText(XCUIKeyboardKey.delete.rawValue)
        }
        usleep(500_000)
        XCTAssertTrue(log(app, "uitest-mutations").isEmpty)
    }

    @MainActor func test_masque_pour_un_utilisateur_simple() {
        let app = launch(["UITEST_ROLE": "guest_local"])
        XCTAssertTrue(app.buttons["quick-2"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["open-SECURITY_OUTLETS"].exists)
        XCTAssertFalse(app.buttons["open-LIGHT_TIMERS"].exists)
        app.tabBars.buttons["Éclairage"].tap()
        XCTAssertTrue(app.buttons["light-dressing-primary"].waitForExistence(timeout: 5))
        usleep(800_000)
        XCTAssertFalse(app.buttons["light-dressing-timer-toggle"].exists)
        XCTAssertFalse(app.buttons["light-wc1-timer-toggle"].exists)
    }

    @MainActor func test_controles_desactives_hors_ligne() {
        let app = launch(["UITEST_ONLINE": "0"])
        XCTAssertTrue(app.staticTexts["Armoire hors ligne"].waitForExistence(timeout: 10))
        tap(app, app.buttons["open-LIGHT_TIMERS"])
        XCTAssertTrue(app.staticTexts["timers-offline"].waitForExistence(timeout: 5))
        // Les lumières suivent l'ordre de la disposition (affichage-objets-2026-11-006) : le Dressing est en bas de
        // l'écran et n'est pas dans la hiérarchie tant qu'il n'est pas visible ; on contrôle WC 1.
        XCTAssertFalse(app.buttons["timer-menu-wc1-30"].isEnabled)
        XCTAssertFalse(app.buttons["timer-menu-wc1-apply"].isEnabled)
    }
}
