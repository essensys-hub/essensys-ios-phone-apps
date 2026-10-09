import Foundation
import Testing
@testable import essensys_iphone

/// Anti-rebond indépendant du temps (spec domotic-controls « Double appui ») : tant qu'une commande est
/// en vol pour une cible, les appuis suivants sur la même cible sont ignorés.
@MainActor struct ControlModelTests {
    // NR: NR-ios-9 essensys-hub/essensys-ios-phone-apps#4
    @Test func second_press_while_in_flight_is_ignored_NR_ios_9() async throws {
        let t = TestBackend(token: "jwt")
        t.route { _ in Thread.sleep(forTimeInterval: 0.3); return MockReply(body: #"{"guid":"g","params":[]}"#) }
        let model = ControlModel(control: t.container.control)
        let salon = IndexTable.lights.first { $0.id == "salon" }!
        #expect(model.send(key: "salon-on", label: "Salon", injections: [salon.command(on: true)]))
        #expect(!model.send(key: "salon-on", label: "Salon", injections: [salon.command(on: true)]))
        // Une autre cible n'est pas bloquée.
        #expect(model.send(key: "salon-off", label: "Salon", injections: [salon.command(on: false)]))
        let deadline = Date().addingTimeInterval(5)
        while !model.inFlight.isEmpty && Date() < deadline { try await Task.sleep(for: .milliseconds(20)) }
        #expect(t.requests.filter { $0.body == #"{"k":612,"v":"128"}"# }.count == 1)
        // Une fois la réponse reçue, un nouvel appui repart normalement.
        #expect(model.send(key: "salon-on", label: "Salon", injections: [salon.command(on: true)]))
    }
}
