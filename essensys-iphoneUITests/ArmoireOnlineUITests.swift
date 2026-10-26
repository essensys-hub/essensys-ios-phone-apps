//
//  ArmoireOnlineUITests.swift
//  Armoire « en ligne » avec ou sans gateway (armoire-online-sans-gateway-2026-10-012) sur simulateur, contre
//  le backend simulé embarqué : aucune armoire réelle. Cas A à G de la matrice du ticket
//  essensys-hub/essensys-feature-lifecycle#37. Jumeau de ArmoireOnlineFlowTest (Android).
//

import XCTest

final class ArmoireOnlineUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launch(_ env: [String: String] = [:]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment = ["UITEST_BACKEND": "1", "UITEST_TOKEN": "1"].merging(env) { $1 }
        app.launch()
        return app
    }

    private func expectOnline(_ online: Bool, _ env: [String: String] = [:]) {
        let app = launch(env)
        XCTAssertTrue(app.buttons["quick-2"].waitForExistence(timeout: 10))
        let label = online ? "Armoire en ligne" : "Armoire hors ligne"
        XCTAssertTrue(app.staticTexts[label].waitForExistence(timeout: 10), label)
        XCTAssertEqual(app.buttons["quick-2"].isEnabled, online)
    }

    @MainActor func test_avec_gateway_en_ligne() { expectOnline(true) }

    @MainActor func test_gateway_hors_ligne_armoire_vue() {
        expectOnline(true, ["UITEST_ONLINE": "0", "UITEST_ARMOIRE": "seen"])
    }

    @MainActor func test_gateway_et_armoire_hors_ligne() { expectOnline(false, ["UITEST_ONLINE": "0"]) }

    // NR: NR-ios-19 essensys-hub/essensys-ios-phone-apps#25
    // Signalement du 2026-10-26 (essensys-feature-lifecycle#37) : installation sans gateway, armoire joignable.
    @MainActor func test_sans_gateway_armoire_vue_en_ligne_NR_ios_19() {
        expectOnline(true, ["UITEST_GATEWAY": "none", "UITEST_ARMOIRE": "seen"])
    }

    @MainActor func test_sans_gateway_armoire_ancienne_hors_ligne() {
        expectOnline(false, ["UITEST_GATEWAY": "none", "UITEST_ARMOIRE": "old"])
    }

    @MainActor func test_sans_gateway_ni_armoire_hors_ligne() {
        expectOnline(false, ["UITEST_GATEWAY": "none", "UITEST_ARMOIRE": "none"])
    }

    @MainActor func test_mode_LAN_commandes_actives() {
        let app = launch(["UITEST_MODE": "lan"])
        XCTAssertTrue(app.buttons["quick-2"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["quick-2"].isEnabled)
    }
}
