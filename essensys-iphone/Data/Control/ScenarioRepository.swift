//
//  ScenarioRepository.swift
//  Scénarios 2 à 8 (spec scenarios), jumeau de ScenarioRepository.kt : cloud /api/portal/scenarios*
//  (JWT), LAN /api/scenarios* (session). L'en-tête dry-run est ajouté par APIClient, dans les deux modes.
//

import Foundation

/// Définition d'un scénario : valeur de chacun des 41 indices de son bloc.
struct ScenarioDefinition: Equatable, Sendable {
    let slot: Int
    var values: [Int: Int]

    /// Le backend réécrit les 41 octets (manquant = 0) : on n'édite qu'une définition complète.
    var complete: Bool { IndexTable.scenarioBlock(slot).allSatisfy { values[$0] != nil } }

    func isSet(metaIndex: Int, bitValue: Int) -> Bool {
        guard let index = IndexTable.shiftIntoScenario(metaIndex, slot: slot) else { return false }
        return (values[index] ?? 0) & bitValue != 0
    }

    /// Choix « Prises de sécurité » du scénario (décalage 31 du bloc, spec security-outlets).
    var security: IndexTable.ScenarioSecurity {
        IndexTable.ScenarioSecurity(rawValue: values[IndexTable.scenarioSecurityIndex(slot)] ?? 0) ?? .nothing
    }

    func withSecurity(_ choice: IndexTable.ScenarioSecurity) -> ScenarioDefinition {
        var copy = self
        copy.values[IndexTable.scenarioSecurityIndex(slot)] = choice.rawValue
        return copy
    }

    func toggled(metaIndex: Int, bitValue: Int, on: Bool) -> ScenarioDefinition {
        guard let index = IndexTable.shiftIntoScenario(metaIndex, slot: slot) else { return self }
        var copy = self
        let current = values[index] ?? 0
        copy.values[index] = on ? current | bitValue : current & ~bitValue & 0xFF
        return copy
    }
}

final class ScenarioRepository: Sendable {
    private let api: APIClient
    private let store: SessionStore
    private let auth: AuthRepository

    init(api: APIClient, store: SessionStore, auth: AuthRepository) {
        self.api = api
        self.store = store
        self.auth = auth
    }

    private var prefix: String { store.state.mode == .cloud ? "/api/portal/scenarios" : "/api/scenarios" }

    func list() async -> Result<[ScenarioSlot], APIError> {
        await get(prefix, as: ScenarioList.self) { list in
            list.slots.filter { IndexTable.scenarioSlots.contains($0.slot) }.sorted { $0.slot < $1.slot }
        }
    }

    func definition(_ slot: Int) async -> Result<ScenarioDefinition, APIError> {
        await get("\(prefix)/\(slot)", as: ScenarioSlot.self) { detail in
            let block = IndexTable.scenarioBlock(slot)
            var values: [Int: Int] = [:]
            for param in detail.params ?? [] where block.contains(param.k) {
                if let value = Int(param.v.trimmingCharacters(in: .whitespaces)) { values[param.k] = value }
            }
            return ScenarioDefinition(slot: slot, values: values)
        }
    }

    func bitmasks() async -> Result<[BitmaskField], APIError> {
        await get("\(prefix)/meta/bitmasks", as: BitmaskMeta.self) { $0.fields }
    }

    func launch(_ slot: Int) async -> Result<InjectOutcome, APIError> {
        guard IndexTable.scenarioSlots.contains(slot) else { return .failure(.invalidRequest("scénario \(slot) non lançable")) }
        return await mutate("POST", "\(prefix)/\(slot)/launch", body: EmptyBody?.none)
    }

    func restore(_ slot: Int) async -> Result<InjectOutcome, APIError> {
        guard IndexTable.restorableScenarioSlots.contains(slot) else { return .failure(.invalidRequest("scénario \(slot) sans réglages d'usine")) }
        return await mutate("POST", "\(prefix)/\(slot)/restore", body: EmptyBody?.none)
    }

    /// Enregistre la définition complète ; tout indice hors du bloc est refusé avant l'appel.
    func save(_ definition: ScenarioDefinition) async -> Result<InjectOutcome, APIError> {
        let block = IndexTable.scenarioBlock(definition.slot)
        guard definition.complete else { return .failure(.invalidRequest("définition incomplète du scénario \(definition.slot)")) }
        guard definition.values.keys.allSatisfy(block.contains) else { return .failure(.invalidRequest("indice hors du bloc du scénario \(definition.slot)")) }
        guard definition.values.values.allSatisfy((0...255).contains) else { return .failure(.invalidRequest("valeur hors octet")) }
        let params = Dictionary(uniqueKeysWithValues: definition.values.map { (String($0.key), String($0.value)) })
        return await mutate("PUT", "\(prefix)/\(definition.slot)", body: ScenarioSaveRequest(params: params))
    }

    private func mutate<Body: Encodable>(_ method: String, _ path: String, body: Body?) async -> Result<InjectOutcome, APIError> {
        switch await api.send(method, path, body: body) {
        case let .failure(error):
            auth.handle(error)
            return .failure(error)
        case let .success(response):
            return .success(ControlRepository.outcome(response.body))
        }
    }

    private func get<T: Decodable, R>(_ path: String, as type: T.Type, map: (T) -> R) async -> Result<R, APIError> {
        switch await api.get(path) {
        case let .failure(error):
            auth.handle(error)
            return .failure(error)
        case let .success(response):
            guard let decoded = try? JSONDecoder().decode(T.self, from: response.body) else {
                return .failure(.http(status: response.status, code: "decode", text: "Réponse du serveur illisible."))
            }
            return .success(map(decoded))
        }
    }
}
