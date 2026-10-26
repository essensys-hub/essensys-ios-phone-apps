//
//  SecurityOutletsUITests.swift
//  Prises de sécurité (spec security-outlets) sur simulateur, contre le backend simulé embarqué :
//  aucune armoire réelle. Jumeau de SecurityOutletsFlowTest (Android).
//

import XCTest

final class SecurityOutletsUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launch(_ env: [String: String] = [:]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment = ["UITEST_BACKEND": "1", "UITEST_TOKEN": "1"].merging(env) { $1 }
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

    private func openOutlets(_ env: [String: String] = [:]) -> XCUIApplication {
        let app = launch(env)
        XCTAssertTrue(app.buttons["quick-2"].waitForExistence(timeout: 10))
        tap(app, app.buttons["open-SECURITY_OUTLETS"])
        XCTAssertTrue(app.buttons["outlets-cut"].waitForExistence(timeout: 5))
        return app
    }

    private func stateLabel(_ app: XCUIApplication) -> String { app.descendants(matching: .any)["outlets-state"].label }

    @MainActor func test_couper_envoie_590_et_623_a_1_apres_confirmation() {
        let app = openOutlets(["UITEST_EXCHANGE": "440=0"])
        XCTAssertTrue(waitFor { self.stateLabel(app).contains("Prises pilotées") }, stateLabel(app))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "20-security-outlets-light"
        attachment.lifetime = .keepAlways
        add(attachment)
        app.buttons["outlets-cut"].tap()
        XCTAssertTrue(app.alerts.buttons["Couper"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(log(app, "uitest-injections").isEmpty)
        app.alerts.buttons["Couper"].firstMatch.tap()
        XCTAssertTrue(waitFor { !self.log(app, "uitest-injections").isEmpty })
        XCTAssertEqual(log(app, "uitest-injections"), [#"{"params":[{"k":590,"v":"1"},{"k":623,"v":"1"}]}"#])
        XCTAssertTrue(waitFor { self.stateLabel(app).contains("En attente de l'armoire") }, stateLabel(app))
    }

    @MainActor func test_annuler_la_confirmation_n_envoie_rien() {
        let app = openOutlets()
        app.buttons["outlets-cut"].tap()
        XCTAssertTrue(app.alerts.buttons["Annuler"].firstMatch.waitForExistence(timeout: 5))
        app.alerts.buttons["Annuler"].firstMatch.tap()
        XCTAssertTrue(app.buttons["outlets-cut"].isEnabled)
        usleep(500_000)
        XCTAssertTrue(log(app, "uitest-injections").isEmpty)
    }

    @MainActor func test_retablir_envoie_590_et_623_a_2() {
        let app = openOutlets()
        app.buttons["outlets-restore"].tap()
        XCTAssertTrue(waitFor { !self.log(app, "uitest-injections").isEmpty })
        XCTAssertEqual(log(app, "uitest-injections"), [#"{"params":[{"k":590,"v":"1"},{"k":623,"v":"2"}]}"#])
    }

    @MainActor func test_commandes_desactivees_hors_ligne() {
        let app = launch(["UITEST_ONLINE": "0"])
        XCTAssertTrue(app.staticTexts["Armoire hors ligne"].waitForExistence(timeout: 10))
        tap(app, app.buttons["open-SECURITY_OUTLETS"])
        XCTAssertTrue(app.staticTexts["outlets-offline"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["outlets-cut"].isEnabled)
        XCTAssertFalse(app.buttons["outlets-restore"].isEnabled)
    }

    @MainActor func test_etat_inconnu_sans_indice_440() {
        let app = openOutlets()
        XCTAssertTrue(waitFor { self.stateLabel(app).contains("État inconnu") }, stateLabel(app))
        XCTAssertTrue(app.buttons["outlets-restore"].isEnabled)
    }

    @MainActor func test_editeur_scenario_prises_au_decalage_31() {
        let app = launch()
        XCTAssertTrue(app.buttons["quick-2"].waitForExistence(timeout: 10))
        tap(app, app.buttons["open-SCENARIOS"])
        tap(app, app.buttons["edit-4"])
        let couper = app.segmentedControls["scenario-security"].buttons["Couper"]
        tap(app, couper)
        tap(app, app.buttons["editor-save"])
        XCTAssertTrue(waitFor { !self.log(app, "uitest-mutations").isEmpty })
        let put = log(app, "uitest-mutations").last ?? ""
        XCTAssertTrue(put.hasPrefix("PUT /api/portal/scenarios/4 "), put)
        XCTAssertTrue(put.contains(#""746":"1""#), put) // scénario 4 : 715 + 31
    }
}
