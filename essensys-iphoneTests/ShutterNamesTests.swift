import Foundation
import Testing
@testable import essensys_iphone

/// Noms personnalisés des volets et stores (noms-volets-2026-11-005, tâches 6.1 et 6.3, spec shutter-names-clients).
@MainActor struct ShutterNamesTests {
    private static let list = #"{"shutters":[{"id":"volet1salon","default":"Volet 1 Salon","name":"Volet baie vitrée","version":2,"updated_at":"2026-11-07T10:15:30.123Z"},{"id":"voletbureau","default":"Volet Bureau","name":null,"version":0,"updated_at":null},{"id":"voletstore","default":"Volet \"Store\"","name":"a&b <i>","version":1,"updated_at":"2026-11-07T10:15:30.123Z"}]}"#

    // MARK: lecture

    @Test func names_are_read_from_the_cloud_route() async {
        let t = TestBackend(token: "jwt")
        t.enqueue(200, Self.list)
        guard case let .success(shutters) = await t.container.comfort.readShutterNames() else { Issue.record("succès attendu"); return }
        #expect(t.requests.first?.path == "/api/portal/shutters/names")
        #expect(t.requests.first?.method == "GET")
        #expect(shutters.count == 3)
        #expect(shutters[0].displayName == "Volet baie vitrée")
        #expect(shutters[1].displayName == "Volet Bureau") // name null : nom d'origine
        #expect(shutters[1].version == 0)
        #expect(shutters[1].updatedAt == nil)
    }

    @Test func names_are_read_from_the_local_route_in_lan_mode() async {
        let t = TestBackend(mode: .lan)
        t.store.update { $0.lanCookie = "abc" }
        t.enqueue(200, Self.list)
        _ = await t.container.comfort.readShutterNames()
        #expect(t.requests.first?.path == "/api/shutters/names")
    }

    @Test func names_are_plain_text_and_kept_as_is() async {
        let t = TestBackend(token: "jwt")
        t.enqueue(200, Self.list)
        let model = ShutterNamesModel(comfort: t.container.comfort)
        await model.load()
        #expect(model.displayName(id: "voletstore") == "a&b <i>") // jamais interprété ni échappé
    }

