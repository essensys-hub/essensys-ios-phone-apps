//
//  essensys_iphoneUITests.swift
//  essensys-iphoneUITests
//

import XCTest

/// Lancement de l'app sur simulateur (tâche 1.2) ; les parcours UI suivent par écran.
final class LaunchUITests: XCTestCase {
    @MainActor
    func test_app_launches() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["Essensys"].waitForExistence(timeout: 10))
    }
}
