//
//  essensys_iphoneUITests.swift
//  Parcours V1 sur simulateur contre le backend simulé embarqué (UITEST_BACKEND, DEBUG) :
//  aucune armoire réelle (spec ios-quality « Tests unitaires et UI »). Jumeau d'AppFlowTest.kt.
//

import XCTest

final class AppFlowUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launch(_ env: [String: String] = [:]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment = ["UITEST_BACKEND": "1"].merging(env) { $1 }
        app.launch()
        return app
    }

    private func screenshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func injections(_ app: XCUIApplication) -> [String] {
        let value = app.staticTexts["uitest-injections"].value as? String ?? ""
        return value.isEmpty ? [] : value.components(separatedBy: "|")
    }

    /// iOS peut proposer d'enregistrer le mot de passe après la connexion : on refuse (fenêtre système).
    private func dismissPasswordPrompts(_ app: XCUIApplication) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for label in ["Not Now", "Pas maintenant", "Plus tard", "Jamais pour ce site web", "Never for This Website"] {
            for candidate in [app.buttons[label], springboard.buttons[label]] where candidate.exists {
                candidate.tap()
                return
            }
        }
    }

    private func login(_ app: XCUIApplication) {
        app.textFields["email"].tap()
        app.textFields["email"].typeText("demo@essensys.fr")
        app.secureTextFields["password"].tap()
        app.secureTextFields["password"].typeText("secret123")
        app.buttons["login"].tap()
    }

    @MainActor func test_cloud_login_opens_home_with_gateway_status() {
        let app = launch()
        screenshot(app, "01-login-light")
        login(app)
        XCTAssertTrue(app.staticTexts["Armoire en ligne"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["open-lighting"].exists)
        let deadline = Date().addingTimeInterval(5)
        while !app.buttons["open-lighting"].isHittable && Date() < deadline { dismissPasswordPrompts(app); usleep(300_000) }
        screenshot(app, "02-home-light")
    }

    // NR: NR-ios-8 essensys-hub/essensys-ios-phone-apps#4
    @MainActor func test_lighting_command_is_sent_once_on_double_tap_NR_ios_8() {
        let app = launch(["UITEST_TOKEN": "1", "UITEST_INJECT_DELAY_MS": "800"])
        XCTAssertTrue(app.tabBars.buttons["Éclairage"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Éclairage"].tap()
        let salon = app.buttons["light-salon-primary"]
        XCTAssertTrue(salon.waitForExistence(timeout: 5))
        salon.tap()
        salon.tap()
        XCTAssertTrue(app.staticTexts["Salon : commande envoyée — l'armoire exécute sous ~5 s"].waitForExistence(timeout: 10))
        XCTAssertEqual(injections(app), [#"{"k":612,"v":"128"}"#])
        screenshot(app, "03-lighting-light")
    }

    @MainActor func test_shutters_screen_sends_kitchen_close_and_shows_travel_time() {
        let app = launch(["UITEST_TOKEN": "1"])
        XCTAssertTrue(app.tabBars.buttons["Volets"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Volets"].tap()
        XCTAssertTrue(app.staticTexts["Temps de course : 25 s"].waitForExistence(timeout: 10))
        let close = app.buttons["shutter-volet1cuisine-secondary"]
        while !close.isHittable { app.swipeUp() }
        close.tap()
        let deadline = Date().addingTimeInterval(10)
        while injections(app).isEmpty && Date() < deadline { usleep(200_000) }
        XCTAssertEqual(injections(app), [#"{"k":622,"v":"1"}"#])
        screenshot(app, "04-shutters-light")
    }

    @MainActor func test_offline_gateway_disables_commands() {
        let app = launch(["UITEST_TOKEN": "1", "UITEST_ONLINE": "0"])
        XCTAssertTrue(app.staticTexts["Armoire hors ligne"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Éclairage"].tap()
        XCTAssertFalse(app.buttons["light-salon-primary"].isEnabled)
    }

    @MainActor func test_temporary_password_forces_change_before_home() {
        let app = launch(["UITEST_TEMP_PASSWORD": "1"])
        login(app)
        XCTAssertTrue(app.buttons["change-password"].waitForExistence(timeout: 10))
        let current = app.secureTextFields["current-password"]
        let deadline = Date().addingTimeInterval(10)
        while !current.isHittable && Date() < deadline { dismissPasswordPrompts(app); usleep(300_000) }
        screenshot(app, "05-password-change")
        app.secureTextFields["current-password"].tap()
        app.secureTextFields["current-password"].typeText("secret123")
        app.secureTextFields["new-password"].tap()
        app.secureTextFields["new-password"].typeText("Nouveau-pass-456")
        app.buttons["change-password"].tap()
        XCTAssertTrue(app.buttons["open-lighting"].waitForExistence(timeout: 10))
    }

    @MainActor func test_account_without_armoire_sees_link_screen() {
        let app = launch(["UITEST_TOKEN": "1", "UITEST_LINKED": "0"])
        XCTAssertTrue(app.buttons["request-link"].waitForExistence(timeout: 10))
        screenshot(app, "06-link")
        XCTAssertTrue(injections(app).isEmpty)
    }

    @MainActor func test_lan_host_in_cleartext_is_refused() {
        let app = launch(["UITEST_MODE": "lan"])
        let host = app.textFields["lan-host"]
        XCTAssertTrue(host.waitForExistence(timeout: 10))
        host.tap()
        host.press(forDuration: 1.0)
        if app.menuItems["Select All"].waitForExistence(timeout: 2) { app.menuItems["Select All"].tap() }
        host.typeText(XCUIKeyboardKey.delete.rawValue)
        host.typeText("http://mon.essensys.local")
        login(app)
        XCTAssertTrue(app.staticTexts["Seule une connexion sécurisée (https://) est possible."].waitForExistence(timeout: 5))
    }

    @MainActor func test_test_mode_shows_banner_and_dry_run_message() {
        let app = launch(["UITEST_TOKEN": "1", "UITEST_TEST_MODE": "1"])
        XCTAssertTrue(app.staticTexts["test-banner"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Éclairage"].tap()
        app.buttons["light-salon-primary"].tap()
        XCTAssertTrue(app.staticTexts["Salon : commande validée (test, non exécutée)"].waitForExistence(timeout: 10))
    }

    @MainActor func test_dark_theme_renders_lighting_and_settings() {
        let app = launch(["UITEST_TOKEN": "1", "UITEST_THEME": "dark"])
        XCTAssertTrue(app.tabBars.buttons["Éclairage"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Éclairage"].tap()
        screenshot(app, "07-lighting-dark")
        app.tabBars.buttons["Réglages"].tap()
        XCTAssertTrue(app.buttons["logout"].waitForExistence(timeout: 5))
        screenshot(app, "08-settings-dark")
    }
}
