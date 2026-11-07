import Foundation
import Testing
@testable import essensys_iphone

/// Affichage des lumières et des volets (affichage-objets-2026-11-006, tâches 6.1 à 6.3, spec object-layout-clients).
@MainActor struct ObjectLayoutTests {
    private static let lightsDoc = #"{"order":["sam","salon"],"disabled":["wc2"],"version":3,"updated_at":"2026-11-07T10:15:30.123Z"}"#
    private static let defaultDoc = #"{"order":[],"disabled":[],"version":0,"updated_at":null}"#

    private func ids(_ items: [IndexTable.Light]) -> [String] { items.map(\.id) }

    // MARK: lecture et repli

    @Test func layout_is_read_from_the_cloud_route() async {
        let t = TestBackend(token: "jwt")
        t.enqueue(200, Self.lightsDoc)
        guard case let .success(layout) = await t.container.comfort.readObjectLayout(.lights) else { Issue.record("succès attendu"); return }
        #expect(t.requests.first?.path == "/api/portal/lights/layout")
        #expect(t.requests.first?.method == "GET")
        #expect(layout.order == ["sam", "salon"])
        #expect(layout.disabled == ["wc2"])
        #expect(layout.version == 3)
    }

    @Test func layout_is_read_from_the_local_route_in_lan_mode() async {
        let t = TestBackend(mode: .lan)
        t.store.update { $0.lanCookie = "abc" }
        t.enqueue(200, Self.defaultDoc)
        _ = await t.container.comfort.readObjectLayout(.shutters)
        #expect(t.requests.first?.path == "/api/shutters/layout")
    }

    @Test func default_layout_keeps_the_catalogue_order_and_shows_everything() async {
        let t = TestBackend(token: "jwt")
        t.enqueue(200, Self.defaultDoc)
        let model = ObjectLayoutModel(kind: .lights, comfort: t.container.comfort)
        await model.load()
        #expect(model.loaded)
        #expect(ids(model.visible(IndexTable.lights)) == ids(IndexTable.lights))
        #expect(model.visible(IndexTable.lights).count == 33)
    }

    @Test func old_server_404_shows_the_full_catalogue_without_message() async {
        let t = TestBackend(token: "jwt")
        t.enqueue(404, "Not found")
        let model = ObjectLayoutModel(kind: .shutters, comfort: t.container.comfort)
        await model.load()
        #expect(!model.loaded)
        #expect(model.feedback == nil)
        #expect(model.visible(IndexTable.shutters).map(\.id) == IndexTable.shutters.map(\.id))
        #expect(model.visible(IndexTable.shutters).count == 16)
    }

    @Test func incomplete_order_and_unknown_ids_are_tolerated() {
        let layout = ObjectLayout(order: ["salon", "ancienne"], disabled: ["inconnue"])
        let ordered = layout.orderedIDs(catalogue: IndexTable.lights.map(\.id))
        #expect(ordered.first == "salon")
        #expect(!ordered.contains("ancienne"))
        #expect(ordered.count == 33)
        // Les autres suivent dans l'ordre du catalogue.
        #expect(Array(ordered.dropFirst()) == IndexTable.lights.map(\.id).filter { $0 != "salon" })
        #expect(layout.disabledIDs(catalogue: IndexTable.lights.map(\.id)).isEmpty)
    }

    @Test func duplicates_in_order_keep_the_first_occurrence_only() {
        let layout = ObjectLayout(order: ["sam", "salon", "sam"], disabled: [])
        let ordered = layout.orderedIDs(catalogue: IndexTable.lights.map(\.id))
        #expect(ordered.filter { $0 == "sam" }.count == 1)
        #expect(Array(ordered.prefix(2)) == ["sam", "salon"])
    }

