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

    @Test func security_outlets_cut_is_one_batch_in_cloud() async {
        let t = TestBackend(token: "jwt")
        t.enqueue(200, TestBackend.fixture("inject_ok"))
        #expect(await t.container.comfort.securityOutlets(.cut) == .success(.sent))
        #expect(t.requests.first?.path == "/api/portal/inject/batch")
        #expect(t.requests.first?.body == #"{"params":[{"k":590,"v":"1"},{"k":623,"v":"1"}]}"#)
    }

    @Test func security_outlets_restore_is_one_array_in_lan_with_dry_run() async {
        let t = TestBackend(mode: .lan, testMode: true)
        t.store.update { $0.lanCookie = "abc" }
        t.enqueue(200, TestBackend.fixture("inject_dry_run"))
        #expect(await t.container.comfort.securityOutlets(.restore) == .success(.dryRunOK))
        #expect(t.requests.first?.path == "/api/admin/inject")
        #expect(t.requests.first?.headers["X-Essensys-Test-Mode"] == "dry-run")
        #expect(t.requests.first?.body == #"[{"k":590,"v":"1"},{"k":623,"v":"2"}]"#)
    }

    @Test func security_outlets_state_is_read_at_440() async {
        let t = TestBackend(token: "jwt")
        t.enqueue(200, #"{"values":[{"k":440,"v":"1"}],"stale":false,"source":"gateway_cache"}"#)
        t.enqueue(200, #"{"values":[],"stale":false,"source":"none"}"#)
        #expect(await t.container.comfort.readSecurityOutlets() == .success(.cut))
        #expect(t.requests.first?.path == "/api/portal/exchange")
        #expect(t.requests.first?.query == "keys=440")
        #expect(await t.container.comfort.readSecurityOutlets() == .success(.unknown))
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

    // MARK: Temporisations des lumières (lumieres-temporisees-2026-11-003)

    private static let timersReply = #"{"timers":[{"id":"dressing","label":"Dressing","key":521,"minutes":15},{"id":"wc1","label":"WC 1","key":555,"minutes":null},{"id":"wc2","label":"WC 2","key":556,"minutes":0},{"id":"pieceserv","label":"Service","key":557,"minutes":60},{"id":"ann1","label":"Annexe 1","key":561,"minutes":null},{"id":"ann2","label":"Annexe 2","key":562,"minutes":7}]}"#

    @Test func light_timers_are_read_in_cloud_with_unknown_kept_unknown() async {
        let t = TestBackend(token: "jwt")
        t.enqueue(200, Self.timersReply)
        guard case let .success(timers) = await t.container.comfort.readLightTimers() else { Issue.record("succès attendu"); return }
        #expect(t.requests.first?.method == "GET")
        #expect(t.requests.first?.path == "/api/portal/lights/timers")
        #expect(timers.map(\.id) == ["dressing", "wc1", "wc2", "pieceserv", "ann1", "ann2"])
        #expect(timers.map(\.minutes) == [15, nil, 0, 60, nil, 7])
        #expect(timers.map(\.display) == ["15 min", "Inconnue", "Jamais", "1 h", "Inconnue", "7 min"])
        #expect(timers.first?.key == 521)
    }

    @Test func light_timers_are_read_on_admin_path_in_lan() async {
        let t = TestBackend(mode: .lan)
        t.store.update { $0.lanCookie = "abc" }
        t.enqueue(200, Self.timersReply)
        _ = await t.container.comfort.readLightTimers()
        #expect(t.requests.first?.path == "/api/admin/lights/timers")
        #expect(t.requests.first?.headers["Cookie"] == "essensys_lan_session=abc")
    }

    @Test func light_timer_out_of_range_reply_is_unknown_not_zero() async {
        let t = TestBackend(token: "jwt")
        t.enqueue(200, #"{"timers":[{"id":"dressing","key":521,"minutes":300},{"id":"wc1","key":555}]}"#)
        guard case let .success(timers) = await t.container.comfort.readLightTimers() else { Issue.record("succès attendu"); return }
        #expect(timers.count == 6)
        #expect(timers[0].minutes == nil)
        #expect(timers[1].minutes == nil)
    }

    @Test func light_timer_is_written_with_put_on_the_admin_cloud_path() async {
        let t = TestBackend(token: "jwt")
        t.enqueue(200, #"{"id":"wc2","minutes":30,"status":"queued"}"#)
        #expect(await t.container.comfort.setLightTimer(id: "wc2", minutes: 30) == .success(.sent))
        #expect(t.requests.first?.method == "PUT")
        #expect(t.requests.first?.path == "/api/portal/admin/lights/timers/wc2")
        #expect(t.requests.first?.body == #"{"minutes":30}"#)
    }

    @Test func light_timer_is_written_in_lan_with_dry_run_in_test_mode() async {
        let t = TestBackend(mode: .lan, testMode: true)
        t.store.update { $0.lanCookie = "abc" }
        t.enqueue(200, #"{"id":"dressing","minutes":0,"status":"dry_run"}"#)
        #expect(await t.container.comfort.setLightTimer(id: "dressing", minutes: 0) == .success(.dryRunOK))
        #expect(t.requests.first?.path == "/api/admin/lights/timers/dressing")
        #expect(t.requests.first?.headers["X-Essensys-Test-Mode"] == "dry-run")
        #expect(t.requests.first?.body == #"{"minutes":0}"#)
    }

    @Test func light_timer_invalid_values_never_reach_the_network() async {
        let t = TestBackend(token: "jwt")
        for minutes in [-1, 256, 300] {
            guard case .failure(.invalidRequest) = await t.container.comfort.setLightTimer(id: "dressing", minutes: minutes) else {
                Issue.record("refus attendu pour \(minutes)"); continue
            }
        }
        guard case .failure(.invalidRequest) = await t.container.comfort.setLightTimer(id: "salon1", minutes: 10) else {
            Issue.record("refus attendu"); return
        }
        #expect(t.requests.isEmpty)
    }

    @Test func light_timer_forbidden_for_a_simple_user_keeps_the_session() async {
        let t = TestBackend(token: "jwt")
        t.enqueue(403, #"{"error":"forbidden"}"#)
        guard case let .failure(error) = await t.container.comfort.setLightTimer(id: "dressing", minutes: 15) else { Issue.record("échec attendu"); return }
        guard case .forbidden = error else { Issue.record("403 attendu : \(error)"); return }
        #expect(t.store.state.token == "jwt")
    }
}
