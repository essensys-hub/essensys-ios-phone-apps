import Testing
@testable import essensys_iphone

/// Mêmes scénarios que HeatingRepositoryTest.kt (Android).
struct HeatingRepositoryTests {
    private let jour = IndexTable.heatingZones.first { $0.id == "jour" }!
    private let sdb1 = IndexTable.heatingZones.first { $0.id == "sdb1" }!
    private let forty = (13..<53).map { Injection(k: $0, v: "17") }

    private func collect<T>(_ stream: AsyncStream<T>) async -> [T] {
        var out: [T] = []
        for await event in stream { out.append(event) }
        return out
    }

    @Test func read_schedule_decodes_zone_and_reports_stale() async {
        let t = TestBackend(token: "jwt")
        t.enqueue(200, TestBackend.fixture("exchange_stale"))
        guard case let .success(read) = await t.container.heating.readSchedule(jour) else { Issue.record("succès attendu"); return }
        #expect(read.stale)
        #expect(read.grid[0, 0] == 1 && read.grid[0, 1] == 1) // 17 = 0x11
        #expect(t.requests.first?.query == "keys=" + (13...96).map(String.init).joined(separator: ","))
    }

    @Test func save_sends_chunks_in_order_and_reports_progress() async {
        let t = TestBackend(token: "jwt")
        for _ in 0..<2 { t.enqueue(200, TestBackend.fixture("inject_batch_ok")) }
        let events = await collect(t.container.heating.save(forty))
        #expect(events == [
            .start(totalParams: 40, chunkCount: 2),
            .sending(chunkIndex: 1, chunkCount: 2, indexMin: 13, indexMax: 42), .chunkSent(chunkIndex: 1, chunkCount: 2),
            .sending(chunkIndex: 2, chunkCount: 2, indexMin: 43, indexMax: 52), .chunkSent(chunkIndex: 2, chunkCount: 2),
            .done(.sent),
        ])
        #expect(t.requests.map { $0.body.hasPrefix(#"{"params":[{"k":13,"#) } == [true, false])
        #expect(t.requests.last?.body.hasPrefix(#"{"params":[{"k":43,"#) == true)
    }

    @Test func failed_chunk_stops_sending_and_keeps_pending_bytes() async {
        let t = TestBackend(token: "jwt")
        t.enqueue(200, TestBackend.fixture("inject_batch_ok"))
        t.enqueue(429, "Rate limit exceeded\n", headers: [:])
        guard case let .failed(index, _, error, sent, pending) = await collect(t.container.heating.save(forty)).last else {
            Issue.record("échec attendu"); return
        }
        #expect(index == 2)
        #expect(error == .rateLimited)
        #expect(sent == Array(forty.prefix(30)))
        #expect(pending == Array(forty.dropFirst(30)))
        #expect(t.requests.count == 2)
    }

    @Test func cancelling_save_stops_between_chunks() async {
        let t = TestBackend(token: "jwt")
        t.route { _ in MockReply(body: TestBackend.fixture("inject_batch_ok")) }
        let stream = t.container.heating.save(forty)
        var events: [SaveEvent] = []
        for await event in stream {
            events.append(event)
            if case .chunkSent(1, _) = event { break } // le consommateur s'arrête : la tâche est annulée
        }
        try? await Task.sleep(for: .milliseconds(200))
        #expect(t.requests.count <= 2)
        #expect(!events.contains(.done(.sent)))
    }

    // NR: NR-ios-14 essensys-hub/essensys-ios-phone-apps#12
    @Test func immediate_mode_sends_zone_mode_index_NR_ios_14() async {
        let t = TestBackend(token: "jwt")
        t.enqueue(200, TestBackend.fixture("inject_ok"))
        _ = await t.container.heating.setMode(sdb1, .forceConfort)
        #expect(t.requests.first?.body == #"{"k":351,"v":"17"}"#)
    }

    @Test func lan_sync_polls_status_then_rereads_schedule() async {
        let t = TestBackend(mode: .lan)
        t.store.update { $0.lanCookie = "abc" }
        // Périodes courtes : même hôte simulé, conteneur dédié.
        let container = AppContainer(store: t.store, guardNoArmoire: true, protocolClasses: [MockURLProtocol.self],
                                     syncPoll: .milliseconds(10), syncTimeout: .seconds(1))
        t.enqueue(200, TestBackend.fixture("heating_sync_started"))
        t.enqueue(200, #"{"active":true,"received":30,"total":84,"chunksTotal":3,"chunksCompleted":1}"#)
        t.enqueue(200, TestBackend.fixture("heating_sync_done"))
        t.enqueue(200, #"{"values":[{"k":13,"v":"33"}]}"#)
        let events = await collect(container.heating.syncFromArmoire(jour))
        #expect(Array(events.dropLast()) == [.progress(received: 0, total: 84), .progress(received: 30, total: 84), .progress(received: 84, total: 84)])
        guard case let .done(read, complete) = events.last else { Issue.record("fin attendue"); return }
        #expect(complete)
        #expect(read.grid[0, 0] == 1)
        #expect(t.requests.first?.path == "/api/admin/heating/sync")
        #expect(t.requests.first?.body == #"{"byteCount":84,"startIndex":13}"#)
        #expect(t.requests[1].query == "startIndex=13&byteCount=84")
    }

    @Test func lan_sync_busy_is_reported() async {
        let t = TestBackend(mode: .lan)
        t.enqueue(409, TestBackend.fixture("heating_sync_busy"))
        #expect(await collect(t.container.heating.syncFromArmoire(jour)) == [.busy])
    }

    @Test func cloud_sync_only_rereads_cache() async {
        let t = TestBackend(token: "jwt")
        t.enqueue(200, TestBackend.fixture("exchange_stale"))
        guard case .cacheOnly = await collect(t.container.heating.syncFromArmoire(jour)).first else { Issue.record("cache attendu"); return }
        #expect(t.requests.first?.path == "/api/portal/exchange")
    }
}
