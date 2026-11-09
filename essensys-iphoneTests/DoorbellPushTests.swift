import Foundation
import Testing
@testable import essensys_iphone

/// Notification de la sonnette (sonnette-plages-push-2026-11-008, essensys-hub/essensys-feature-lifecycle#61) :
/// jeton, dédoublonnage, présence de la gateway, option « Sonnette » et suppression à la déconnexion.
/// Cloud factice (URLProtocol) : aucune notification réelle, aucun fournisseur.
struct DoorbellPushTests {
    // MARK: jeton, ring_id, charge utile

    @Test func jeton_en_hexadecimal_minuscule() {
        #expect(PushToken.hex(Data([0x00, 0xAB, 0x0F, 0xFF])) == "00ab0fff")
    }

    @Test func un_ring_id_n_est_vu_qu_une_fois() {
        let deduper = RingDeduper()
        #expect(deduper.firstSight("ring-1"))
        #expect(!deduper.firstSight("ring-1"))
        #expect(deduper.firstSight("ring-2"))
    }

    @Test func le_dedoublonnage_garde_les_derniers_identifiants_seulement() {
        let deduper = RingDeduper()
        for i in 0..<60 { #expect(deduper.firstSight("r\(i)")) }
        #expect(deduper.firstSight("r0")) // sorti de la fenêtre des 50
        #expect(!deduper.firstSight("r59"))
    }

    @Test func charge_utile_de_la_sonnette() {
        #expect(DoorbellPayload.ringId(["type": "doorbell", "ring_id": "abc", "at": "2026-11-08T10:00:00Z"]) == "abc")
        #expect(DoorbellPayload.ringId(["type": "autre", "ring_id": "abc"]) == nil)
        #expect(DoorbellPayload.ringId([:]) == nil)
        #expect(RingDeduper().firstSight(DoorbellPayload.ringId(["type": "doorbell"])))
    }

    // MARK: présence de la gateway

    private func session(_ state: String?) throws -> PortalSession {
        let field = state.map { #","gateway_state":"\#($0)""# } ?? ""
        return try JSONDecoder().decode(PortalSession.self, from: Data(#"{"user":{"email":"a@b.fr"},"gateway":{"online":true}\#(field)}"#.utf8))
    }

    @Test func trois_etats_de_gateway() throws {
        #expect(try session("online").gatewayPresence?.label == "Gateway en ligne")
        #expect(try session("offline").gatewayPresence?.label == "Gateway hors ligne")
        #expect(try session("none").gatewayPresence?.label == "Aucune gateway liée")
    }

    @Test func option_visible_sauf_sans_gateway_et_sans_champ() throws {
        #expect(try session("online").doorbellAvailable)
        #expect(try session("offline").doorbellAvailable)
        #expect(try !session("none").doorbellAvailable)
        #expect(try !session(nil).doorbellAvailable)
        #expect(try session(nil).gateway?.online == true) // le bloc gateway reste lu
    }

    // MARK: option « Sonnette »

    private func backend(devices: String = "", available: Bool = true) -> TestBackend {
        let t = TestBackend(token: "jwt")
        t.route { r in
            switch (r.method, r.path) {
            case ("PUT", "/api/portal/push/devices"):
                let notify = r.body.contains(#""doorbell_notify":true"#)
                return MockReply(body: #"{"id":7,"platform":"ios","doorbell_notify":\#(notify)}"#)
            case ("GET", "/api/portal/doorbell/preferences"):
                return MockReply(body: #"{"available":\#(available),"devices":[\#(devices)]}"#)
            case ("DELETE", _): return MockReply(status: 204, body: "")
            default: return MockReply(status: 200, body: "{}")
            }
        }
        return t
    }

    @MainActor private func model(_ t: TestBackend, _ system: StaticPushSystem) -> DoorbellModel {
        DoorbellModel(push: t.container.push, system: system, appVersion: "9.9.9")
    }

    @MainActor @Test func activation_enregistre_l_appareil_avec_notification() async throws {
        let t = backend()
        let m = model(t, StaticPushSystem(authorization: .granted, token: "deadbeef"))
        await m.setNotify(true)
        #expect(m.notifyEnabled)
        let put = try #require(t.requests.first { $0.method == "PUT" })
        let body = try #require(try JSONSerialization.jsonObject(with: Data(put.body.utf8)) as? [String: Any])
        #expect(body["platform"] as? String == "ios")
        #expect(body["token"] as? String == "deadbeef")
        #expect(body["app_version"] as? String == "9.9.9")
        #expect(body["doorbell_notify"] as? Bool == true)
        #expect(t.container.push.devices.deviceId == 7)
    }

    @MainActor @Test func premiere_activation_demande_l_autorisation() async {
        let t = backend()
        let system = StaticPushSystem(authorization: .notDetermined, grantOnRequest: true)
        let m = model(t, system)
        await m.setNotify(true)
        #expect(system.requestCount == 1)
        #expect(m.notifyEnabled)
    }

    @MainActor @Test func autorisation_refusee_remet_l_interrupteur_a_zero() async {
        for system in [StaticPushSystem(authorization: .denied), StaticPushSystem(authorization: .notDetermined, grantOnRequest: false)] {
            let t = backend()
            let m = model(t, system)
            await m.setNotify(true)
            #expect(!m.notifyEnabled)
            #expect(m.message?.contains("Réglages") == true)
            #expect(!t.requests.contains { $0.method == "PUT" }, "aucun appareil enregistré sans autorisation")
        }
    }

    @MainActor @Test func desactivation_enregistre_notify_faux_sans_supprimer() async throws {
        let t = backend(devices: #"{"id":7,"platform":"ios","doorbell_notify":true}"#)
        t.container.push.devices.set(7)
        let m = model(t, StaticPushSystem())
        await m.load()
        #expect(m.notifyEnabled)
        await m.setNotify(false)
        #expect(!m.notifyEnabled)
        let put = try #require(t.requests.last { $0.method == "PUT" })
        #expect(put.body.contains(#""doorbell_notify":false"#))
        #expect(!t.requests.contains { $0.method == "DELETE" })
    }

    @MainActor @Test func etat_relu_a_l_ouverture() async {
        let on = backend(devices: #"{"id":7,"platform":"ios","doorbell_notify":true}"#)
        on.container.push.devices.set(7)
        let m = model(on, StaticPushSystem())
        await m.load()
        #expect(m.notifyEnabled)

        // Autre appareil du compte seulement : cet iPhone n'est pas abonné.
        let other = backend(devices: #"{"id":9,"platform":"android","doorbell_notify":true}"#)
        other.container.push.devices.set(7)
        let m2 = model(other, StaticPushSystem())
        await m2.load()
        #expect(!m2.notifyEnabled)
    }

    @MainActor @Test func autorisation_retiree_depuis_retombe_a_zero() async {
        let t = backend(devices: #"{"id":7,"platform":"ios","doorbell_notify":true}"#)
        t.container.push.devices.set(7)
        let m = model(t, StaticPushSystem(authorization: .denied))
        await m.load()
        #expect(!m.notifyEnabled)
    }

    // NR: NR-ios-28 essensys-hub/essensys-feature-lifecycle#61
    // La déconnexion supprime l'appareil côté cloud (sinon la sonnette notifierait un téléphone déconnecté).
    @MainActor @Test func deconnexion_supprime_l_appareil_NR_ios_28() async throws {
        let t = backend()
        let m = model(t, StaticPushSystem())
        await m.setNotify(true)
        #expect(t.container.push.devices.deviceId == 7)
        let session = SessionModel(container: t.container)
        await session.logout()
        let delete = try #require(t.requests.first { $0.method == "DELETE" })
        #expect(delete.path == "/api/portal/push/devices/7")
        #expect(delete.headers["Authorization"] == "Bearer jwt", "la suppression part avec la session d'avant")
        #expect(t.container.push.devices.deviceId == nil)
    }

    @MainActor @Test func deconnexion_sans_appareil_n_appelle_pas_le_cloud() async {
        let t = backend()
        let session = SessionModel(container: t.container)
        await session.logout()
        #expect(!t.requests.contains { $0.method == "DELETE" })
    }

    @MainActor @Test func cloud_sans_route_push_laisse_l_interrupteur_a_zero() async {
        let t = TestBackend(token: "jwt")
        t.route { _ in MockReply(status: 404, body: "Not found") }
        let m = model(t, StaticPushSystem())
        await m.load()
        #expect(!m.notifyEnabled)
        await m.setNotify(true)
        #expect(!m.notifyEnabled)
        #expect(m.message == DoorbellModel.failureMessage)
    }
}
