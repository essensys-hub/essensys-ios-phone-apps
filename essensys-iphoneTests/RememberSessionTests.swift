import Foundation
import Testing
@testable import essensys_iphone

/// Renouvellement transparent de l'accès cloud par la session mémorisée (session-30-jours-2026-11-001, tâche 2.1)
/// et NR-ios-22. Mêmes cas que RememberSessionTest.kt (Android).
@Suite struct RememberSessionTests {
    private static let session = TestBackend.fixture("portal_session_online")

    private final class Counter: @unchecked Sendable {
        private let lock = NSLock()
        private var n = 0
        func bump() -> Int { lock.withLock { n += 1; return n } }
        var count: Int { lock.withLock { n } }
    }

    /// Cloud connecté avec une session mémorisée de 10 jours et un accès « old-jwt » que le serveur refuse.
    private static func remembered(until: Date = Date().addingTimeInterval(10 * 86_400)) -> TestBackend {
        let t = TestBackend()
        t.store.update { $0.token = "old-jwt"; $0.rememberToken = "rem-secret"; $0.rememberExpiresAt = until }
        return t
    }

    /// Le serveur refuse `old-jwt`, accepte tout autre jeton ; le renouvellement répond `refresh`.
    private static func serve(_ t: TestBackend, refreshes: Counter = Counter(), refresh: @escaping @Sendable () -> MockReply) {
        t.route { r in
            switch r.path {
            case "/api/portal/session":
                return r.headers["Authorization"] == "Bearer old-jwt"
                    ? MockReply(status: 401, body: "Unauthorized\n", headers: [:]) : MockReply(body: session)
            case "/api/auth/remember/refresh": _ = refreshes.bump(); return refresh()
            default: return MockReply(status: 404, body: "{}")
            }
        }
    }

