import Foundation
import Testing
@testable import essensys_iphone

/// Rafraîchissement cloud : la dernière action est interrogée bien plus souvent que la session, et plus
/// aucune requête ne part une fois la tâche annulée (app hors premier plan). Jumeau de SessionPollingTest.kt.
@MainActor struct SessionPollingTests {
    @Test func polls_at_portal_cadence_and_stops_when_cancelled() async throws {
        let t = TestBackend(token: "jwt")
        t.route { request in
            request.path == "/api/portal/session"
                ? MockReply(body: #"{"gateway":{"online":true}}"#)
                : MockReply(body: #"{"lastAction":null}"#)
        }
        let model = SessionModel(container: t.container, sessionPeriod: .seconds(60), lastActionPeriod: .milliseconds(50))
        let task = Task { await model.pollWhileVisible() }
        let count = { (path: String) in t.requests.filter { $0.path == path }.count }
        let deadline = Date().addingTimeInterval(5)
        while count("/api/portal/history/latest") < 4 && Date() < deadline { try await Task.sleep(for: .milliseconds(20)) }
        #expect(count("/api/portal/session") == 1)
        #expect(count("/api/portal/history/latest") >= 4)
        #expect(model.gatewayOnline == true)

        task.cancel()
        _ = await task.value
        let frozen = t.requests.count
        try await Task.sleep(for: .milliseconds(300))
        #expect(t.requests.count == frozen)
    }
}
