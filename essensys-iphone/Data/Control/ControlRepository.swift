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
            let decoded = try? JSONDecoder().decode(InjectResponse.self, from: response.body)
            let dryRun = decoded?.status == "test_ok" || decoded?.dryRun == true
            return .success(dryRun ? .dryRunOK : .sent)
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

    func readExchange(keys: [Int]) async -> Result<[Int: String], APIError> {
        let path = "\(prefix)/exchange?keys=" + keys.map(String.init).joined(separator: ",")
        switch await api.get(path) {
        case let .failure(error):
            auth.handle(error)
            return .failure(error)
        case let .success(response):
            let values = (try? JSONDecoder().decode(ExchangeResponse.self, from: response.body))?.values ?? []
            return .success(Dictionary(values.map { ($0.k, $0.v) }, uniquingKeysWith: { first, _ in first }))
        }
    }
}
