//
//  ObjectLayoutUITests.swift
//  Affichage des lumières et des volets (spec object-layout-clients) sur simulateur, contre le backend simulé
//  embarqué : aucune armoire réelle. Feature affichage-objets-2026-11-006, tâches 6.2 et 6.3 (NR-ios-27).
//

import XCTest

final class ObjectLayoutUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launch(_ env: [String: String] = [:]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment = ["UITEST_BACKEND": "1", "UITEST_TOKEN": "1", "UITEST_EXCHANGE": "566=90"].merging(env) { $1 }
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
        while !element.isHittable && tries < 12 { app.swipeUp(); tries += 1 }
        element.tap()
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func openLights(_ env: [String: String] = [:]) -> XCUIApplication {
        let app = launch(env)
        app.tabBars.buttons["Éclairage"].tap()
        XCTAssertTrue(app.buttons["light-salon-primary"].waitForExistence(timeout: 5) || app.staticTexts["group-main-empty"].waitForExistence(timeout: 5))
        return app
    }

    private func openShutters(_ env: [String: String] = [:]) -> XCUIApplication {
        let app = launch(env)
        app.tabBars.buttons["Volets"].tap()
        XCTAssertTrue(app.buttons["shutter-volet1salon-primary"].waitForExistence(timeout: 5) || app.staticTexts["group-main-empty"].waitForExistence(timeout: 5))
        return app
    }

    private func openTimers(_ env: [String: String] = [:]) -> XCUIApplication {
        let app = launch(env)
        tap(app, app.buttons["open-LIGHT_TIMERS"])
        XCTAssertTrue(app.staticTexts["timer-menu-dressing-current"].waitForExistence(timeout: 5) || app.staticTexts["timer-menu-ann1-current"].waitForExistence(timeout: 2))
        return app
    }

    /// Position verticale d'un élément (ordre d'affichage dans la liste).
    private func y(_ element: XCUIElement) -> CGFloat { element.frame.minY }

    // MARK: lumières désactivées

    @MainActor func test_lumiere_desactivee_absente_de_la_liste_du_groupe_et_des_temporisations() {
        let layout = ["UITEST_LIGHT_LAYOUT": "disabled=wc2"]
        let app = openLights(layout)
        XCTAssertTrue(app.staticTexts["WC 1"].exists)
        XCTAssertFalse(app.staticTexts["WC 2"].exists)
        XCTAssertFalse(app.buttons["light-wc2-primary"].exists)
        attach(app, "30-layout-light-disabled")
        // Tout allumer : 20 commandes, aucune pour wc2 (index 615, masque 64).
        tap(app, app.buttons["group-main-all-on"])
        XCTAssertTrue(waitFor { !self.log(app, "uitest-injections").isEmpty })
        let body = log(app, "uitest-injections").joined()
        XCTAssertEqual(body.components(separatedBy: #"{"k":"#).count - 1, 20)
        XCTAssertFalse(body.contains(#"{"k":615,"v":"64"}"#))
        XCTAssertTrue(body.contains(#"{"k":615,"v":"128"}"#)) // pieceserv, même index, autre masque
        // Écran Temporisations : « WC 2 » n'y est pas non plus.
        app.tabBars.buttons["Accueil"].tap()
        tap(app, app.buttons["open-LIGHT_TIMERS"])
        XCTAssertTrue(app.staticTexts["timer-menu-wc1-current"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["timer-menu-wc2-current"].exists)
        XCTAssertTrue(app.staticTexts["timer-menu-dressing-current"].exists)
        attach(app, "31-layout-timers-without-wc2")
    }

    @MainActor func test_tout_desactive_affiche_le_texte_sans_bouton_de_groupe() {
        let main = "terrasse,entree,escalier,deg1,deg2,pieceserv,ann1,ann2,salon,sam,cuisine,sdb1,sdb2,wc1,wc2,bureau,gdchamb,ptchamb1,ptchamb2,ptchamb3,dressing"
        let app = openLights(["UITEST_LIGHT_LAYOUT": "disabled=\(main)"])
        XCTAssertTrue(app.staticTexts["group-main-empty"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["group-main-empty"].label, "Aucune lumière activée")
        XCTAssertFalse(app.buttons["group-main-all-on"].exists)
        XCTAssertTrue(app.buttons["group-indirect-all-on"].exists) // l'autre groupe reste complet
        attach(app, "32-layout-all-disabled")
    }

    @MainActor func test_ordre_applique_dans_le_groupe_sans_changer_de_groupe() {
        let app = openLights(["UITEST_LIGHT_LAYOUT": "order=isalonind,sam,salon"])
        let sam = app.buttons["light-sam-primary"], salon = app.buttons["light-salon-primary"]
        XCTAssertTrue(sam.waitForExistence(timeout: 5))
        XCTAssertLessThan(y(sam), y(salon))
        // `isalonind` reste dans le groupe indirect, en tête.
        XCTAssertTrue(app.buttons["light-isalonind-primary"].exists)
        XCTAssertLessThan(y(salon), y(app.buttons["light-isalonind-primary"]))
    }

    // MARK: volets

    @MainActor func test_volet_desactive_absent_de_la_liste_du_groupe_et_du_temps_de_course() {
        let app = openShutters(["UITEST_SHUTTER_LAYOUT": "order=volet2salon,volet1salon;disabled=voletbureau"])
        XCTAssertFalse(app.buttons["shutter-voletbureau-primary"].exists)
        XCTAssertLessThan(y(app.buttons["shutter-volet2salon-primary"]), y(app.buttons["shutter-volet1salon-primary"]))
        attach(app, "33-layout-shutters")
        tap(app, app.buttons["group-main-all-on"])
        XCTAssertTrue(waitFor { !self.log(app, "uitest-injections").isEmpty })
        let body = log(app, "uitest-injections").joined()
        XCTAssertEqual(body.components(separatedBy: #"{"k":"#).count - 1, 13)
        let time = app.staticTexts["time-name-volet1salon"]
        tap(app, time)
        XCTAssertTrue(time.exists)
        XCTAssertFalse(app.staticTexts["time-name-voletbureau"].exists)
        XCTAssertLessThan(y(app.staticTexts["time-name-volet2salon"]), y(time)) // l'ordre suit aussi « Temps de course »
        attach(app, "34-layout-travel-time")
    }

    @MainActor func test_ancien_serveur_404_affiche_tout_le_catalogue_sans_message() {
        let app = openLights(["UITEST_LAYOUT_READ": "404", "UITEST_LIGHT_LAYOUT": "disabled=wc2"])
        usleep(800_000)
        XCTAssertTrue(app.staticTexts["WC 2"].exists)
        XCTAssertFalse(app.alerts.firstMatch.exists)
    }

    // MARK: écran de gestion

    @MainActor func test_l_administrateur_reactive_une_lumiere_et_enregistre_en_une_ecriture() {
        let app = openLights(["UITEST_LIGHT_LAYOUT": "disabled=wc2"])
        XCTAssertFalse(app.staticTexts["WC 2"].exists)
        tap(app, app.buttons["lights-layout-open"])
        let toggle = app.switches["layout-lights-wc2-toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertEqual(toggle.value as? String, "0") // la lumière désactivée est listée, désactivée
        attach(app, "35-layout-manager-lights")
        tap(app, toggle)
        tap(app, app.buttons["layout-lights-save"])
        XCTAssertTrue(waitFor { self.log(app, "uitest-mutations").count == 1 })
        let put = log(app, "uitest-mutations")[0]
        XCTAssertTrue(put.hasPrefix("PUT /api/portal/admin/lights/layout "), put)
        XCTAssertTrue(put.contains(#""disabled":[]"#), put)
        XCTAssertTrue(app.staticTexts["WC 2"].waitForExistence(timeout: 5)) // revenue dans la liste
        XCTAssertTrue(log(app, "uitest-injections").isEmpty) // NR-ios-27 : aucun ordre vers l'armoire
    }

    @MainActor func test_monter_echange_avec_le_voisin_du_meme_groupe() {
        let app = openLights()
        tap(app, app.buttons["lights-layout-open"])
        tap(app, app.buttons["layout-lights-sam-up"])
        tap(app, app.buttons["layout-lights-save"])
        XCTAssertTrue(waitFor { self.log(app, "uitest-mutations").count == 1 })
        XCTAssertTrue(waitFor { app.buttons["light-sam-primary"].exists })
        XCTAssertLessThan(y(app.buttons["light-sam-primary"]), y(app.buttons["light-salon-primary"]))
    }

    @MainActor func test_ordre_d_origine_envoie_reset() {
        let app = openLights(["UITEST_LIGHT_LAYOUT": "order=sam,salon;disabled=wc2"])
        tap(app, app.buttons["lights-layout-open"])
        tap(app, app.buttons["layout-lights-reset"])
        tap(app, app.buttons["layout-lights-save"])
        XCTAssertTrue(waitFor { self.log(app, "uitest-mutations").count == 1 })
        XCTAssertEqual(log(app, "uitest-mutations"), [#"PUT /api/portal/admin/lights/layout {"reset":true}"#])
        XCTAssertTrue(app.staticTexts["WC 2"].waitForExistence(timeout: 5))
        XCTAssertLessThan(y(app.buttons["light-salon-primary"]), y(app.buttons["light-sam-primary"]))
    }

    @MainActor func test_volets_gestion_cloud_puis_mode_local() {
        let app = openShutters()
        tap(app, app.buttons["shutters-layout-open"])
        tap(app, app.switches["layout-shutters-voletbureau-toggle"])
        tap(app, app.buttons["layout-shutters-save"])
        XCTAssertTrue(waitFor { self.log(app, "uitest-mutations").count == 1 })
        XCTAssertTrue(log(app, "uitest-mutations")[0].hasPrefix("PUT /api/portal/admin/shutters/layout "))
        XCTAssertTrue(waitFor { !app.buttons["shutter-voletbureau-primary"].exists })
    }

    @MainActor func test_mode_local_ecrit_sur_la_route_locale() {
        let app = openShutters(["UITEST_MODE": "lan", "UITEST_ROLE": "lan_admin"])
        tap(app, app.buttons["shutters-layout-open"])
        tap(app, app.switches["layout-shutters-store-toggle"])
        tap(app, app.buttons["layout-shutters-save"])
        XCTAssertTrue(waitFor { self.log(app, "uitest-mutations").count == 1 })
        XCTAssertTrue(log(app, "uitest-mutations")[0].hasPrefix("PUT /api/admin/shutters/layout "))
    }

    @MainActor func test_erreur_503_laisse_l_ecran_ouvert_avec_un_message_clair() {
        let app = openLights(["UITEST_LAYOUT_WRITE": "503"])
        tap(app, app.buttons["lights-layout-open"])
        tap(app, app.switches["layout-lights-wc2-toggle"])
        tap(app, app.buttons["layout-lights-save"])
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'stockage indisponible'")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["layout-lights-save"].exists) // l'écran reste ouvert avec les modifications
        XCTAssertEqual(app.switches["layout-lights-wc2-toggle"].value as? String, "0")
    }

    @MainActor func test_erreur_403_affiche_un_message_clair() {
        let app = openLights(["UITEST_LAYOUT_WRITE": "403"])
        tap(app, app.buttons["lights-layout-open"])
        tap(app, app.switches["layout-lights-wc2-toggle"])
        tap(app, app.buttons["layout-lights-save"])
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Réservé à l'administrateur")).firstMatch.waitForExistence(timeout: 5))
    }

    @MainActor func test_utilisateur_simple_sans_ecran_de_gestion_ni_objets_desactives() {
        let app = openLights(["UITEST_ROLE": "guest_local", "UITEST_LIGHT_LAYOUT": "disabled=wc2"])
        usleep(800_000)
        XCTAssertFalse(app.buttons["lights-layout-open"].exists)
        XCTAssertFalse(app.staticTexts["WC 2"].exists)
        XCTAssertTrue(app.staticTexts["WC 1"].exists)
    }

    /// iPhone SE : un nom de 40 caractères ne masque ni l'interrupteur ni les boutons Monter/Descendre.
    @MainActor func test_nom_de_40_caracteres_reste_lisible_dans_l_ecran_de_gestion() {
        let name = String("Lumière très longue du couloir nord xxxxxxxxxxxxx".prefix(40))
        XCTAssertEqual(name.count, 40)
        let app = openLights(["UITEST_LIGHT_NAMES": "salon=\(name)"])
        tap(app, app.buttons["lights-layout-open"])
        let label = app.staticTexts["layout-lights-salon-name"]
        XCTAssertTrue(label.waitForExistence(timeout: 5))
        XCTAssertEqual(label.label, name)
        XCTAssertTrue(app.switches["layout-lights-salon-toggle"].isHittable)
        XCTAssertTrue(app.buttons["layout-lights-salon-down"].isHittable)
        XCTAssertTrue(app.buttons["layout-lights-salon-up"].exists)
        // Le nom ne déborde pas sur l'interrupteur.
        XCTAssertLessThanOrEqual(label.frame.maxX, app.switches["layout-lights-salon-toggle"].frame.minX + 1)
        attach(app, "36-layout-manager-name-40")
    }

    // NR-ios-27 : aucune écriture dans l'armoire, noms et indices inchangés.
    @MainActor func test_NR_ios_27_aucun_ordre_vers_l_armoire_et_noms_conserves() {
        let app = openLights(["UITEST_LIGHT_NAMES": "dressing=WC 3", "UITEST_LIGHT_LAYOUT": "order=dressing"])
        XCTAssertTrue(app.staticTexts["WC 3"].waitForExistence(timeout: 5))
        XCTAssertLessThan(y(app.buttons["light-dressing-primary"]), y(app.buttons["light-salon-primary"]))
        usleep(500_000)
        XCTAssertTrue(log(app, "uitest-injections").isEmpty)
        XCTAssertTrue(log(app, "uitest-mutations").isEmpty)
    }
}
