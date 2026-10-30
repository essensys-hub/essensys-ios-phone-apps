//
//  ParityUITests.swift
//  Écrans v2.1.0 (Chauffage, Scénarios, Chauffe-eau, Arrosage, Alarme, Accueil, Réglages) sur simulateur,
//  contre le backend simulé embarqué : aucune armoire réelle (spec parity-quality « Tests applicatifs »).
//  Jumeaux de HeatingFlowTest, ScenariosFlowTest, ComfortFlowTest et HomeFlowTest (Android).
//

import XCTest

final class ParityUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launch(_ env: [String: String] = [:]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment = ["UITEST_BACKEND": "1", "UITEST_TOKEN": "1"].merging(env) { $1 }
        app.launch()
        return app
    }

    private func screenshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
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

    /// Fait défiler jusqu'à l'élément puis le touche.
    private func tap(_ app: XCUIApplication, _ element: XCUIElement) {
        XCTAssertTrue(element.waitForExistence(timeout: 5), "\(element)")
        var tries = 0
        while !element.isHittable && tries < 8 { app.swipeUp(); tries += 1 }
        element.tap()
    }

    private func openHome(_ app: XCUIApplication) {
        XCTAssertTrue(app.buttons["quick-2"].waitForExistence(timeout: 10))
    }

    // MARK: Accueil et navigation (spec home-dashboard)

    @MainActor func test_five_tabs_and_home_tiles_without_coming_soon() {
        let app = launch()
        openHome(app)
        XCTAssertEqual(app.tabBars.buttons.allElementsBoundByIndex.map(\.label), ["Accueil", "Éclairage", "Volets", "Chauffage", "Réglages"])
        XCTAssertFalse(app.staticTexts["Bientôt disponible"].exists)
        screenshot(app, "02-home-light")
        for id in ["open-lighting", "open-shutters", "open-heating", "open-SCENARIOS", "open-WATER_HEATER", "open-SPRINKLER", "open-ALARM"] {
            XCTAssertTrue(app.buttons[id].exists, id)
        }
    }

    /// #27 : la version apparaît sous le bandeau, sur chaque onglet et sur les écrans poussés.
    @MainActor func test_app_version_visible_on_every_screen() {
        let app = launch()
        openHome(app)
        let version = app.staticTexts["app-version"]
        XCTAssertTrue(version.waitForExistence(timeout: 5))
        let label = version.label
        XCTAssertTrue(label.range(of: #"^Version \d+\.\d+\.\d+"#, options: .regularExpression) != nil, label)
        for tab in ["Éclairage", "Volets", "Chauffage", "Réglages", "Accueil"] {
            app.tabBars.buttons[tab].tap()
            XCTAssertTrue(version.waitForExistence(timeout: 5), tab)
            XCTAssertEqual(version.label, label, tab)
        }
        tap(app, app.buttons["open-SCENARIOS"])
        XCTAssertEqual(version.label, label)
        screenshot(app, "app-version-scenarios")
    }

    @MainActor func test_tile_opens_pushed_screen_and_back_returns_home() {
        let app = launch()
        openHome(app)
        tap(app, app.buttons["open-WATER_HEATER"])
        XCTAssertTrue(app.buttons["heater-OFF"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["quick-2"].waitForExistence(timeout: 5))
        tap(app, app.buttons["open-heating"])
        XCTAssertTrue(app.buttons["zone-jour"].waitForExistence(timeout: 5))
    }

    @MainActor func test_quick_scenario_launches_in_one_tap() {
        let app = launch()
        openHome(app)
        app.buttons["quick-2"].tap()
        XCTAssertTrue(waitFor { !self.log(app, "uitest-mutations").isEmpty })
        XCTAssertEqual(log(app, "uitest-mutations").first?.hasPrefix("POST /api/portal/scenarios/2/launch"), true)
    }

    @MainActor func test_offline_disables_quick_scenarios_but_tiles_stay_open() {
        let app = launch(["UITEST_ONLINE": "0"])
        openHome(app)
        XCTAssertTrue(app.staticTexts["Armoire hors ligne"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["quick-2"].isEnabled)
        tap(app, app.buttons["open-SPRINKLER"])
        XCTAssertTrue(app.buttons["sprinkler-AUTO"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["sprinkler-AUTO"].isEnabled)
    }

    @MainActor func test_settings_show_account_and_armoire_in_cloud() {
        let app = launch(["UITEST_THEME": "dark"])
        openHome(app)
        app.tabBars.buttons["Réglages"].tap()
        XCTAssertTrue(app.staticTexts["account-armoire"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["account-user"].label, "Camille Démo — demo@essensys.fr")
        XCTAssertTrue(app.staticTexts["account-armoire"].label.contains("SC944D-0001"))
        screenshot(app, "10-settings-account-dark")
    }

    // MARK: Chauffage (spec heating-control)

    @MainActor func test_heating_edit_slot_then_save_sends_expected_batch() {
        let app = launch()
        openHome(app)
        app.tabBars.buttons["Chauffage"].tap()
        XCTAssertTrue(app.buttons["hour-6"].waitForExistence(timeout: 5))
        tap(app, app.buttons["day-0"])
        tap(app, app.buttons["brush-CONFORT"])
        tap(app, app.buttons["hour-6"])
        tap(app, app.buttons["brush-ECO"])
        tap(app, app.buttons["hour-7"])
        XCTAssertTrue(app.staticTexts["heating-pending"].waitForExistence(timeout: 5))
        screenshot(app, "09-heating-light")
        tap(app, app.buttons["heating-save"])
        XCTAssertTrue(waitFor { !self.log(app, "uitest-injections").isEmpty })
        XCTAssertEqual(log(app, "uitest-injections"), [#"{"params":[{"k":16,"v":"33"}]}"#])
    }

    @MainActor func test_heating_failed_save_keeps_changes_for_retry() {
        let app = launch(["UITEST_FAIL_FIRST_INJECT": "1"])
        openHome(app)
        app.tabBars.buttons["Chauffage"].tap()
        tap(app, app.buttons["hour-10"])
        tap(app, app.buttons["heating-save"])
        XCTAssertTrue(waitFor { self.log(app, "uitest-injections").count == 1 })
        XCTAssertTrue(app.staticTexts["heating-pending"].waitForExistence(timeout: 5))
        tap(app, app.buttons["heating-save"])
        XCTAssertTrue(waitFor { self.log(app, "uitest-injections").count == 2 })
        XCTAssertEqual(log(app, "uitest-injections")[0], log(app, "uitest-injections")[1])
    }

    // Spec : forçage confort en salle de bain 1 = k=351, v="17" ; Anticipé absent des salles de bain.
    @MainActor func test_heating_immediate_mode_for_bathroom() {
        let app = launch()
        openHome(app)
        app.tabBars.buttons["Chauffage"].tap()
        tap(app, app.buttons["zone-sdb1"])
        XCTAssertTrue(app.buttons["mode-FORCE_CONFORT"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["mode-ANTICIPATED"].exists)
        tap(app, app.buttons["mode-FORCE_CONFORT"])
        XCTAssertTrue(waitFor { !self.log(app, "uitest-injections").isEmpty })
        XCTAssertEqual(log(app, "uitest-injections"), [#"{"k":351,"v":"17"}"#])
    }

    @MainActor func test_heating_renders_in_dark_theme() {
        let schedule = (13...96).map { "\($0)=18" }.joined(separator: ",")
        let app = launch(["UITEST_THEME": "dark", "UITEST_EXCHANGE": schedule])
        openHome(app)
        app.tabBars.buttons["Chauffage"].tap()
        XCTAssertTrue(app.buttons["hour-0"].waitForExistence(timeout: 5))
        XCTAssertTrue(waitFor { app.buttons["hour-0"].label.contains("Éco") })
        screenshot(app, "13-heating-dark")
    }

    @MainActor func test_heating_lan_sync_rereads_schedule() {
        let app = launch(["UITEST_MODE": "lan", "UITEST_EXCHANGE": "13=33"])
        XCTAssertTrue(app.tabBars.buttons["Chauffage"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Chauffage"].tap()
        tap(app, app.buttons["heating-sync"])
        XCTAssertTrue(app.staticTexts["Planning relu depuis l'armoire"].waitForExistence(timeout: 10))
    }

    // MARK: Scénarios (spec scenarios)

    @MainActor func test_scenario_restore_requires_confirmation_then_launch_and_edit() {
        let app = launch()
        openHome(app)
        tap(app, app.buttons["open-SCENARIOS"])
        XCTAssertTrue(app.buttons["launch-2"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Dernier lancé"].exists)
        screenshot(app, "11-scenarios-light")
        // Réglages d'usine : annuler n'envoie rien.
        tap(app, app.buttons["restore-4"])
        app.alerts.buttons["Annuler"].firstMatch.tap()
        XCTAssertTrue(log(app, "uitest-mutations").isEmpty)
        tap(app, app.buttons["restore-4"])
        app.alerts.buttons["Remettre"].firstMatch.tap()
        XCTAssertTrue(waitFor { self.log(app, "uitest-mutations").count == 1 })
        XCTAssertEqual(log(app, "uitest-mutations").first?.hasPrefix("POST /api/portal/scenarios/4/restore"), true)
        XCTAssertFalse(app.buttons["restore-7"].exists)
        // Édition : la case « Salon 1 » (méta 605) est enregistrée à l'indice 728 du scénario 4.
        app.swipeDown(); app.swipeDown(); app.swipeDown()
        tap(app, app.buttons["edit-4"])
        let bit = app.switches["bit-605-2"]
        XCTAssertTrue(bit.waitForExistence(timeout: 5))
        bit.switches.firstMatch.exists ? bit.switches.firstMatch.tap() : bit.tap()
        tap(app, app.buttons["editor-save"])
        XCTAssertTrue(waitFor { self.log(app, "uitest-mutations").count == 2 })
        let put = log(app, "uitest-mutations")[1]
        XCTAssertTrue(put.hasPrefix("PUT /api/portal/scenarios/4 "), put)
        XCTAssertTrue(put.contains(#""728":"2""#), put)
        XCTAssertFalse(put.contains(#""605""#), put)
    }

    // MARK: Temps de course des volets (spec shutter-travel-time)

    @MainActor func test_travel_time_is_sent_then_displayed_and_out_of_range_refused() {
        let app = launch()
        openHome(app)
        app.tabBars.buttons["Volets"].tap()
        let current = app.staticTexts["time-current-volet1salon"]
        XCTAssertTrue(current.waitForExistence(timeout: 10))
        XCTAssertTrue(waitFor { current.label == "Actuel : 25 s" })
        XCTAssertEqual(app.staticTexts["time-current-volet2salon"].label, "Non transmis (défaut usine : 120 s, store : 255 s)")
        let field = app.textFields["time-input-volet1salon"]
        tap(app, field)
        field.typeText("300")
        tap(app, app.buttons["time-save-volet1salon"])
        XCTAssertTrue(app.staticTexts["Volet 1 Salon : entre 1 et 255 secondes"].waitForExistence(timeout: 5))
        XCTAssertTrue(log(app, "uitest-injections").isEmpty)
        tap(app, field)
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 3) + "30")
        tap(app, app.buttons["time-save-volet1salon"])
        XCTAssertTrue(waitFor { !self.log(app, "uitest-injections").isEmpty })
        XCTAssertEqual(log(app, "uitest-injections"), [#"{"k":566,"v":"30"}"#])
        XCTAssertTrue(waitFor { current.label == "Actuel : 30 s" })
        screenshot(app, "14-shutters-travel-time-light")
    }

    @MainActor func test_offline_disables_travel_time_save() {
        let app = launch(["UITEST_ONLINE": "0"])
        openHome(app)
        XCTAssertTrue(app.staticTexts["Armoire hors ligne"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Volets"].tap()
        let field = app.textFields["time-input-volet1salon"]
        tap(app, field)
        field.typeText("30")
        XCTAssertFalse(app.buttons["time-save-volet1salon"].isEnabled)
    }

    // MARK: Chauffe-eau, arrosage, alarme (specs comfort-controls, alarm-control)

    @MainActor func test_sprinkler_uses_firmware_index_363_and_water_heater_353() {
        let app = launch(["UITEST_EXCHANGE": "353=2"])
        openHome(app)
        tap(app, app.buttons["open-WATER_HEATER"])
        XCTAssertTrue(app.buttons["heater-OFF_PEAK"].waitForExistence(timeout: 5))
        screenshot(app, "12-water-heater-light")
        app.buttons["heater-OFF_PEAK"].tap()
        XCTAssertTrue(waitFor { !self.log(app, "uitest-injections").isEmpty })
        app.navigationBars.buttons.element(boundBy: 0).tap()
        tap(app, app.buttons["open-SPRINKLER"])
        tap(app, app.buttons["sprinkler-MINUTES_30"])
        XCTAssertTrue(waitFor { self.log(app, "uitest-injections").count == 2 })
        XCTAssertEqual(log(app, "uitest-injections"), [#"{"k":353,"v":"1"}"#, #"{"k":363,"v":"30"}"#])
    }

    @MainActor func test_alarm_on_sends_code_once_then_clears_field_and_off_needs_confirmation() {
        let app = launch()
        openHome(app)
        tap(app, app.buttons["open-ALARM"])
        let field = app.secureTextFields["alarm-code"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["alarm-on"].isEnabled)
        field.tap(); field.typeText("1234")
        app.buttons["alarm-on"].tap()
        XCTAssertTrue(waitFor { self.log(app, "uitest-mutations").count == 1 })
        XCTAssertEqual(log(app, "uitest-mutations").first, #"POST /api/portal/web/actions {"alarme":"on","codealarme":"1234"}"#)
        XCTAssertFalse(app.buttons["alarm-on"].isEnabled) // champ vidé après envoi
        field.tap(); field.typeText("4321")
        app.buttons["alarm-off"].tap()
        app.alerts.buttons["Annuler"].firstMatch.tap()
        XCTAssertEqual(log(app, "uitest-mutations").count, 1)
        app.buttons["alarm-off"].tap()
        app.alerts.buttons["Arrêter"].firstMatch.tap()
        XCTAssertTrue(waitFor { self.log(app, "uitest-mutations").count == 2 })
        XCTAssertEqual(log(app, "uitest-mutations")[1], #"POST /api/portal/web/actions {"alarme":"off","codealarme":"4321"}"#)
    }

    @MainActor func test_alarm_is_cloud_only_in_lan() {
        let app = launch(["UITEST_MODE": "lan"])
        XCTAssertTrue(app.buttons["open-ALARM"].waitForExistence(timeout: 10))
        tap(app, app.buttons["open-ALARM"])
        XCTAssertTrue(app.staticTexts["alarm-cloud-only"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.secureTextFields["alarm-code"].exists)
    }
}
