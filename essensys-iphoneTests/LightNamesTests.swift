import Foundation
import Testing
@testable import essensys_iphone

/// Noms personnalisés des lumières (noms-lumieres-2026-11-004, tâches 8.1 et 8.3, spec light-names-clients).
@MainActor struct LightNamesTests {
    private static let list = #"{"lights":[{"id":"dressing","default":"Dressing","name":"WC 3","version":2,"updated_at":"2026-11-07T10:15:30.123Z"},{"id":"wc1","default":"WC 1","name":null,"version":0,"updated_at":null},{"id":"salon","default":"Salon","name":"a&b <i>","version":1,"updated_at":"2026-11-07T10:15:30.123Z"}]}"#

    // MARK: lecture

    @Test func names_are_read_from_the_cloud_route() async {
        let t = TestBackend(token: "jwt")
        t.enqueue(200, Self.list)
        guard case let .success(lights) = await t.container.comfort.readLightNames() else { Issue.record("succès attendu"); return }
        #expect(t.requests.first?.path == "/api/portal/lights/names")
        #expect(t.requests.first?.method == "GET")
        #expect(lights.count == 3)
        #expect(lights[0].displayName == "WC 3")
        #expect(lights[1].displayName == "WC 1") // name null : nom d'origine
        #expect(lights[1].version == 0)
        #expect(lights[1].updatedAt == nil)
    }

    @Test func names_are_read_from_the_local_route_in_lan_mode() async {
        let t = TestBackend(mode: .lan)
        t.store.update { $0.lanCookie = "abc" }
        t.enqueue(200, Self.list)
        _ = await t.container.comfort.readLightNames()
        #expect(t.requests.first?.path == "/api/lights/names")
    }

    @Test func names_are_plain_text_and_kept_as_is() async {
        let t = TestBackend(token: "jwt")
        t.enqueue(200, Self.list)
        let model = LightNamesModel(comfort: t.container.comfort)
        await model.load()
        #expect(model.displayName(id: "salon") == "a&b <i>") // jamais interprété ni échappé
    }

