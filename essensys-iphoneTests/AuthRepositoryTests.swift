import Foundation
import Testing
@testable import essensys_iphone

struct AuthRepositoryTests {
    @Test func cloud_login_stores_jwt_and_shows_home() async {
        let t = TestBackend()
        t.enqueue(200, TestBackend.fixture("cloud_login_ok"))
        #expect(await t.container.auth.login(email: "demo@essensys.fr", password: "x") == .loggedIn)
        #expect(t.store.state.token == "jwt-demo")
        #expect(t.requests.first?.path == "/api/auth/login")
        #expect(t.requests.first?.body.contains("\"email\":\"demo@essensys.fr\"") == true)
    }

    @Test func invalid_credentials_show_generic_message() async {
        let t = TestBackend()
        t.enqueue(401, "Invalid credentials\n", headers: [:])
        #expect(await t.container.auth.login(email: "demo@essensys.fr", password: "x") == .failed("Email ou mot de passe incorrect."))
        #expect(t.store.state.token == nil)
    }

    // NR: NR-ios-2 essensys-hub/essensys-ios-phone-apps#2
    @Test func unauthorized_response_clears_session_and_shows_login_NR_ios_2() async {
        let t = TestBackend(token: "expired-jwt")
        t.enqueue(401, "Unauthorized\n", headers: [:])
        if case .success = await t.container.portal.gatewayOnline() { Issue.record("attendu un échec") }
        #expect(t.store.state.token == nil)
        #expect(!t.store.state.isAuthenticated)
        #expect(t.requests.first?.headers["Authorization"] == "Bearer expired-jwt")
    }

