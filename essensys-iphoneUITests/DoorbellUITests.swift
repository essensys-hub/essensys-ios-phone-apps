//
//  DoorbellUITests.swift
//  Option « Sonnette » (sonnette-plages-push-2026-11-008, essensys-feature-lifecycle#61) sur simulateur, contre le
//  backend simulé embarqué : aucun cloud réel, aucune notification réelle. Jumeau de DoorbellFlowTest (Android).
//

import XCTest

final class DoorbellUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launch(_ env: [String: String] = [:]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment = ["UITEST_BACKEND": "1", "UITEST_TOKEN": "1"].merging(env) { $1 }
        app.launch()
        return app
    }

    private func openSettings(_ app: XCUIApplication) {
        XCTAssertTrue(app.tabBars.buttons["Réglages"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Réglages"].tap()
        XCTAssertTrue(app.buttons["switch-mode"].waitForExistence(timeout: 5))
    }

    private func scrollTo(_ app: XCUIApplication, _ element: XCUIElement) {
        XCTAssertTrue(element.waitForExistence(timeout: 10), "\(element)")
        var tries = 0
        while !element.isHittable && tries < 20 { app.swipeUp(); tries += 1 }
        XCTAssertTrue(element.isHittable, "\(element)")
    }

    private func flip(_ app: XCUIApplication, _ toggle: XCUIElement) {
        scrollTo(app, toggle)
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
    }

    private func mutations(_ app: XCUIApplication) -> String { app.staticTexts["uitest-mutations"].value as? String ?? "" }

    private func waitFor(_ app: XCUIApplication, _ fragment: String) {
        let deadline = Date().addingTimeInterval(8)
        while Date() < deadline, !mutations(app).contains(fragment) { usleep(200_000) }
        XCTAssertTrue(mutations(app).contains(fragment), mutations(app))
    }

    @MainActor func test_toggle_registers_the_device_and_shows_the_gateway_state() {
        let app = launch()
        openSettings(app)
        let label = app.staticTexts["doorbell-gateway"]
        scrollTo(app, label)
        XCTAssertEqual(label.label, "Gateway en ligne")
        XCTAssertTrue(app.staticTexts["La sonnette doit être activée sur la gateway pour que la notification arrive."].exists)
        let toggle = app.switches["doorbell-toggle"]
        XCTAssertEqual(toggle.value as? String, "0")
        flip(app, toggle)
        waitFor(app, "PUT /api/portal/push/devices notify=true")
        XCTAssertEqual(toggle.value as? String, "1")
        flip(app, toggle)
        waitFor(app, "notify=false")
        XCTAssertEqual(toggle.value as? String, "0")
    }

    @MainActor func test_offline_gateway_label() {
        let app = launch(["UITEST_ONLINE": "0"])
        openSettings(app)
        let label = app.staticTexts["doorbell-gateway"]
        scrollTo(app, label)
        XCTAssertEqual(label.label, "Gateway hors ligne")
    }

    @MainActor func test_no_gateway_hides_the_option() {
        let app = launch(["UITEST_GATEWAY": "none"])
        openSettings(app)
        XCTAssertTrue(app.buttons["logout"].waitForExistence(timeout: 5) || app.buttons["open-support"].exists)
        sleep(1)
        XCTAssertFalse(app.switches["doorbell-toggle"].exists)
        XCTAssertFalse(app.staticTexts["doorbell-gateway"].exists)
    }

    @MainActor func test_old_cloud_without_gateway_state_hides_the_option() {
        let app = launch(["UITEST_GATEWAY_STATE": "absent"])
        openSettings(app)
        sleep(1)
        XCTAssertFalse(app.switches["doorbell-toggle"].exists)
    }

    @MainActor func test_denied_permission_resets_the_switch_and_points_to_system_settings() {
        let app = launch(["UITEST_PUSH_AUTH": "denied"])
        openSettings(app)
        let toggle = app.switches["doorbell-toggle"]
        flip(app, toggle)
        let message = app.staticTexts["doorbell-message"]
        XCTAssertTrue(message.waitForExistence(timeout: 5))
        XCTAssertTrue(message.label.contains("Réglages"), message.label)
        XCTAssertEqual(toggle.value as? String, "0")
        XCTAssertFalse(mutations(app).contains("push/devices"))
    }

    @MainActor func test_device_unknown_to_this_install_reads_as_off_and_logout_calls_nothing() {
        let app = launch(["UITEST_PUSH_NOTIFY": "1"])
        openSettings(app)
        let toggle = app.switches["doorbell-toggle"]
        scrollTo(app, toggle)
        // Le cloud ne renvoie jamais le jeton : un appareil sans id local (réinstallation) ne compte pas, l'interrupteur est à zéro
        // et la déconnexion n'appelle rien. Réactiver le même jeton met l'appareil à jour (PUT idempotent).
        XCTAssertEqual(toggle.value as? String, "0")
        let logout = app.buttons["logout"]
        scrollTo(app, logout)
        logout.tap()
        XCTAssertTrue(app.textFields["email"].waitForExistence(timeout: 10))
        XCTAssertFalse(mutations(app).contains("DELETE"))
    }

    // NR: NR-ios-28 essensys-hub/essensys-feature-lifecycle#61
    @MainActor func test_logout_after_activation_deletes_the_device_NR_ios_28() {
        let app = launch()
        openSettings(app)
        flip(app, app.switches["doorbell-toggle"])
        waitFor(app, "notify=true")
        let logout = app.buttons["logout"]
        scrollTo(app, logout)
        logout.tap()
        waitFor(app, "DELETE /api/portal/push/devices/7")
    }
}
