//
//  RememberMeUITests.swift
//  « Se souvenir de moi » (session-30-jours-2026-11-001) sur simulateur, contre le backend simulé embarqué :
//  aucune armoire réelle. Jumeau de RememberMeFlowTest (Android).
//

import XCTest

final class RememberMeUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launch(_ env: [String: String] = [:]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment = ["UITEST_BACKEND": "1"].merging(env) { $1 }
        app.launch()
        return app
    }

    /// iOS propose d'enregistrer le mot de passe après la connexion et masque l'app : on ferme la fenêtre système.
    private func scrollTo(_ app: XCUIApplication, _ element: XCUIElement) {
        let appears = Date().addingTimeInterval(15)
        while !element.exists && Date() < appears { dismissPasswordPrompts(app); usleep(400_000) }
        XCTAssertTrue(element.exists, "\(element)")
        var tries = 0
        while !element.isHittable && tries < 20 {
            dismissPasswordPrompts(app)
            if !element.isHittable { app.swipeUp() }
            tries += 1
        }
        XCTAssertTrue(element.isHittable, "\(element)")
    }

    /// Le toucher au centre d'une ligne SwiftUI vise le libellé : on vise l'interrupteur, à droite.
    private func flip(_ app: XCUIApplication, _ toggle: XCUIElement) {
        scrollTo(app, toggle)
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
    }

    private func dismissPasswordPrompts(_ app: XCUIApplication) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for label in ["Not Now", "Pas maintenant", "Plus tard", "Jamais pour ce site web", "Never for This Website"] {
            for candidate in [app.buttons[label], springboard.buttons[label]] where candidate.exists {
                candidate.tap()
                return
            }
        }
    }

    /// Le toucher sur l'onglet est avalé tant que la fenêtre système est là : on réessaie jusqu'à voir un écran de Réglages.
    private func openSettings(_ app: XCUIApplication) {
        for _ in 0..<5 {
            dismissPasswordPrompts(app)
            if app.tabBars.buttons["Réglages"].isHittable { app.tabBars.buttons["Réglages"].tap() }
            if app.buttons["switch-mode"].waitForExistence(timeout: 3) { return }
        }
        XCTFail("Réglages introuvables")
    }

    private func login(_ app: XCUIApplication) {
        app.textFields["email"].tap()
        app.textFields["email"].typeText("demo@essensys.fr")
        app.secureTextFields["password"].tap()
        app.secureTextFields["password"].typeText("secret123")
        app.buttons["login"].tap()
        XCTAssertTrue(app.tabBars.buttons["Réglages"].waitForExistence(timeout: 10))
        let deadline = Date().addingTimeInterval(8)
        while !app.tabBars.buttons["Réglages"].isHittable && Date() < deadline { dismissPasswordPrompts(app); usleep(300_000) }
    }

    private func logins(_ app: XCUIApplication) -> String { app.staticTexts["uitest-logins"].value as? String ?? "" }

    private func value(_ toggle: XCUIElement) -> String { toggle.value as? String ?? "" }

    // Tâches 1.3 et 2.3 : case décochée par défaut, valeur transmise, date de fin, puis case décochée après la déconnexion.
    @MainActor func test_remember_me_is_sent_shown_in_settings_and_not_remembered_after_logout() {
        let app = launch()
        let toggle = app.switches["remember-me"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        XCTAssertEqual(value(toggle), "0", "décochée par défaut")
        flip(app, toggle)
        XCTAssertEqual(value(toggle), "1")
        login(app)
        XCTAssertTrue(logins(app).contains("login remember_me=true"), logins(app))

        openSettings(app)
        let until = app.staticTexts["remember-until"]
        scrollTo(app, until)
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        let expected = "Connecté jusqu'au \(formatter.string(from: Date().addingTimeInterval(30 * 86_400)))"
        XCTAssertEqual(until.label, expected)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "settings-remember-until"
        shot.lifetime = .keepAlways
        add(shot)

        let logout = app.buttons["logout"]
        scrollTo(app, logout)
        logout.tap()
        XCTAssertTrue(app.buttons["login"].waitForExistence(timeout: 10))
        // La révocation part avec le jeton mémorisé, et la case n'a pas gardé le choix précédent.
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline, !logins(app).contains("logout") { usleep(200_000) }
        XCTAssertTrue(logins(app).contains(#"logout {"remember_token":"remember-uitest"}"#), logins(app))
        XCTAssertEqual(value(app.switches["remember-me"]), "0", "non mémorisée d'une connexion à l'autre")
    }

    // Tâche 2.3 : aucune date de fin pour une session non mémorisée.
    @MainActor func test_settings_show_no_end_date_when_the_session_is_not_remembered() {
        let app = launch()
        XCTAssertTrue(app.switches["remember-me"].waitForExistence(timeout: 10))
        login(app)
        XCTAssertTrue(logins(app).contains("login remember_me=false"), logins(app))
        openSettings(app)
        scrollTo(app, app.buttons["logout"])
        XCTAssertFalse(app.staticTexts["remember-until"].exists)
    }

    // Tâche 1.3 : la case est proposée en mode Cloud comme en mode Réseau local.
    @MainActor func test_remember_me_is_offered_in_cloud_and_lan_modes() {
        let app = launch(["UITEST_MODE": "lan"])
        XCTAssertTrue(app.textFields["lan-host"].waitForExistence(timeout: 10), "mode Réseau local")
        XCTAssertTrue(app.switches["remember-me"].exists)
        app.buttons["Cloud"].tap()
        XCTAssertFalse(app.textFields["lan-host"].exists, "mode Cloud")
        XCTAssertTrue(app.switches["remember-me"].waitForExistence(timeout: 5))
        XCTAssertEqual(value(app.switches["remember-me"]), "0")
    }
}
