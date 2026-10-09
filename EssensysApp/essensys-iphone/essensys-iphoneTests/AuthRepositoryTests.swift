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
}