    private static let renewed: @Sendable () -> MockReply = { MockReply(body: #"{"token":"new-jwt","password_change_required":false}"#) }

    @Test func expired_access_is_renewed_and_the_request_replayed() async {
        let t = Self.remembered()
        let until = t.store.state.rememberExpiresAt
        Self.serve(t, refresh: Self.renewed)
        guard case .success = await t.container.portal.session() else { Issue.record("succès attendu"); return }
        #expect(t.requests.map(\.path) == ["/api/portal/session", "/api/auth/remember/refresh", "/api/portal/session"])
        #expect(t.requests[1].headers["Authorization"] == nil)
        #expect(t.requests[1].body == #"{"remember_token":"rem-secret"}"#)
        #expect(t.requests[2].headers["Authorization"] == "Bearer new-jwt")
        #expect(t.store.state.token == "new-jwt")
        #expect(t.store.state.rememberToken == "rem-secret")
        #expect(t.store.state.rememberExpiresAt == until)
    }

    // Test « token refresh is single flight »
    @Test func four_simultaneous_requests_share_one_renewal() async {
        let t = Self.remembered()
        let refreshes = Counter()
        Self.serve(t, refreshes: refreshes, refresh: Self.renewed)
        let portal = t.container.portal
        let succeeded = await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<4 { group.addTask { if case .success = await portal.session() { true } else { false } } }
            return await group.reduce(0) { $0 + ($1 ? 1 : 0) }
        }
        #expect(succeeded == 4)
        #expect(refreshes.count == 1)
        #expect(t.store.state.token == "new-jwt")
    }

    @Test func refused_renewal_ends_the_session_and_says_so() async {
        let t = Self.remembered()
        Self.serve(t) { MockReply(status: 401, body: #"{"error":"remember_invalid"}"#) }
        guard case let .failure(error) = await t.container.portal.session() else { Issue.record("échec attendu"); return }
        #expect(error == .unauthorized(code: nil, text: "Unauthorized"))
        let state = t.store.state
        #expect(!state.isAuthenticated)
        #expect(state.rememberToken == nil)
        #expect(state.rememberExpiresAt == nil)
        #expect(state.sessionEnded)
        #expect(t.requests.map(\.path) == ["/api/portal/session", "/api/auth/remember/refresh"])
    }

    @Test func disabled_account_on_renewal_also_ends_the_session() async {
        let t = Self.remembered()
        Self.serve(t) { MockReply(status: 403, body: #"{"error":"account_forbidden","redirect":"/maintenance/"}"#) }
        _ = await t.container.portal.session()
        #expect(!t.store.state.isAuthenticated)
        #expect(t.store.state.sessionEnded)
    }

    @Test func unreachable_server_keeps_the_session_and_is_not_a_401() async {
        let t = Self.remembered()
        Self.serve(t) { MockReply(status: 503, body: #"{"error":"unavailable"}"#) }
        guard case let .failure(error) = await t.container.portal.session() else { Issue.record("échec attendu"); return }
        if case .unauthorized = error { Issue.record("un 401 ferait effacer la session mémorisée") }
        #expect(t.store.state.token == "old-jwt")
        #expect(t.store.state.rememberToken == "rem-secret")
        #expect(!t.store.state.sessionEnded)
    }

    @Test func without_a_remembered_session_the_password_is_asked_again() async {
        let t = TestBackend(token: "old-jwt")
        Self.serve(t, refresh: Self.renewed)
        _ = await t.container.portal.session()
        #expect(t.requests.map(\.path) == ["/api/portal/session"])
        #expect(!t.store.state.isAuthenticated)
        #expect(!t.store.state.sessionEnded)
    }

    @Test func authentication_routes_are_never_renewed() async {
        let t = Self.remembered()
        t.enqueue(401, #"{"error":"invalid_current_password"}"#)
        _ = await t.container.auth.changePassword(current: "faux", new: "nouveau-456")
        #expect(t.requests.map(\.path) == ["/api/auth/password/change"])
        #expect(t.store.state.rememberToken == "rem-secret")
    }

    @Test func a_session_past_its_end_is_not_renewed_and_says_so() async {
        let t = Self.remembered(until: Date().addingTimeInterval(-60))
        Self.serve(t, refresh: Self.renewed)
        _ = await t.container.portal.session()
        #expect(t.requests.map(\.path) == ["/api/portal/session"])
        #expect(!t.store.state.isAuthenticated)
        #expect(t.store.state.sessionEnded)
    }

    // NR: NR-ios-22 essensys-hub/essensys-ios-phone-apps#37
    // Les 30 jours partent de la saisie du mot de passe : renouveler chaque jour ne les prolonge jamais.
    @Test func remembered_session_is_never_extended_by_use_NR_ios_22() async {
        let day: TimeInterval = 86_400
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let appNow = LockedValue(start)
        let skew: TimeInterval = 2 * 3_600 // le serveur avance de 2 h sur le téléphone
        let expires = start.addingTimeInterval(30 * day)
        let formatted = ISO8601DateFormatter().string(from: expires)
        let jwtLifetime: TimeInterval = 12 * 3_600

        // État du serveur simulé : le dernier accès émis et l'instant (serveur) de son émission.
        let server = LockedValue((jwt: "jwt-0", issuedAt: start.addingTimeInterval(skew), accepted: 0, refused: 0))
        let t = TestBackend(now: { appNow.get() })
        t.route { r in
            let serverNow = appNow.get().addingTimeInterval(skew)
            switch r.path {
            case "/api/auth/login":
                return MockReply(body: #"{"token":"jwt-0","remember_token":"rem-nr22","remember_expires_at":"\#(formatted)"}"#)
            case "/api/portal/session":
                let live = server.get().jwt, issued = server.get().issuedAt
                return r.headers["Authorization"] == "Bearer \(live)" && serverNow < issued.addingTimeInterval(jwtLifetime)
                    ? MockReply(body: Self.session) : MockReply(status: 401, body: "Unauthorized\n", headers: [:])
            case "/api/auth/remember/refresh":
                if serverNow >= expires {
                    server.update { $0.refused += 1 }
                    return MockReply(status: 401, body: #"{"error":"remember_invalid"}"#)
                }
                var jwt = ""
                server.update { $0.accepted += 1; jwt = "jwt-\($0.accepted)"; $0.jwt = jwt; $0.issuedAt = serverNow }
                return MockReply(body: #"{"token":"\#(jwt)","password_change_required":false}"#)
            default: return MockReply(status: 404, body: "{}")
            }
        }

        #expect(await t.container.auth.login(email: "demo@essensys.fr", password: "x", rememberMe: true) == .loggedIn)
        #expect(t.store.state.rememberExpiresAt == expires)

        for dayNumber in 1...29 {
            appNow.set(start.addingTimeInterval(Double(dayNumber) * day))
            guard case .success = await t.container.portal.session() else { Issue.record("jour \(dayNumber) : succès attendu"); return }
            #expect(t.store.state.rememberExpiresAt == expires, "jour \(dayNumber) : la fin ne doit jamais bouger")
        }
        #expect(server.get().accepted == 29)

        // 30 jours moins une heure à la montre du téléphone, mais le serveur est déjà 1 h après la fin.
        appNow.set(expires.addingTimeInterval(-3_600))
        guard case .failure = await t.container.portal.session() else { Issue.record("le 30e jour doit être refusé"); return }
        #expect(server.get().refused == 1)
        #expect(!t.store.state.isAuthenticated)
        #expect(t.store.state.sessionEnded)
        #expect(t.store.state.rememberToken == nil)
    }
}