    @Test func read_failure_falls_back_to_the_default_names() async {
        let t = TestBackend(token: "jwt")
        t.enqueue(503, #"{"error":"names_unavailable"}"#)
        let model = LightNamesModel(comfort: t.container.comfort)
        await model.load()
        #expect(!model.loaded)
        #expect(model.feedback == nil) // aucun message bloquant
        let dressing = IndexTable.lights.first { $0.id == "dressing" }!
        #expect(model.displayName(dressing) == "Dressing")
        #expect(model.displayName(id: "idressing") == "Dressing (placards)")
        #expect(model.displayName(id: "inconnue") == "inconnue")
    }

    @Test func custom_name_replaces_the_default_once_loaded() async {
        let t = TestBackend(token: "jwt")
        t.enqueue(200, Self.list)
        let model = LightNamesModel(comfort: t.container.comfort)
        await model.load()
        let dressing = IndexTable.lights.first { $0.id == "dressing" }!
        #expect(model.displayName(dressing) == "WC 3")
        #expect(model.displayName(id: "wc1") == "WC 1")
    }

    // MARK: règle du nom

    @Test func name_rule_is_trimmed_1_to_40_without_controls_or_angle_brackets() {
        #expect(LightNameFormat.validate("  WC 3  ") == "WC 3")
        #expect(LightNameFormat.validate("é") == "é")
        #expect(LightNameFormat.validate(String(repeating: "a", count: 40)) != nil)
        #expect(LightNameFormat.validate(String(repeating: "a", count: 41)) == nil)
        for refused in ["", "   ", "a<b", "a>b", "a\u{07}b", "a\u{7F}b", "a\nb"] { #expect(LightNameFormat.validate(refused) == nil, "\(refused.debugDescription)") }
        #expect(LightNameFormat.validate("a&b") == "a&b")
    }

    // MARK: écriture

    @Test func rename_is_a_put_on_the_admin_cloud_path() async {
        let t = TestBackend(token: "jwt")
        t.enqueue(200, #"{"id":"dressing","default":"Dressing","name":"WC 3","version":2,"updated_at":"2026-11-07T10:15:30.123Z","status":"saved"}"#)
        guard case let .success(reply) = await t.container.comfort.setLightName(id: "dressing", name: " WC 3 ") else { Issue.record("succès attendu"); return }
        #expect(t.requests.first?.method == "PUT")
        #expect(t.requests.first?.path == "/api/portal/admin/lights/names/dressing")
        #expect(t.requests.first?.body == #"{"name":"WC 3"}"#)
        #expect(reply.light.displayName == "WC 3")
        #expect(reply.status == "saved")
    }

    @Test func rename_is_a_put_on_the_admin_local_path_in_lan_mode() async {
        let t = TestBackend(mode: .lan)
        t.store.update { $0.lanCookie = "abc" }
        t.enqueue(200, #"{"id":"wc1","default":"WC 1","name":"WC Haut","version":1,"updated_at":"2026-11-07T10:15:30.123Z","status":"saved"}"#)
        _ = await t.container.comfort.setLightName(id: "wc1", name: "WC Haut")
        #expect(t.requests.first?.path == "/api/admin/lights/names/wc1")
    }

    @Test func original_name_sends_an_explicit_null() async {
        let t = TestBackend(token: "jwt")
        t.enqueue(200, #"{"id":"dressing","default":"Dressing","name":null,"version":3,"updated_at":"2026-11-07T10:20:00.000Z","status":"saved"}"#)
        guard case let .success(reply) = await t.container.comfort.setLightName(id: "dressing", name: nil) else { Issue.record("succès attendu"); return }
        #expect(t.requests.first?.body == #"{"name":null}"#)
        #expect(reply.light.displayName == "Dressing")
    }

    @Test func dry_run_header_is_sent_in_test_mode() async {
        let t = TestBackend(token: "jwt", testMode: true)
        t.enqueue(200, #"{"id":"dressing","default":"Dressing","name":null,"version":0,"updated_at":null,"status":"dry_run"}"#)
        let model = LightNamesModel(comfort: t.container.comfort)
        #expect(await model.rename("dressing", to: "WC 3"))
        #expect(t.requests.first?.headers["X-Essensys-Test-Mode"] == "dry-run")
        #expect(model.feedback?.kind == .info)
        #expect(model.customName("dressing") == nil) // rien d'enregistré
    }

    @Test func invalid_names_never_reach_the_network() async {
        let t = TestBackend(token: "jwt")
        for bad in ["", "   ", String(repeating: "x", count: 41), "a<b", "a>b"] {
            guard case .failure(.invalidRequest) = await t.container.comfort.setLightName(id: "dressing", name: bad) else {
                Issue.record("refus attendu pour \(bad)"); continue
            }
        }
        guard case .failure(.invalidRequest) = await t.container.comfort.setLightName(id: "salon1", name: "ok") else { Issue.record("refus attendu"); return }
        let model = LightNamesModel(comfort: t.container.comfort)
        #expect(!(await model.rename("dressing", to: "")))
        #expect(model.feedback?.text == LightNameFormat.invalidMessage)
        #expect(t.requests.isEmpty)
    }

    @Test func error_messages_for_400_403_503_are_clear() async {
        let t = TestBackend(token: "jwt")
        let model = LightNamesModel(comfort: t.container.comfort)
        t.enqueue(400, #"{"error":"invalid_name"}"#)
        #expect(!(await model.rename("dressing", to: "WC 3")))
        #expect(model.feedback?.text == LightNameFormat.invalidMessage)
        t.enqueue(400, #"{"error":"unknown_light"}"#)
        #expect(!(await model.rename("dressing", to: "WC 3")))
        #expect(model.feedback?.text == "Lumière inconnue.")
        t.enqueue(403, #"{"error":"forbidden"}"#)
        #expect(!(await model.rename("dressing", to: "WC 3")))
        #expect(model.feedback?.text == "Réservé à l'administrateur de l'armoire.")
        t.enqueue(503, #"{"error":"names_unavailable"}"#)
        #expect(!(await model.rename("dressing", to: "WC 3")))
        #expect(model.feedback?.text.contains("stockage indisponible") == true)
        #expect(model.feedback?.kind == .error)
        #expect(t.store.state.token == "jwt") // un 403 ne déconnecte pas
    }

    @Test func saved_name_is_shown_without_reload_and_original_name_restores_it() async {
        let t = TestBackend(token: "jwt")
        let model = LightNamesModel(comfort: t.container.comfort)
        t.enqueue(200, #"{"id":"dressing","default":"Dressing","name":"WC 3","version":1,"updated_at":"2026-11-07T10:15:30.123Z","status":"saved"}"#)
        #expect(await model.rename("dressing", to: "WC 3"))
        #expect(model.displayName(id: "dressing") == "WC 3")
        t.enqueue(200, #"{"id":"dressing","default":"Dressing","name":null,"version":2,"updated_at":"2026-11-07T10:16:00.000Z","status":"saved"}"#)
        #expect(await model.restoreDefault("dressing"))
        #expect(model.displayName(id: "dressing") == "Dressing")
        #expect(t.requests.map(\.method) == ["PUT", "PUT"]) // aucune relecture
    }

    // MARK: scénarios

    @Test func scenario_bits_map_to_the_catalogue_lights() {
        #expect(IndexTable.light(metaIndex: 605, bitValue: 2)?.id == "isalonind")
        #expect(IndexTable.light(metaIndex: 611, bitValue: 1)?.id == "entree")
        #expect(IndexTable.light(metaIndex: 617, bitValue: 32) == nil) // volet
        // (indice, masque) désigne au plus une lumière, en allumage comme en extinction.
        var seen = Set<String>()
        for light in IndexTable.lights {
            for index in [light.onIndex, light.offIndex] {
                #expect(seen.insert("\(index)/\(light.mask)").inserted || IndexTable.light(metaIndex: index, bitValue: light.mask)?.id == light.id)
                #expect(IndexTable.light(metaIndex: index, bitValue: light.mask)?.id == light.id, "\(light.id)")
            }
        }
    }

    // NR: NR-ios-25 essensys-hub/essensys-feature-lifecycle#41
    @Test func rename_never_orders_the_armoire_NR_ios_25() async {
        let t = TestBackend(token: "jwt")
        let model = LightNamesModel(comfort: t.container.comfort)
        t.enqueue(200, #"{"id":"dressing","default":"Dressing","name":"WC 3","version":1,"updated_at":"2026-11-07T10:15:30.123Z","status":"saved"}"#)
        t.enqueue(200, #"{"id":"dressing","default":"Dressing","name":null,"version":2,"updated_at":"2026-11-07T10:16:00.000Z","status":"saved"}"#)
        _ = await model.rename("dressing", to: "WC 3")
        _ = await model.restoreDefault("dressing")
        #expect(t.requests.allSatisfy { $0.path.contains("/lights/names/") })
        #expect(!t.requests.contains { $0.path.contains("inject") || $0.path.contains("web/actions") || $0.path.contains("exchange") })
        // Le catalogue d'indices (table d'échange) n'est pas touché par les noms : mêmes commandes qu'avant.
        #expect(IndexTable.lights.first { $0.id == "dressing" }?.command(on: true) == Injection(k: 611, v: "8"))
        #expect(IndexTable.lights.count == 33)
    }
}
