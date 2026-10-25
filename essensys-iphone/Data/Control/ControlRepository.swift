//
//  ControlRepository.swift
//  Envoi des commandes selon le mode (cloud /api/portal/inject, LAN /api/admin/inject) et lecture
//  de la table d'échange (temps de course). Jumeau de ControlRepository.kt.
//

import Foundation

enum InjectOutcome: Equatable, Sendable { case sent, dryRunOK }

final class ControlRepository: Sendable {
    private let api: APIClient
    private let store: SessionStore
    private let auth: AuthRepository

    init(api: APIClient, store: SessionStore, auth: AuthRepository) {
        self.api = api
        self.store = store
        self.auth = auth
    }

    private var prefix: String { store.state.mode == .cloud ? "/api/portal" : "/api/admin" }

    func inject(_ injection: Injection) async -> Result<InjectOutcome, APIError> {
        switch await api.send("POST", "\(prefix)/inject", body: InjectRequest(k: injection.k, v: injection.v)) {
        case let .failure(error):
            auth.handle(error)
            return .failure(error)
        case let .success(response):
            return .success(Self.outcome(response.body))
        }
    }

    /// Commandes de groupe : séquentielles, une injection par sortie, arrêt à la première erreur (comme le portail).
    func injectAll(_ injections: [Injection]) async -> Result<InjectOutcome, APIError> {
        var outcome = InjectOutcome.sent
        for injection in injections {
            switch await inject(injection) {
            case let .failure(error): return .failure(error)
            case let .success(value): if value == .dryRunOK { outcome = .dryRunOK }
            }
        }
        return .success(outcome)
    }

    /// Un lot d'au plus 30 couples (limite firmware) en une requête : cloud POST /api/portal/inject/batch
    /// {params:[{k,v}]}, LAN POST /api/admin/inject avec un tableau. Le découpage est fait par l'appelant.
    func injectBatch(_ chunk: [Injection]) async -> Result<InjectOutcome, APIError> {
        guard (1...IndexTable.maxParamsPerAction).contains(chunk.count) else { return .failure(.invalidRequest("lot de \(chunk.count) couples")) }
        let params = chunk.map { KeyValue(k: $0.k, v: $0.v) }
        let result = store.state.mode == .cloud
            ? await api.send("POST", "/api/portal/inject/batch", body: InjectBatchRequest(params: params))
            : await api.send("POST", "/api/admin/inject", body: params)
        switch result {
        case let .failure(error):
            auth.handle(error)
            return .failure(error)
        case let .success(response):
            return .success(Self.outcome(response.body))
        }
    }

    func readExchange(keys: [Int]) async -> Result<[Int: String], APIError> {
        await readExchangeSnapshot(keys: keys).map(\.values)
    }

    /// Lecture avec l'état du cache cloud (stale, source) ; en LAN, la gateway répond toujours à jour.
    func readExchangeSnapshot(keys: [Int]) async -> Result<ExchangeSnapshot, APIError> {
        let path = "\(prefix)/exchange?keys=" + keys.map(String.init).joined(separator: ",")
        switch await api.get(path) {
        case let .failure(error):
            auth.handle(error)
            return .failure(error)
        case let .success(response):
            let decoded = try? JSONDecoder().decode(ExchangeResponse.self, from: response.body)
            let values = decoded?.values ?? []
            return .success(ExchangeSnapshot(
                values: Dictionary(values.map { ($0.k, $0.v) }, uniquingKeysWith: { first, _ in first }),
                stale: decoded?.stale == true || decoded?.source == "none"))
        }
    }

    static func outcome(_ body: Data) -> InjectOutcome {
        let decoded = try? JSONDecoder().decode(InjectResponse.self, from: body)
        return decoded?.status == "test_ok" || decoded?.dryRun == true ? .dryRunOK : .sent
    }
}

/// Valeurs lues dans la table d'échange ; stale = cache cloud ancien ou vide (spec heating-control).
struct ExchangeSnapshot: Equatable, Sendable {
    let values: [Int: String]
    let stale: Bool
}