    // NR: NR-ios-3 essensys-hub/essensys-ios-phone-apps#2
    @Test func password_change_required_blocks_app_until_changed_NR_ios_3() async {
        let t = TestBackend()
        t.enqueue(200, TestBackend.fixture("cloud_login_temp_password"))
        #expect(await t.container.auth.login(email: "demo@essensys.fr", password: "tmp") == .mustChangePassword)
        #expect(t.store.state.passwordChangeRequired)

        t.store.update { $0.passwordChangeRequired = false }
        t.enqueue(409, #"{"error":"password_change_required","redirect":"/change-password"}"#)
        _ = await t.container.portal.gatewayOnline()
        #expect(t.store.state.passwordChangeRequired)
        #expect(t.store.state.token == "jwt-temp")

        t.enqueue(200, #"{"message":"Mot de passe mis à jour."}"#)
        if case .failure = await t.container.auth.changePassword(current: "tmp", new: "nouveau-456") { Issue.record("attendu un succès") }
        #expect(!t.store.state.passwordChangeRequired)
        #expect(t.store.state.token == "jwt-temp")
    }

    @Test func weak_password_error_is_readable() async {
        let t = TestBackend(token: "jwt")
        t.enqueue(400, #"{"error":"weak_password","message":"Le mot de passe doit contenir au moins 8 caractères."}"#)
        guard case let .failure(error) = await t.container.auth.changePassword(current: "a", new: "b") else { Issue.record("échec attendu"); return }
        #expect(error.userMessage == "Le mot de passe doit contenir au moins 8 caractères.")
    }

    @Test func lan_login_keeps_session_cookie_and_sends_it_back() async {
        let t = TestBackend(mode: .lan)
        t.enqueue(200, TestBackend.fixture("lan_login_ok"), headers: [
            "Content-Type": "application/json",
            "Set-Cookie": "essensys_lan_session=abc123; Path=/; HttpOnly; Secure; SameSite=Lax; Max-Age=604800",
        ])
        #expect(await t.container.auth.login(email: "admin@essensys.local", password: "x") == .loggedIn)
        #expect(t.store.state.lanCookie == "abc123")
        t.enqueue(200, TestBackend.fixture("lan_login_ok"))
        _ = await t.container.portal.lanSessionValid()
        #expect(t.requests.last?.headers["Cookie"] == "essensys_lan_session=abc123")
    }

    @Test func lan_password_change_ends_session() async {
        let t = TestBackend(mode: .lan)
        t.store.update { $0.lanCookie = "abc" }
        t.enqueue(200, #"{"status":"ok"}"#)
        if case .failure = await t.container.auth.changePassword(current: "a", new: "bcdefghi") { Issue.record("succès attendu") }
        #expect(t.store.state.lanCookie == nil)
        #expect(t.requests.first?.method == "PUT")
    }

    @Test func forbidden_account_clears_session() async {
        let t = TestBackend(token: "jwt")
        t.enqueue(403, #"{"error":"account_forbidden","redirect":"/maintenance/"}"#)
        _ = await t.container.portal.gatewayOnline()
        #expect(t.store.state.token == nil)
    }

    // MARK: Session mémorisée (session-30-jours-2026-11-001, tâche 1.2)

    private static let expiry = "2026-12-06T09:00:00.123456789Z"

    @Test func remember_me_cloud_login_stores_the_session_and_the_server_expiry() async {
        let t = TestBackend()
        t.enqueue(200, #"{"token":"jwt-demo","password_change_required":false,"remember_token":"rem-abc","remember_expires_at":"\#(Self.expiry)"}"#)
        #expect(await t.container.auth.login(email: "demo@essensys.fr", password: "x", rememberMe: true) == .loggedIn)
        #expect(t.requests.first?.body.contains(#""remember_me":true"#) == true)
        #expect(t.store.state.token == "jwt-demo")
        #expect(t.store.state.rememberToken == "rem-abc")
        let until = t.store.state.rememberExpiresAt?.timeIntervalSince1970 ?? 0
        #expect(abs(until - 1_796_547_600.123) < 0.01)
    }

    @Test func login_without_the_option_sends_no_remember_me_and_keeps_nothing() async {
        let t = TestBackend()
        t.enqueue(200, #"{"token":"jwt-demo","remember_token":"rem-abc","remember_expires_at":"\#(Self.expiry)"}"#)
        #expect(await t.container.auth.login(email: "demo@essensys.fr", password: "x") == .loggedIn)
        #expect(t.requests.first?.body.contains("remember_me") == false)
        #expect(t.store.state.rememberToken == nil)
        #expect(t.store.state.rememberExpiresAt == nil)
    }

    // Test « server without remember support falls back »
    @Test func server_without_remember_support_falls_back_without_error() async {
        let t = TestBackend()
        t.enqueue(200, TestBackend.fixture("cloud_login_ok"))
        #expect(await t.container.auth.login(email: "demo@essensys.fr", password: "x", rememberMe: true) == .loggedIn)
        #expect(t.store.state.token == "jwt-demo")
        #expect(t.store.state.rememberToken == nil)
        #expect(t.store.state.rememberExpiresAt == nil)
        #expect(!t.store.state.sessionEnded)
    }

    @Test func lan_remember_login_keeps_only_the_expiry_of_the_body() async {
        let t = TestBackend(mode: .lan)
        let cookie = ["Content-Type": "application/json", "Set-Cookie": "essensys_lan_session=abc123; Path=/; HttpOnly; Secure; Max-Age=2592000"]
        t.enqueue(200, #"{"user":{"id":1},"remember_expires_at":"\#(Self.expiry)"}"#, headers: cookie)
        #expect(await t.container.auth.login(email: "admin@essensys.local", password: "x", rememberMe: true) == .loggedIn)
        #expect(t.store.state.lanCookie == "abc123")
        #expect(t.store.state.rememberToken == nil)
        #expect(t.store.state.rememberExpiresAt != nil)

        // Gateway sans stockage : session classique, sans date, sans erreur.
        let plain = TestBackend(mode: .lan)
        plain.enqueue(200, TestBackend.fixture("lan_login_ok"), headers: cookie)
        #expect(await plain.container.auth.login(email: "admin@essensys.local", password: "x", rememberMe: true) == .loggedIn)
        #expect(plain.store.state.rememberExpiresAt == nil)
    }

    // MARK: Fin de session (tâche 2.2)

    private static func remembered(_ t: TestBackend, until: Date = Date().addingTimeInterval(10 * 86_400)) {
        t.store.update { $0.token = "old-jwt"; $0.rememberToken = "rem-secret"; $0.rememberExpiresAt = until }
    }

    // Test « logout revokes remember session »
    @Test func logout_revokes_the_remembered_session_and_clears_locally() async {
        let t = TestBackend()
        Self.remembered(t)
        let store = t.store
        let atRequest = LockedValue<String>("pas appelé")
        t.route { _ in atRequest.set(store.state.rememberToken ?? "effacée"); return MockReply(body: "") }
        await t.container.auth.logout()
        #expect(t.requests.first?.path == "/api/auth/logout")
        #expect(t.requests.first?.body == #"{"remember_token":"rem-secret"}"#)
        // La session locale était déjà effacée quand la révocation est partie : le réseau n'est jamais attendu.
        #expect(atRequest.get() == "effacée")
        #expect(!t.store.state.isAuthenticated)
        #expect(t.store.state.rememberToken == nil)
        #expect(t.store.state.rememberExpiresAt == nil)
    }

    @Test func logout_offline_clears_before_any_network_and_shows_no_error() async {
        let t = TestBackend()
        Self.remembered(t)
        MockURLProtocol.unregister(host: t.host) // aucun réseau : la requête échoue (cannotConnectToHost)
        await t.container.auth.logout()
        #expect(!t.store.state.isAuthenticated)
        #expect(t.store.state.rememberToken == nil)
        #expect(t.store.state.rememberExpiresAt == nil)
        #expect(!t.store.state.sessionEnded)
    }

    @Test func lan_logout_sends_the_cookie_it_just_cleared() async {
        let t = TestBackend(mode: .lan)
        t.store.update { $0.lanCookie = "abc"; $0.rememberExpiresAt = Date().addingTimeInterval(86_400) }
        t.enqueue(200, "")
        await t.container.auth.logout()
        #expect(t.requests.first?.headers["Cookie"] == "essensys_lan_session=abc")
        #expect(t.requests.first?.body == "")
        #expect(t.store.state.lanCookie == nil)
        #expect(t.store.state.rememberExpiresAt == nil)
    }

    @Test func cloud_password_change_forgets_the_remembered_session_but_keeps_access() async {
        let t = TestBackend()
        Self.remembered(t)
        t.enqueue(200, #"{"message":"Mot de passe mis à jour."}"#)
        if case .failure = await t.container.auth.changePassword(current: "a", new: "bcdefghi") { Issue.record("succès attendu") }
        #expect(t.store.state.token == "old-jwt")
        #expect(t.store.state.rememberToken == nil)
        #expect(t.store.state.rememberExpiresAt == nil)
    }
}

/// Valeur partagée entre un test et le gestionnaire du backend simulé (qui tourne sur un autre fil).
final class LockedValue<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Value
    init(_ value: Value) { self.value = value }
    func get() -> Value { lock.withLock { value } }
    func set(_ next: Value) { lock.withLock { value = next } }
    func update(_ change: (inout Value) -> Void) { lock.withLock { change(&value) } }
}
