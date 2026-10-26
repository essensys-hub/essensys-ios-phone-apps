import Foundation
import Testing
@testable import essensys_iphone

/// Armoire « en ligne » avec ou sans gateway (armoire-online-sans-gateway-2026-10-012), cas A à F de la
/// matrice du ticket essensys-hub/essensys-feature-lifecycle#37. Les sessions passent par le vrai décodage
/// du dépôt, depuis le JSON du cloud. Même jeu de cas que PortalOnlineTest.kt (Android).
struct PortalOnlineTests {
    private let gatewayOn = #"{"id":"gw","online":true}"#
    private let gatewayOff = #"{"id":"gw","online":false}"#
    private let armoireSeen = #"{"no_serie":"UNKNOWN-734254c2","last_seen":"2026-10-26T11:48:00Z","online":true}"#
    private let armoireOld = #"{"no_serie":"UNKNOWN-734254c2","last_seen":"2026-10-26T09:00:00Z","online":false}"#

    private func json(gateway: String?, armoire: String?) -> String {
        #"{"user":{"email":"demo@essensys.fr"},"portal_access":true"#
            + (gateway.map { #","gateway":\#($0)"# } ?? "") + (armoire.map { #","armoire":\#($0)"# } ?? "") + "}"
    }

    private func online(gateway: String?, armoire: String?) async -> Bool? {
        let t = TestBackend(token: "jwt")
        t.enqueue(200, json(gateway: gateway, armoire: armoire))
        guard case let .success(value) = await t.container.portal.gatewayOnline() else { return nil }
        return value
    }

    @Test func avec_gateway_en_ligne() async { #expect(await online(gateway: gatewayOn, armoire: armoireSeen) == true) }
    @Test func gateway_hors_ligne_armoire_vue() async { #expect(await online(gateway: gatewayOff, armoire: armoireSeen) == true) }
    @Test func gateway_et_armoire_hors_ligne() async { #expect(await online(gateway: gatewayOff, armoire: armoireOld) == false) }

    // NR: NR-ios-19 essensys-hub/essensys-ios-phone-apps#24
    // Signalement du 2026-10-26 (essensys-feature-lifecycle#37) : sans gateway, armoire vue.
    @Test func sans_gateway_armoire_vue_en_ligne_NR_ios_19() async {
        #expect(await online(gateway: nil, armoire: armoireSeen) == true)
    }

    @Test func sans_gateway_armoire_ancienne_hors_ligne() async { #expect(await online(gateway: nil, armoire: armoireOld) == false) }
    @Test func sans_gateway_ni_armoire_hors_ligne() async { #expect(await online(gateway: nil, armoire: nil) == false) }

    @Test func ancien_backend_sans_champ_online_se_reduit_a_la_gateway() async {
        let oldArmoire = #"{"no_serie":"SC944D-0001","last_seen":"2026-10-26T11:48:00Z"}"#
        #expect(await online(gateway: gatewayOn, armoire: oldArmoire) == true)
        #expect(await online(gateway: nil, armoire: oldArmoire) == false)
    }

    @Test func la_regle_se_lit_aussi_sur_la_session_decodee() throws {
        let data = Data(json(gateway: nil, armoire: armoireSeen).utf8)
        let session = try JSONDecoder().decode(PortalSession.self, from: data)
        #expect(session.gateway == nil)
        #expect(session.armoireOnline)
    }
}
