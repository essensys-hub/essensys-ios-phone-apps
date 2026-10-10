import Foundation
import Testing
@testable import essensys_iphone

struct NoArmoireGuardTests {
    private func request(_ url: String, _ method: String = "POST", dryRun: Bool = false) -> URLRequest {
        var r = URLRequest(url: URL(string: url)!)
        r.httpMethod = method
        if dryRun { r.setValue(NoArmoireGuard.dryRun, forHTTPHeaderField: NoArmoireGuard.testModeHeader) }
        return r
    }

    // NR: NR-ios-1 essensys-hub/essensys-ios-phone-apps#1
    @Test func no_armoire_guard_blocks_real_mutation_NR_ios_1() async {
        #expect(NoArmoireGuard().shouldBlock(request("https://mon.essensys.fr/api/portal/inject")))
        // Bout en bout : l'appel échoue sans partir sur le réseau.
        var state = SessionState(); state.token = "jwt"
        let container = AppContainer(store: SessionStore(persistence: InMemoryPersistence(initial: state)), guardNoArmoire: true)
        let result = await container.control.inject(Injection(k: 612, v: "128"))
        guard case let .failure(.http(_, code, text)) = result else { Issue.record("attendu un échec no-armoire"); return }
        #expect(code == "no_armoire")
        #expect(text?.hasPrefix("no-armoire") == true)
    }

    @Test func simulated_backend_and_dry_run_are_allowed() {
        #expect(!NoArmoireGuard().shouldBlock(request("https://abc.essensys.test/api/portal/inject")))
        #expect(!NoArmoireGuard().shouldBlock(request("https://mon.essensys.fr/api/portal/inject", dryRun: true)))
    }

    @Test func reads_and_non_armoire_paths_are_not_mutations() {
        #expect(!NoArmoireGuard.isArmoireMutation(method: "GET", path: "/api/portal/inject"))
        #expect(!NoArmoireGuard.isArmoireMutation(method: "POST", path: "/api/auth/login"))
        #expect(NoArmoireGuard.isArmoireMutation(method: "POST", path: "/api/admin/inject"))
        #expect(NoArmoireGuard.isArmoireMutation(method: "POST", path: "/api/portal/scenarios/3/launch"))
    }
}
