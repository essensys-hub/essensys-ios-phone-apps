import Foundation
import Security
import Testing
@testable import essensys_iphone

/// Épinglage TOFU du certificat de la gateway LAN (spec connection-modes « HTTPS uniquement », design D4).
struct LanTrustTests {
    private func der(_ name: String) -> Data {
        try! Data(contentsOf: Bundle(for: BundleToken.self).url(forResource: name, withExtension: "der")!)
    }
    private func trust(_ chain: [Data]) -> SecTrust {
        let certs = chain.map { SecCertificateCreateWithData(nil, $0 as CFData)! }
        var trust: SecTrust?
        SecTrustCreateWithCertificates(certs as CFArray, SecPolicyCreateBasicX509(), &trust)
        return trust!
    }

    @Test func presented_gateway_ca_is_the_anchor_candidate() {
        let ca = der("test_ca_cert")
        let candidate = LanTrust.anchorCandidate(of: trust([der("test_leaf_cert"), ca]))
        #expect(candidate.map(LanTrust.sha256) == LanTrust.sha256(ca))
        #expect(LanTrust.sha256(ca).range(of: "^([0-9A-F]{2}:){31}[0-9A-F]{2}$", options: .regularExpression) != nil)
    }

    @Test func pinned_gateway_certificate_is_trusted() {
        #expect(LanTrust.evaluate(trust([der("test_leaf_cert"), der("test_ca_cert")]), host: "localhost", pinned: der("test_ca_cert")))
    }

    @Test func another_ca_is_rejected() {
        #expect(!LanTrust.evaluate(trust([der("test_leaf_cert"), der("test_ca_cert")]), host: "localhost", pinned: der("test_other_cert")))
    }

    @Test func wrong_host_is_rejected() {
        #expect(!LanTrust.evaluate(trust([der("test_leaf_cert"), der("test_ca_cert")]), host: "mon.essensys.local", pinned: der("test_ca_cert")))
    }

    @Test func requests_fail_until_certificate_is_confirmed() async {
        var state = SessionState(); state.mode = .lan; state.lanHost = "https://127.0.0.1:9"; state.lanCookie = "c"
        let container = AppContainer(store: SessionStore(persistence: InMemoryPersistence(initial: state)), guardNoArmoire: true)
        guard case let .failure(error) = await container.portal.lanSessionValid() else { Issue.record("échec attendu"); return }
        guard case .network = error else { Issue.record("erreur réseau attendue : \(error)"); return }
    }
}