    @Test func a_lost_connection_keeps_the_last_layout_read() async {
        let t = TestBackend(token: "jwt")
        t.enqueue(200, Self.lightsDoc)
        t.enqueue(503, #"{"error":"names_unavailable"}"#)
        let model = ObjectLayoutModel(kind: .lights, comfort: t.container.comfort)
        await model.load()
        await model.load()
        #expect(model.isDisabled("wc2")) // un objet masqué ne réapparaît pas sur une coupure passagère
        #expect(model.feedback == nil)
        model.reset() // changement de compte ou de mode
        #expect(!model.isDisabled("wc2"))
    }

    // MARK: désactivation et ordre par groupe

    @Test func disabled_light_is_hidden_and_absent_from_the_group_command() async {
        let t = TestBackend(token: "jwt")
        t.enqueue(200, #"{"order":[],"disabled":["wc2"],"version":1,"updated_at":"2026-11-07T10:15:30.123Z"}"#)
        let model = ObjectLayoutModel(kind: .lights, comfort: t.container.comfort)
        await model.load()
        let main = model.visible(IndexTable.lights).filter { $0.group == .main }
        #expect(main.count == 20)
        #expect(!main.contains { $0.id == "wc2" })
        let injections = main.map { $0.command(on: true) }
        #expect(injections.count == 20)
        #expect(!injections.contains(IndexTable.lights.first { $0.id == "wc2" }!.command(on: true)))
    }

    @Test func order_applies_inside_each_group_and_never_moves_an_item_between_groups() async {
        let t = TestBackend(token: "jwt")
        // `isalonind` (indirect) placé avant `salon` (principal) : le groupe d'affichage ne change pas.
        t.enqueue(200, #"{"order":["isalonind","sam","salon"],"disabled":[],"version":2,"updated_at":"2026-11-07T10:15:30.123Z"}"#)
        let model = ObjectLayoutModel(kind: .lights, comfort: t.container.comfort)
        await model.load()
        let main = ids(model.visible(IndexTable.lights).filter { $0.group == .main })
        let indirect = ids(model.visible(IndexTable.lights).filter { $0.group == .indirect })
        #expect(main.prefix(2) == ["sam", "salon"])
        #expect(indirect.first == "isalonind")
        #expect(!main.contains("isalonind"))
        #expect(indirect.count == 12)
    }

    @Test func shutters_follow_the_chosen_order_in_the_list_and_the_travel_time_card() async {
        let t = TestBackend(token: "jwt")
        t.enqueue(200, #"{"order":["volet2salon","volet1salon"],"disabled":["voletbureau","store"],"version":1,"updated_at":"2026-11-07T10:15:30.123Z"}"#)
        let model = ObjectLayoutModel(kind: .shutters, comfort: t.container.comfort)
        await model.load()
        let visible = model.visible(IndexTable.shutters)
        #expect(visible.prefix(2).map(\.id) == ["volet2salon", "volet1salon"])
        #expect(!visible.contains { $0.id == "voletbureau" || $0.id == "store" })
        #expect(visible.count == 14)
        #expect(visible.filter { $0.group == .special }.map(\.id) == ["voletstore"])
    }

    @Test func all_disabled_leaves_the_groups_empty() async {
        let t = TestBackend(token: "jwt")
        let allMain = IndexTable.lights.filter { $0.group == .main }.map { "\"\($0.id)\"" }.joined(separator: ",")
        t.enqueue(200, #"{"order":[],"disabled":[\#(allMain)],"version":1,"updated_at":"2026-11-07T10:15:30.123Z"}"#)
        let model = ObjectLayoutModel(kind: .lights, comfort: t.container.comfort)
        await model.load()
        #expect(model.visible(IndexTable.lights).filter { $0.group == .main }.isEmpty)
        #expect(model.visible(IndexTable.lights).filter { $0.group == .indirect }.count == 12)
    }

    @Test func light_timers_follow_the_global_order_and_skip_disabled_lights() async {
        let t = TestBackend(token: "jwt")
        t.enqueue(200, #"{"order":["ann2","wc1"],"disabled":["wc2"],"version":1,"updated_at":"2026-11-07T10:15:30.123Z"}"#)
        let model = ObjectLayoutModel(kind: .lights, comfort: t.container.comfort)
        await model.load()
        let timers = model.visible(IndexTable.lightTimers)
        #expect(!timers.contains { $0.id == "wc2" })
        #expect(timers.count == 5)
        // `ann2` précède `wc1` ; les autres suivent l'ordre du catalogue des lumières (pieceserv, ann1, dressing...).
        #expect(timers.first?.id == "ann2")
        #expect(timers.map(\.id).firstIndex(of: "ann2")! < timers.map(\.id).firstIndex(of: "wc1")!)
    }

    @Test func custom_names_and_timers_are_untouched_by_the_layout() async {
        let t = TestBackend(token: "jwt")
        t.enqueue(200, #"{"lights":[{"id":"dressing","default":"Dressing","name":"WC 3","version":2,"updated_at":"2026-11-07T10:15:30.123Z"}]}"#)
        t.enqueue(200, #"{"order":["dressing"],"disabled":[],"version":1,"updated_at":"2026-11-07T10:15:30.123Z"}"#)
        let names = LightNamesModel(comfort: t.container.comfort)
        let layout = ObjectLayoutModel(kind: .lights, comfort: t.container.comfort)
        await names.load()
        await layout.load()
        let first = layout.visible(IndexTable.lights).first!
        #expect(first.id == "dressing")
        #expect(names.displayName(first) == "WC 3")
        #expect(IndexTable.lightTimers.map(\.key) == [521, 555, 556, 557, 561, 562])
    }

    // MARK: écriture

    @Test func save_is_one_put_on_the_admin_cloud_path_with_the_complete_order() async {
        let t = TestBackend(token: "jwt")
        t.enqueue(200, #"{"order":["volet2salon","volet1salon"],"disabled":["voletbureau"],"version":1,"updated_at":"2026-11-07T10:15:30.123Z","status":"saved"}"#)
        let model = ObjectLayoutModel(kind: .shutters, comfort: t.container.comfort)
        var draft = ObjectLayoutDraft(kind: .shutters, layout: model.layout)
        draft.move("volet2salon", up: true)
        draft.toggle("voletbureau")
        #expect(await model.save(draft))
        #expect(t.requests.count == 1)
        #expect(t.requests.first?.method == "PUT")
        #expect(t.requests.first?.path == "/api/portal/admin/shutters/layout")
        let body = try! JSONSerialization.jsonObject(with: Data((t.requests.first?.body ?? "").utf8)) as! [String: Any]
        #expect(Set(body.keys) == ["order", "disabled"])
        let order = body["order"] as! [String]
        #expect(order.count == 16) // `order` complet
        #expect(Array(order.prefix(2)) == ["volet2salon", "volet1salon"])
        #expect(body["disabled"] as! [String] == ["voletbureau"])
        #expect(model.isDisabled("voletbureau")) // appliqué sans relecture
        #expect(model.feedback?.kind == .success)
    }

    @Test func save_is_a_put_on_the_admin_local_path_in_lan_mode() async {
        let t = TestBackend(mode: .lan)
        t.store.update { $0.lanCookie = "abc" }
        t.enqueue(200, #"{"order":[],"disabled":["wc2"],"version":1,"updated_at":"2026-11-07T10:15:30.123Z","status":"saved"}"#)
        let model = ObjectLayoutModel(kind: .lights, comfort: t.container.comfort)
        var draft = ObjectLayoutDraft(kind: .lights, layout: model.layout)
        draft.toggle("wc2")
        #expect(await model.save(draft))
        #expect(t.requests.first?.path == "/api/admin/lights/layout")
    }

    @Test func original_order_sends_reset_true_and_reenables_everything() async {
        let t = TestBackend(token: "jwt")
        t.enqueue(200, Self.lightsDoc)
        t.enqueue(200, #"{"order":[],"disabled":[],"version":4,"updated_at":"2026-11-07T10:20:00.000Z","status":"saved"}"#)
        let model = ObjectLayoutModel(kind: .lights, comfort: t.container.comfort)
        await model.load()
        var draft = ObjectLayoutDraft(kind: .lights, layout: model.layout)
        draft.resetToOrigin()
        #expect(draft.disabled.isEmpty)
        #expect(draft.order == IndexTable.lights.map(\.id))
        #expect(await model.save(draft))
        #expect(t.requests.last?.body == #"{"reset":true}"#)
        #expect(ids(model.visible(IndexTable.lights)) == ids(IndexTable.lights))
    }

    @Test func an_edit_after_original_order_sends_the_complete_document_instead_of_reset() {
        var draft = ObjectLayoutDraft(kind: .lights, layout: .original)
        draft.resetToOrigin()
        draft.toggle("wc2")
        #expect(!draft.isReset)
        #expect(draft.disabled == ["wc2"])
    }

    @Test func dry_run_header_is_sent_in_test_mode_and_nothing_is_applied() async {
        let t = TestBackend(token: "jwt", testMode: true)
        t.enqueue(200, #"{"order":[],"disabled":["wc2"],"version":0,"updated_at":null,"status":"dry_run"}"#)
        let model = ObjectLayoutModel(kind: .lights, comfort: t.container.comfort)
        var draft = ObjectLayoutDraft(kind: .lights, layout: model.layout)
        draft.toggle("wc2")
        #expect(await model.save(draft))
        #expect(t.requests.first?.headers["X-Essensys-Test-Mode"] == "dry-run")
        #expect(model.feedback?.kind == .info)
        #expect(!model.isDisabled("wc2"))
    }

    @Test func error_messages_for_400_403_503_are_clear_and_keep_the_draft() async {
        let t = TestBackend(token: "jwt")
        let model = ObjectLayoutModel(kind: .lights, comfort: t.container.comfort)
        var draft = ObjectLayoutDraft(kind: .lights, layout: model.layout)
        draft.toggle("wc2")
        t.enqueue(400, #"{"error":"invalid_layout"}"#)
        #expect(!(await model.save(draft)))
        #expect(model.feedback?.text == ObjectLayoutFormat.invalidMessage)
        t.enqueue(400, #"{"error":"unknown_light"}"#)
        #expect(!(await model.save(draft)))
        #expect(model.feedback?.text == "Lumière inconnue.")
        t.enqueue(403, #"{"error":"forbidden"}"#)
        #expect(!(await model.save(draft)))
        #expect(model.feedback?.text == "Réservé à l'administrateur de l'armoire.")
        t.enqueue(503, #"{"error":"names_unavailable"}"#)
        #expect(!(await model.save(draft)))
        #expect(model.feedback?.text.contains("stockage indisponible") == true)
        #expect(model.feedback?.kind == .error)
        #expect(!model.isDisabled("wc2")) // rien d'appliqué
        #expect(t.store.state.token == "jwt") // un 403 ne déconnecte pas
    }

    @Test func unknown_or_duplicate_ids_never_reach_the_network() async {
        let t = TestBackend(token: "jwt")
        let comfort = t.container.comfort
        guard case .failure(.invalidRequest) = await comfort.writeObjectLayout(.lights, order: ["salon", "inconnue"], disabled: []) else { Issue.record("refus attendu"); return }
        guard case .failure(.invalidRequest) = await comfort.writeObjectLayout(.lights, order: ["salon", "salon"], disabled: []) else { Issue.record("refus attendu"); return }
        guard case .failure(.invalidRequest) = await comfort.writeObjectLayout(.lights, order: [], disabled: ["wc2", "wc2"]) else { Issue.record("refus attendu"); return }
        // Un identifiant de l'autre genre est refusé.
        guard case .failure(.invalidRequest) = await comfort.writeObjectLayout(.shutters, order: ["salon"], disabled: []) else { Issue.record("refus attendu"); return }
        #expect(t.requests.isEmpty)
    }

    // MARK: écran de gestion

    @Test func management_lists_every_object_in_the_effective_order_with_disabled_ones() {
        let layout = ObjectLayout(order: ["sam", "salon"], disabled: ["wc2"])
        let draft = ObjectLayoutDraft(kind: .lights, layout: layout)
        #expect(draft.order.count == 33)
        #expect(Array(draft.order.prefix(2)) == ["sam", "salon"])
        #expect(draft.disabled == ["wc2"])
        #expect(draft.order.contains("wc2"))
    }

    @Test func move_swaps_with_the_neighbour_of_the_same_group() {
        var draft = ObjectLayoutDraft(kind: .lights, layout: ObjectLayout(order: ["salon", "isalonind", "sam"], disabled: []))
        // Dans le groupe principal, `sam` suit `salon` malgré `isalonind` entre eux dans l'ordre global.
        draft.move("sam", up: true)
        let main = draft.order.filter { id in IndexTable.lights.first { $0.id == id }?.group == .main }
        #expect(Array(main.prefix(2)) == ["sam", "salon"])
        #expect(draft.order.filter { $0 == "isalonind" }.count == 1)
        let indirect = draft.order.filter { id in IndexTable.lights.first { $0.id == id }?.group == .indirect }
        #expect(indirect.first == "isalonind")
    }

    @Test func move_is_refused_at_the_head_and_tail_of_a_group() {
        var draft = ObjectLayoutDraft(kind: .shutters, layout: .original)
        #expect(!draft.canMove("volet1salon", up: true))
        #expect(draft.canMove("volet1salon", up: false))
        #expect(!draft.canMove("voletbureau", up: false)) // dernier du groupe « Volets »
        #expect(!draft.canMove("voletstore", up: true)) // premier du groupe « Éléments spéciaux »
        #expect(!draft.canMove("store", up: false))
        let before = draft.order
        draft.move("volet1salon", up: true)
        #expect(draft.order == before)
    }

    // NR: NR-ios-27 essensys-hub/essensys-feature-lifecycle#41
    @Test func layout_never_orders_the_armoire_and_keeps_names_and_indices_NR_ios_27() async {
        let t = TestBackend(token: "jwt")
        t.enqueue(200, #"{"order":[],"disabled":["wc2"],"version":1,"updated_at":"2026-11-07T10:15:30.123Z","status":"saved"}"#)
        t.enqueue(200, #"{"order":[],"disabled":[],"version":2,"updated_at":"2026-11-07T10:16:00.000Z","status":"saved"}"#)
        let model = ObjectLayoutModel(kind: .lights, comfort: t.container.comfort)
        var draft = ObjectLayoutDraft(kind: .lights, layout: model.layout)
        draft.toggle("wc2")
        _ = await model.save(draft)
        var reset = draft
        reset.resetToOrigin()
        _ = await model.save(reset)
        #expect(t.requests.allSatisfy { $0.path.contains("/lights/layout") })
        #expect(!t.requests.contains { $0.path.contains("inject") || $0.path.contains("web/actions") || $0.path.contains("exchange") })
        // Table d'échange, catalogues et noms d'origine inchangés (#41, #52).
        let wc2 = IndexTable.lights.first { $0.id == "wc2" }!
        #expect(wc2.name == "WC 2")
        #expect(IndexTable.lights.count == 33)
        #expect(IndexTable.shutters.count == 16)
        let salon = IndexTable.shutters.first { $0.id == "volet1salon" }!
        #expect(salon.command(open: true) == Injection(k: 617, v: "1"))
        #expect(salon.travelTimeIndex == 566)
        let names = LightNamesModel(comfort: t.container.comfort)
        #expect(names.displayName(id: "dressing") == "Dressing")
        let shutters = ShutterNamesModel(comfort: t.container.comfort)
        #expect(shutters.displayName(id: "store") == "Store (banne)")
    }
}
