import Foundation
import Testing
@testable import essensys_iphone

struct ControlRepositoryTests {
    private let salonOn = IndexTable.lights.first { $0.id == "salon" }!.command(on: true)

    @Test func cloud_inject_posts_portal_endpoint_with_bearer() async {
        let t = TestBackend(token: "jwt")
        t.enqueue(200, TestBackend.fixture("inject_ok"))
        #expect(await t.container.control.inject(salonOn) == .success(.sent))
        let r = t.requests.first
        #expect(r?.path == "/api/portal/inject")
        #expect(r?.body == #"{"k":612,"v":"128"}"#)
        #expect(r?.headers["Authorization"] == "Bearer jwt")
        #expect(r?.headers["X-Essensys-Test-Mode"] == nil)
    }

    @Test func lan_inject_posts_admin_endpoint_with_cookie() async {
        let t = TestBackend(mode: .lan)
        t.store.update { $0.lanCookie = "abc" }
        t.enqueue(200, #"{"status":"ok","guid":"g","guids":["g"]}"#)
        #expect(await t.container.control.inject(salonOn) == .success(.sent))
        #expect(t.requests.first?.path == "/api/admin/inject")
        #expect(t.requests.first?.headers["Cookie"] == "essensys_lan_session=abc")
    }

    // NR: NR-ios-7 essensys-hub/essensys-ios-phone-apps#4
    @Test func dry_run_header_sent_in_test_mode_NR_ios_7() async {
        let t = TestBackend(token: "jwt", testMode: true)
        t.enqueue(200, TestBackend.fixture("inject_dry_run"))
        #expect(await t.container.control.inject(salonOn) == .success(.dryRunOK))
        #expect(t.requests.first?.headers["X-Essensys-Test-Mode"] == "dry-run")
    }

    @Test func rate_limit_is_reported() async {
        let t = TestBackend(token: "jwt")
        t.enqueue(429, "Rate limit exceeded\n", headers: [:])
        #expect(await t.container.control.inject(salonOn) == .failure(.rateLimited))
    }

    @Test func group_command_is_sequential_and_stops_on_error() async {
        let t = TestBackend(token: "jwt")
        t.enqueue(200, TestBackend.fixture("inject_ok"))
        t.enqueue(403, "Portal access not approved\n", headers: [:])
        let all = IndexTable.lights.prefix(3).map { $0.command(on: false) }
        guard case let .failure(error) = await t.container.control.injectAll(Array(all)) else { Issue.record("échec attendu"); return }
        #expect(error.userMessage == "Accès portail non approuvé.")
        #expect(t.requests.count == 2)
    }

    @Test func exchange_read_returns_travel_times() async {
        let t = TestBackend(token: "jwt")
        t.enqueue(200, #"{"values":[{"k":566,"v":"25"},{"k":567,"v":"30"}],"stale":false,"source":"gateway_cache"}"#)
        #expect(await t.container.control.readExchange(keys: [566, 567]) == .success([566: "25", 567: "30"]))
        #expect(t.requests.first?.query == "keys=566,567")
    }

    // NR: NR-ios-4 essensys-hub/essensys-ios-phone-apps#3
    @Test func no_demo_fallback_when_server_unreachable_NR_ios_4() async {
        let t = TestBackend(token: "jwt")
        MockURLProtocol.unregister(host: t.host) // serveur arrêté : connexion refusée
        guard case let .failure(error) = await t.container.control.inject(salonOn) else { Issue.record("échec attendu"); return }
        guard case .network = error else { Issue.record("erreur réseau attendue : \(error)"); return }
        #expect(error.userMessage.hasPrefix("Connexion impossible à"))
    }
}
