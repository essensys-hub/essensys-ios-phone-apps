import Testing
@testable import essensys_iphone

/// Mêmes scénarios que ScenarioRepositoryTest.kt (Android).
struct ScenarioRepositoryTests {
    @Test func list_hides_server_slot_and_marks_last_launched() async {
        let t = TestBackend(token: "jwt")
        t.enqueue(200, TestBackend.fixture("scenarios_list"))
        guard case let .success(slots) = await t.container.scenarios.list() else { Issue.record("succès attendu"); return }
        #expect(slots.map(\.slot) == Array(2...8))
        #expect(slots.first?.label == "Je sors")
        #expect(slots.first?.lastLaunched == 2)
        #expect(t.requests.first?.path == "/api/portal/scenarios")
    }

    @Test func launch_uses_cloud_then_lan_routes() async {
        let cloud = TestBackend(token: "jwt")
        cloud.enqueue(200, TestBackend.fixture("scenario_launch_ok"))
        #expect(await cloud.container.scenarios.launch(2) == .success(.sent))
        #expect(cloud.requests.first?.method == "POST")
        #expect(cloud.requests.first?.path == "/api/portal/scenarios/2/launch")
        let lan = TestBackend(mode: .lan)
        lan.store.update { $0.lanCookie = "abc" }
        lan.enqueue(200, TestBackend.fixture("scenario_launch_ok"))
        _ = await lan.container.scenarios.launch(4)
        #expect(lan.requests.first?.path == "/api/scenarios/4/launch")
    }

    // Spec : en mode test, lancement, restauration et enregistrement portent l'en-tête dry-run, en LAN aussi.
    @Test func lan_mutations_carry_dry_run_header_in_test_mode() async {
        let t = TestBackend(mode: .lan, testMode: true)
        t.store.update { $0.lanCookie = "abc" }
        for _ in 0..<3 { t.enqueue(200, TestBackend.fixture("inject_dry_run")) }
        let definition = ScenarioDefinition(slot: 4, values: Dictionary(uniqueKeysWithValues: IndexTable.scenarioBlock(4).map { ($0, 0) }))
        #expect(await t.container.scenarios.launch(6) == .success(.dryRunOK))
        #expect(await t.container.scenarios.restore(3) == .success(.dryRunOK))
        #expect(await t.container.scenarios.save(definition) == .success(.dryRunOK))
        #expect(t.requests.map { $0.headers["X-Essensys-Test-Mode"] } == ["dry-run", "dry-run", "dry-run"])
    }

    // NR: NR-ios-15 essensys-hub/essensys-ios-phone-apps#13
    @Test func scenario_bitmask_index_is_shifted_into_slot_block_NR_ios_15() async {
        #expect(IndexTable.shiftIntoScenario(605, slot: 4) == 728)
        #expect(IndexTable.shiftIntoScenario(617, slot: 2) == 633 + 25)
        let t = TestBackend(token: "jwt")
        t.enqueue(200, TestBackend.fixture("scenario_4"))
        t.enqueue(200, TestBackend.fixture("scenario_save_ok"))
        guard case let .success(definition) = await t.container.scenarios.definition(4) else { Issue.record("succès attendu"); return }
        #expect(definition.complete)
        let edited = definition.toggled(metaIndex: 605, bitValue: 2, on: true)
        #expect(edited.isSet(metaIndex: 605, bitValue: 2))
        _ = await t.container.scenarios.save(edited)
        let body = t.requests.last?.body ?? ""
        #expect(body.contains(#""728":"2""#), "\(body)")
        #expect(!body.contains(#""605""#), "\(body)")
        #expect(body.components(separatedBy: #"":""#).count - 1 == 41) // les 41 octets du bloc 715–755
    }

    @Test func incomplete_definition_or_out_of_block_index_is_refused_locally() async {
        let t = TestBackend(token: "jwt")
        let partial = ScenarioDefinition(slot: 4, values: [715: 0])
        #expect(!partial.complete)
        guard case .failure(.invalidRequest) = await t.container.scenarios.save(partial) else { Issue.record("refus attendu"); return }
        var outside = ScenarioDefinition(slot: 4, values: Dictionary(uniqueKeysWithValues: IndexTable.scenarioBlock(4).map { ($0, 0) }))
        outside.values[605] = 1
        guard case .failure(.invalidRequest) = await t.container.scenarios.save(outside) else { Issue.record("refus attendu"); return }
        guard case .failure(.invalidRequest) = await t.container.scenarios.restore(7) else { Issue.record("refus attendu"); return }
        #expect(t.requests.isEmpty)
    }

    @Test func test_failed_from_server_is_reported() async {
        let t = TestBackend(token: "jwt", testMode: true)
        t.enqueue(422, TestBackend.fixture("test_failed"))
        guard case let .failure(error) = await t.container.scenarios.launch(2) else { Issue.record("échec attendu"); return }
        #expect(error.userMessage.contains("outside slot range"))
    }
}
