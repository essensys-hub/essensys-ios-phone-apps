//
//  HeatingRepository.swift
//  Chauffage : planning des zones et mode immédiat (spec heating-control), jumeau de HeatingRepository.kt.
//  Lecture et écriture via ControlRepository (exchange, lots de 30) ; heating/sync réel en LAN seulement.
//

import Foundation

/// Planning lu ; stale = cache cloud ancien ou vide.
struct ScheduleRead: Equatable, Sendable {
    let grid: ScheduleGrid
    let stale: Bool
}

/// Progression de l'enregistrement du planning (design D3), indices de lot à partir de 1.
enum SaveEvent: Equatable, Sendable {
    case start(totalParams: Int, chunkCount: Int)
    case sending(chunkIndex: Int, chunkCount: Int, indexMin: Int, indexMax: Int)
    case chunkSent(chunkIndex: Int, chunkCount: Int)
    /// Arrêt de l'envoi : sent = couples déjà acceptés par le serveur, pending = reste à envoyer.
    case failed(chunkIndex: Int, chunkCount: Int, error: APIError, sent: [Injection], pending: [Injection])
    case done(InjectOutcome)
}

/// Synchronisation du planning depuis l'armoire.
enum SyncEvent: Equatable, Sendable {
    case progress(received: Int, total: Int)
    case busy
    /// Cloud : pas de lecture réelle, seulement le dernier cache reçu de la gateway.
    case cacheOnly(ScheduleRead)
    case done(ScheduleRead, complete: Bool)
    case failed(APIError)
}

final class HeatingRepository: Sendable {
    private let api: APIClient
    private let store: SessionStore
    private let auth: AuthRepository
    private let control: ControlRepository
    private let syncPoll: Duration
    private let syncTimeout: Duration

    init(api: APIClient, store: SessionStore, auth: AuthRepository, control: ControlRepository,
         syncPoll: Duration = .seconds(3), syncTimeout: Duration = .seconds(90)) {
        self.api = api
        self.store = store
        self.auth = auth
        self.control = control
        self.syncPoll = syncPoll
        self.syncTimeout = syncTimeout
    }

    func readSchedule(_ zone: IndexTable.HeatingZone) async -> Result<ScheduleRead, APIError> {
        await control.readExchangeSnapshot(keys: Array(zone.scheduleIndices)).map {
            ScheduleRead(grid: ScheduleCodec.decode($0.values, scheduleStart: zone.scheduleStart), stale: $0.stale)
        }
    }

    /// Envoi séquentiel des lots ; s'arrête au premier échec (comme le portail) ou si la tâche est annulée.
    func save(_ changes: [Injection]) -> AsyncStream<SaveEvent> {
        let control = self.control
        return AsyncStream { continuation in
            let task = Task {
                let chunks = IndexTable.chunk(changes)
                continuation.yield(.start(totalParams: changes.count, chunkCount: chunks.count))
                var outcome = InjectOutcome.sent
                for (i, chunk) in chunks.enumerated() {
                    if Task.isCancelled { break }
                    continuation.yield(.sending(chunkIndex: i + 1, chunkCount: chunks.count,
                                                indexMin: chunk.map(\.k).min() ?? 0, indexMax: chunk.map(\.k).max() ?? 0))
                    switch await control.injectBatch(chunk) {
                    case let .failure(error):
                        continuation.yield(.failed(chunkIndex: i + 1, chunkCount: chunks.count, error: error,
                                                   sent: Array(chunks.prefix(i).joined()), pending: Array(chunks.dropFirst(i).joined())))
                        continuation.finish()
                        return
                    case let .success(value):
                        if value == .dryRunOK { outcome = .dryRunOK }
                        continuation.yield(.chunkSent(chunkIndex: i + 1, chunkCount: chunks.count))
                    }
                }
                if !Task.isCancelled { continuation.yield(.done(outcome)) }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func setMode(_ zone: IndexTable.HeatingZone, _ mode: IndexTable.ImmediateMode) async -> Result<InjectOutcome, APIError> {
        guard let injection = zone.command(mode) else { return .failure(.invalidRequest("\(mode.label) non proposé pour \(zone.name)")) }
        return await control.inject(injection)
    }

    func syncFromArmoire(_ zone: IndexTable.HeatingZone) -> AsyncStream<SyncEvent> {
        AsyncStream { continuation in
            let task = Task { [self] in
                await runSync(zone, continuation)
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func runSync(_ zone: IndexTable.HeatingZone, _ continuation: AsyncStream<SyncEvent>.Continuation) async {
        if store.state.mode == .cloud {
            switch await readSchedule(zone) {
            case let .failure(error): continuation.yield(.failed(error))
            case let .success(read): continuation.yield(.cacheOnly(read))
            }
            return
        }
        let body = HeatingSyncRequest(startIndex: zone.scheduleStart, byteCount: IndexTable.scheduleBytes)
        switch await api.send("POST", "/api/admin/heating/sync", body: body) {
        case let .failure(error):
            if case .http(409, _, _) = error { continuation.yield(.busy) } else {
                auth.handle(error)
                continuation.yield(.failed(error))
            }
            return
        case let .success(response):
            if let sync = (try? JSONDecoder().decode(HeatingSyncStarted.self, from: response.body))?.sync {
                continuation.yield(.progress(received: sync.received ?? 0, total: sync.total ?? 0))
            }
        }
        let path = "/api/admin/heating/sync/status?startIndex=\(zone.scheduleStart)&byteCount=\(IndexTable.scheduleBytes)"
        let clock = ContinuousClock()
        let deadline = clock.now + syncTimeout
        var complete = false
        var finished = false
        while !Task.isCancelled {
            switch await api.get(path) {
            case let .failure(error):
                auth.handle(error)
                continuation.yield(.failed(error))
                return
            case let .success(response):
                let status = (try? JSONDecoder().decode(HeatingSyncStatus.self, from: response.body)) ?? HeatingSyncStatus()
                let received = status.received ?? 0, total = status.total ?? 0
                continuation.yield(.progress(received: received, total: total))
                if status.active != true && received >= total { complete = total > 0; finished = true }
            }
            if finished || clock.now >= deadline { break }
            try? await Task.sleep(for: syncPoll)
        }
        switch await readSchedule(zone) {
        case let .failure(error): continuation.yield(.failed(error))
        case let .success(read): continuation.yield(.done(read, complete: complete))
        }
    }
}
