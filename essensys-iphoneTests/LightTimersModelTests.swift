import Foundation
import Testing
@testable import essensys_iphone

/// Relecture 5/10/20 s après un envoi, valeur commune aux deux écrans (lumieres-temporisees-2026-11-003, tâche 7.2).
@MainActor struct LightTimersModelTests {
    private static let before = #"{"timers":[{"id":"dressing","label":"Dressing","key":521,"minutes":15}]}"#
    private static let after = #"{"timers":[{"id":"dressing","label":"Dressing","key":521,"minutes":30}]}"#

    @Test func default_recheck_pauses_are_5_10_and_20_seconds() {
        let total = LightTimersModel.recheckPauses.reduce(0.0) { $0 + Double($1.components.seconds) }
        #expect(LightTimersModel.recheckPauses.count == 3)
        #expect(total == 20)
        #expect(LightTimersModel.recheckPauses.first == .seconds(5))
    }

    @Test func load_then_send_rereads_until_the_armoire_confirms() async {
        let t = TestBackend(token: "jwt")
        let model = LightTimersModel(comfort: t.container.comfort, pauses: [.milliseconds(10), .milliseconds(10), .milliseconds(10)])
        t.enqueue(200, Self.before)
        await model.load()
        #expect(model.state("dressing")?.display == "15 min")
        #expect(model.state("wc1")?.display == "Inconnue")

        t.enqueue(200, #"{"id":"dressing","minutes":30,"status":"queued"}"#)
        t.enqueue(200, Self.before) // première relecture : pas encore appliqué
        t.enqueue(200, Self.after)  // deuxième : confirmé, plus de relecture
        model.set("dressing", minutes: 30)
        for _ in 0..<200 where model.state("dressing")?.minutes != 30 || model.waiting.contains("dressing") { try? await Task.sleep(for: .milliseconds(20)) }
        #expect(model.state("dressing")?.display == "30 min")
        #expect(!model.waiting.contains("dressing"))
        #expect(t.requests.map(\.method) == ["GET", "PUT", "GET", "GET"])
        #expect(model.feedback?.kind == .success)
    }

    @Test func dry_run_does_not_reread() async {
        let t = TestBackend(token: "jwt", testMode: true)
        let model = LightTimersModel(comfort: t.container.comfort, pauses: [.milliseconds(10)])
        t.enqueue(200, #"{"id":"dressing","minutes":30,"status":"dry_run"}"#)
        model.set("dressing", minutes: 30)
        for _ in 0..<100 where model.sending.contains("dressing") || model.feedback == nil { try? await Task.sleep(for: .milliseconds(20)) }
        try? await Task.sleep(for: .milliseconds(100))
        #expect(model.feedback?.kind == .info)
        #expect(t.requests.map(\.method) == ["PUT"])
        #expect(model.waiting.isEmpty)
    }
}