    @Test func read_failure_falls_back_to_the_default_names() async {
        let t = TestBackend(token: "jwt")
        t.enqueue(503, #"{"error":"names_unavailable"}"#)
        let model = ShutterNamesModel(comfort: t.container.comfort)
        await model.load()
        #expect(!model.loaded)
        #expect(model.feedback == nil) // aucun message bloquant
        let salon = IndexTable.shutters.first { $0.id == "volet1salon" }!
        #expect(model.displayName(salon) == "Volet 1 Salon")
        #expect(model.displayName(id: "store") == "Store (banne)")
        #expect(model.displayName(id: "voletstore") == "Volet \"Store\"")
        #expect(model.displayName(id: "inconnu") == "inconnu")
    }

    @Test func custom_name_replaces_the_default_once_loaded() async {
        let t = TestBackend(token: "jwt")
        t.enqueue(200, Self.list)
        let model = ShutterNamesModel(comfort: t.container.comfort)
        await model.load()
        let salon = IndexTable.shutters.first { $0.id == "volet1salon" }!
        #expect(model.displayName(salon) == "Volet baie vitrée")
        #expect(model.displayName(id: "voletbureau") == "Volet Bureau")
    }

    // MARK: règle du nom

    @Test func name_rule_is_trimmed_1_to_40_without_controls_or_angle_brackets() {
        #expect(ShutterNameFormat.validate("  Volet baie vitrée  ") == "Volet baie vitrée")
        #expect(ShutterNameFormat.validate("é") == "é")
        #expect(ShutterNameFormat.validate(String(repeating: "a", count: 40)) != nil)
        #expect(ShutterNameFormat.validate(String(repeating: "a", count: 41)) == nil)
        for refused in ["", "   ", "a<b", "a>b", "a\u{07}b", "a\u{7F}b", "a\nb"] { #expect(ShutterNameFormat.validate(refused) == nil, "\(refused.debugDescription)") }
        #expect(ShutterNameFormat.validate("Store \"nord\"") == "Store \"nord\"")
        #expect(ShutterNameFormat.validate("a&b") == "a&b")
    }

    // MARK: écriture

    @Test func rename_is_a_put_on_the_admin_cloud_path() async {
        let t = TestBackend(token: "jwt")
        t.enqueue(200, #"{"id":"volet1salon","default":"Volet 1 Salon","name":"Volet baie vitrée","version":2,"updated_at":"2026-11-07T10:15:30.123Z","status":"saved"}"#)
        guard case let .success(reply) = await t.container.comfort.setShutterName(id: "volet1salon", name: " Volet baie vitrée ") else { Issue.record("succès attendu"); return }
        #expect(t.requests.first?.method == "PUT")
        #expect(t.requests.first?.path == "/api/portal/admin/shutters/names/volet1salon")
        #expect(t.requests.first?.body == #"{"name":"Volet baie vitrée"}"#)
        #expect(reply.shutter.displayName == "Volet baie vitrée")
        #expect(reply.status == "saved")
    }

    @Test func rename_is_a_put_on_the_admin_local_path_in_lan_mode() async {
        let t = TestBackend(mode: .lan)
        t.store.update { $0.lanCookie = "abc" }
        t.enqueue(200, #"{"id":"store","default":"Store (banne)","name":"Store terrasse","version":1,"updated_at":"2026-11-07T10:15:30.123Z","status":"saved"}"#)
        _ = await t.container.comfort.setShutterName(id: "store", name: "Store terrasse")
        #expect(t.requests.first?.path == "/api/admin/shutters/names/store")
    }

    @Test func original_name_sends_an_explicit_null() async {
        let t = TestBackend(token: "jwt")
        t.enqueue(200, #"{"id":"volet1salon","default":"Volet 1 Salon","name":null,"version":3,"updated_at":"2026-11-07T10:20:00.000Z","status":"saved"}"#)
        guard case let .success(reply) = await t.container.comfort.setShutterName(id: "volet1salon", name: nil) else { Issue.record("succès attendu"); return }
        #expect(t.requests.first?.body == #"{"name":null}"#)
        #expect(reply.shutter.displayName == "Volet 1 Salon")
    }

    @Test func dry_run_header_is_sent_in_test_mode() async {
        let t = TestBackend(token: "jwt", testMode: true)
        t.enqueue(200, #"{"id":"volet1salon","default":"Volet 1 Salon","name":null,"version":0,"updated_at":null,"status":"dry_run"}"#)
        let model = ShutterNamesModel(comfort: t.container.comfort)
        #expect(await model.rename("volet1salon", to: "Volet baie vitrée"))
        #expect(t.requests.first?.headers["X-Essensys-Test-Mode"] == "dry-run")
        #expect(model.feedback?.kind == .info)
        #expect(model.customName("volet1salon") == nil) // rien d'enregistré
    }

    @Test func invalid_names_never_reach_the_network() async {
        let t = TestBackend(token: "jwt")
        for bad in ["", "   ", String(repeating: "x", count: 41), "a<b", "a>b"] {
            guard case .failure(.invalidRequest) = await t.container.comfort.setShutterName(id: "volet1salon", name: bad) else {
                Issue.record("refus attendu pour \(bad)"); continue
            }
        }
        guard case .failure(.invalidRequest) = await t.container.comfort.setShutterName(id: "volet9", name: "ok") else { Issue.record("refus attendu"); return }
        let model = ShutterNamesModel(comfort: t.container.comfort)
        #expect(!(await model.rename("volet1salon", to: "")))
        #expect(model.feedback?.text == ShutterNameFormat.invalidMessage)
        #expect(t.requests.isEmpty)
    }

    @Test func error_messages_for_400_403_503_are_clear() async {
        let t = TestBackend(token: "jwt")
        let model = ShutterNamesModel(comfort: t.container.comfort)
        t.enqueue(400, #"{"error":"invalid_name"}"#)
        #expect(!(await model.rename("volet1salon", to: "Volet baie vitrée")))
        #expect(model.feedback?.text == ShutterNameFormat.invalidMessage)
        t.enqueue(400, #"{"error":"unknown_shutter"}"#)
        #expect(!(await model.rename("volet1salon", to: "Volet baie vitrée")))
        #expect(model.feedback?.text == "Volet inconnu.")
        t.enqueue(403, #"{"error":"forbidden"}"#)
        #expect(!(await model.rename("volet1salon", to: "Volet baie vitrée")))
        #expect(model.feedback?.text == "Réservé à l'administrateur de l'armoire.")
        t.enqueue(503, #"{"error":"names_unavailable"}"#)
        #expect(!(await model.rename("volet1salon", to: "Volet baie vitrée")))
        #expect(model.feedback?.text.contains("stockage indisponible") == true)
        #expect(model.feedback?.kind == .error)
        #expect(t.store.state.token == "jwt") // un 403 ne déconnecte pas
    }

    @Test func saved_name_is_shown_without_reload_and_original_name_restores_it() async {
        let t = TestBackend(token: "jwt")
        let model = ShutterNamesModel(comfort: t.container.comfort)
        t.enqueue(200, #"{"id":"store","default":"Store (banne)","name":"Store terrasse","version":1,"updated_at":"2026-11-07T10:15:30.123Z","status":"saved"}"#)
        #expect(await model.rename("store", to: "Store terrasse"))
        #expect(model.displayName(id: "store") == "Store terrasse")
        t.enqueue(200, #"{"id":"store","default":"Store (banne)","name":null,"version":2,"updated_at":"2026-11-07T10:16:00.000Z","status":"saved"}"#)
        #expect(await model.restoreDefault("store"))
        #expect(model.displayName(id: "store") == "Store (banne)")
        #expect(t.requests.map(\.method) == ["PUT", "PUT"]) // aucune relecture
    }

    // MARK: temps de course

    @Test func travel_time_messages_use_the_display_name() async {
        let t = TestBackend(token: "jwt", testMode: true)
        let model = ControlModel(control: t.container.control)
        let store = IndexTable.shutters.first { $0.id == "store" }!
        t.enqueue(200, #"{"status":"ok"}"#)
        #expect(model.saveTravelTime(store, raw: "90", name: "Store terrasse"))
        for _ in 0..<50 where model.feedback == nil { try? await Task.sleep(nanoseconds: 100_000_000) }
        #expect(model.feedback?.text.hasPrefix("Store terrasse : ") == true)
        #expect(!(model.saveTravelTime(store, raw: "999", name: "Store terrasse")))
        #expect(model.feedback?.text == "Store terrasse : entre 1 et 255 secondes")
    }

    // NR: NR-ios-26 essensys-hub/essensys-feature-lifecycle#41
    @Test func rename_never_orders_the_armoire_and_keeps_light_names_NR_ios_26() async {
        let t = TestBackend(token: "jwt")
        let model = ShutterNamesModel(comfort: t.container.comfort)
        t.enqueue(200, #"{"id":"volet1salon","default":"Volet 1 Salon","name":"Volet baie vitrée","version":1,"updated_at":"2026-11-07T10:15:30.123Z","status":"saved"}"#)
        t.enqueue(200, #"{"id":"volet1salon","default":"Volet 1 Salon","name":null,"version":2,"updated_at":"2026-11-07T10:16:00.000Z","status":"saved"}"#)
        _ = await model.rename("volet1salon", to: "Volet baie vitrée")
        _ = await model.restoreDefault("volet1salon")
        #expect(t.requests.allSatisfy { $0.path.contains("/shutters/names/") })
        #expect(!t.requests.contains { $0.path.contains("inject") || $0.path.contains("web/actions") || $0.path.contains("exchange") })
        // Table d'échange et noms d'origine intacts : mêmes commandes qu'avant, 16 volets.
        let salon = IndexTable.shutters.first { $0.id == "volet1salon" }!
        #expect(salon.name == "Volet 1 Salon")
        #expect(salon.command(open: true) == Injection(k: 617, v: "1"))
        #expect(salon.travelTimeIndex == 566)
        #expect(IndexTable.shutters.count == 16)
        // Les noms des lumières (#41) restent inchangés.
        let lights = LightNamesModel(comfort: t.container.comfort)
        #expect(lights.displayName(id: "dressing") == "Dressing")
        #expect(IndexTable.lights.count == 33)
    }
}
