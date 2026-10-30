//
//  SupportUITests.swift
//  Bouton Support (app-support-bundle-2026-10-013) sur simulateur, contre le backend simulé embarqué :
//  aucune armoire réelle. Le composeur Mail n'est pas pilotable en simulateur : en mode UI-test, l'envoi
//  est relevé par la sonde `uitest-support-mail`. Jumeau de SupportFlowTest (Android).
//

import XCTest

final class SupportUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launch(_ env: [String: String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment = ["UITEST_BACKEND": "1"].merging(env) { $1 }
        app.launch()
        return app
    }

    private func tap(_ app: XCUIApplication, _ element: XCUIElement) {
        XCTAssertTrue(element.waitForExistence(timeout: 10), "\(element)")
        var tries = 0
        while !element.isHittable && tries < 10 { app.swipeUp(); tries += 1 }
        element.tap()
    }

    private func sendAndReadMail(_ app: XCUIApplication) -> String {
        tap(app, app.buttons["support-send"])
        let probe = app.staticTexts["uitest-support-mail"]
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline, (probe.value as? String ?? "").isEmpty { usleep(200_000) }
        return probe.value as? String ?? ""
    }

    @MainActor func test_settings_support_runs_diagnostics_and_prepares_the_email() {
        let app = launch(["UITEST_TOKEN": "1", "UITEST_TEST_MODE": "1"])
        XCTAssertTrue(app.buttons["quick-2"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Réglages"].tap()
        tap(app, app.buttons["open-support"])
        XCTAssertTrue(app.buttons["support-send"].waitForExistence(timeout: 30))
        XCTAssertEqual(app.staticTexts["check-online-status"].label, "OK")
        let mail = sendAndReadMail(app)
        XCTAssertTrue(mail.hasPrefix("support_essensys@rhinosys.fr|Support Essensys — "), mail)
        XCTAssertTrue(mail.contains("|essensys-support-ios-"), mail)
        XCTAssertTrue(mail.hasSuffix(".zip|application/zip"), mail)
        // Lecture seule : le diagnostic n'a envoyé aucune commande.
        XCTAssertEqual(app.staticTexts["uitest-injections"].value as? String ?? "", "")
        XCTAssertEqual(app.staticTexts["uitest-mutations"].value as? String ?? "", "")
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "support-screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor func test_support_is_reachable_before_login() {
        let app = launch([:])
        tap(app, app.buttons["open-support"])
        XCTAssertTrue(app.buttons["support-send"].waitForExistence(timeout: 30))
        XCTAssertEqual(app.staticTexts["check-session-status"].label, "Non applicable")
        XCTAssertEqual(app.staticTexts["check-health-status"].label, "OK")
        XCTAssertFalse(sendAndReadMail(app).isEmpty)
        app.buttons["support-close"].tap()
        XCTAssertTrue(app.buttons["login"].waitForExistence(timeout: 5))
    }
}
