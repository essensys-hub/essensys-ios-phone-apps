import Testing
@testable import essensys_iphone

/// Mêmes scénarios que ComfortRepositoryTest.kt (Android).
struct ComfortRepositoryTests {
    @Test func current_modes_are_read_from_firmware_indices() async {
        let t = TestBackend(token: "jwt")
        t.enqueue(200, #"{"values":[{"k":353,"v":"1"},{"k":363,"v":"30"}],"stale":false,"source":"gateway_cache"}"#)
        t.enqueue(200, #"{"values":[],"stale":false,"source":"none"}"#)
        guard case let .success(modes) = await t.container.comfort.readModes() else { Issue.record("succès attendu"); return }
        #expect(modes.waterHeater == .offPeak)
        #expect(modes.sprinklerLabel == "Forcé 30 minutes")
        #expect(t.requests.first?.query == "keys=353,363")
        guard case let .success(unknown) = await t.container.comfort.readModes() else { Issue.record("succès attendu"); return }
        #expect(unknown.waterHeater == nil)
        #expect(unknown.sprinklerLabel == nil)
    }

    @Test func water_heater_and_sprinkler_commands_hit_inject() async {
        let t = TestBackend(token: "jwt")
        for _ in 0..<2 { t.enqueue(200, TestBackend.fixture("inject_ok")) }
        _ = await t.container.comfort.setWaterHeater(.offPeak)
        _ = await t.container.comfort.setSprinkler(.minutes30)
        #expect(t.requests.map(\.body) == [#"{"k":353,"v":"1"}"#, #"{"k":363,"v":"30"}"#])
    }

    @Test func alarm_posts_web_actions_in_cloud() async {
        let t = TestBackend(token: "jwt")
        t.enqueue(200, TestBackend.fixture("web_actions_ok"))
        #expect(await t.container.comfort.alarm(on: true, code: "1234") == .success(.sent))
        #expect(t.requests.first?.path == "/api/portal/web/actions")
        #expect(t.requests.first?.body == #"{"alarme":"on","codealarme":"1234"}"#)
    }

    @Test func alarm_is_cloud_only() async {
        let t = TestBackend(mode: .lan)
        t.store.update { $0.lanCookie = "abc" }
        #expect(await t.container.comfort.alarm(on: false, code: "1234") == .failure(.cloudOnly))
        #expect(t.requests.isEmpty)
    }

    // NR: NR-ios-16 essensys-hub/essensys-ios-phone-apps#14
    @Test func alarm_code_is_never_logged_or_stored_NR_ios_16() async {
        let t = TestBackend(token: "jwt", testMode: true)
        // Réponse dry-run qui répète le code, puis erreur serveur qui le cite.
        t.enqueue(200, #"{"status":"test_ok","dry_run":true,"validated_params":[{"k":410,"v":"12"},{"k":411,"v":"34"}],"message":"code 1234 ok"}"#)
        t.enqueue(400, "invalid code 1234\n", headers: [:])
        #expect(await t.container.comfort.alarm(on: true, code: "1234") == .success(.dryRunOK)) // statut seul
        guard case let .failure(error) = await t.container.comfort.alarm(on: false, code: "1234") else { Issue.record("échec attendu"); return }
        #expect(!error.userMessage.contains("1234"))
        #expect(!String(describing: error).contains("1234"))
        // Aucune trace dans l'état de session (persisté dans le Keychain / UserDefaults).
        #expect(!String(describing: t.store.state).contains("1234"))
        #expect(!String(describing: AlarmRequest(alarme: "on", codealarme: "1234")).contains("1234"))
        guard case .failure(.invalidRequest) = await t.container.comfort.alarm(on: true, code: "12a4") else { Issue.record("refus attendu"); return }
    }
}
