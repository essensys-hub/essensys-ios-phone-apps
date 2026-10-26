//
//  ComfortRepository.swift
//  Chauffe-eau, arrosage (spec comfort-controls), prises de sécurité (spec security-outlets) et alarme
//  (spec alarm-control), jumeau de ComfortRepository.kt.
//

import Foundation

/// Modes actuels lus dans la table d'échange ; nil = valeur non transmise par l'armoire.
struct ComfortModes: Equatable, Sendable {
    let waterHeater: IndexTable.WaterHeaterMode?
    let sprinklerMinutes: Int?

    /// Arrosage : 0 = arrêt, 255 = automatique, 1–254 = forcé N minutes (Arrose_Mode).
    var sprinklerLabel: String? {
        switch sprinklerMinutes {
        case nil: nil
        case 0: "Arrêt"
        case 255: "Automatique"
        case let v? where (1...254).contains(v): "Forcé \(v) minutes"
        default: nil
        }
    }
}

final class ComfortRepository: Sendable {
    private let api: APIClient
    private let store: SessionStore
    private let auth: AuthRepository
    private let control: ControlRepository

    init(api: APIClient, store: SessionStore, auth: AuthRepository, control: ControlRepository) {
        self.api = api
        self.store = store
        self.auth = auth
        self.control = control
    }

    func readModes() async -> Result<ComfortModes, APIError> {
        await control.readExchange(keys: [IndexTable.waterHeaterIndex, IndexTable.sprinklerIndex]).map { values in
            let heater = values[IndexTable.waterHeaterIndex].flatMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            let sprinkler = values[IndexTable.sprinklerIndex].flatMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            return ComfortModes(
                waterHeater: heater.flatMap(IndexTable.WaterHeaterMode.init(rawValue:)),
                sprinklerMinutes: sprinkler.flatMap { (0...255).contains($0) ? $0 : nil })
        }
    }

    func setWaterHeater(_ mode: IndexTable.WaterHeaterMode) async -> Result<InjectOutcome, APIError> {
        await control.inject(mode.command)
    }

    func setSprinkler(_ mode: IndexTable.SprinklerMode) async -> Result<InjectOutcome, APIError> {
        await control.inject(mode.command)
    }

    /// Prises de sécurité (spec security-outlets) : état lu à l'indice 440, inconnu s'il est absent.
    func readSecurityOutlets() async -> Result<IndexTable.SecurityOutletsState, APIError> {
        await control.readExchange(keys: [IndexTable.securityOutletsStateIndex]).map {
            IndexTable.SecurityOutletsState(raw: $0[IndexTable.securityOutletsStateIndex])
        }
    }

    /// Coupure ou rétablissement : un lot [590 = 1, 623 = 1|2], en cloud comme en LAN.
    func securityOutlets(_ action: IndexTable.SecurityOutletsAction) async -> Result<InjectOutcome, APIError> {
        await control.injectBatch(action.commands)
    }

    /// Mise en service ou arrêt de l'alarme, en cloud seulement. Le code n'est ni conservé ni renvoyé :
    /// un message d'erreur serveur qui le contiendrait est masqué, et la réponse dry-run (qui le répète
    /// dans validated_params) n'est réduite qu'à son statut.
    func alarm(on: Bool, code: String) async -> Result<InjectOutcome, APIError> {
        guard code.count == 4, code.allSatisfy(\.isASCII), code.allSatisfy(\.isNumber) else {
            return .failure(.invalidRequest("code d'alarme : 4 chiffres"))
        }
        guard store.state.mode == .cloud else { return .failure(.cloudOnly) }
        switch await api.send("POST", "/api/portal/web/actions", body: AlarmRequest(alarme: on ? "on" : "off", codealarme: code)) {
        case let .failure(error):
            auth.handle(error)
            return .failure(Self.redact(error, code: code))
        case let .success(response):
            return .success(ControlRepository.outcome(response.body))
        }
    }

    private static func redact(_ error: APIError, code: String) -> APIError {
        func mask(_ text: String?) -> String? { text?.replacingOccurrences(of: code, with: "••••") }
        switch error {
        case let .http(status, c, text): return .http(status: status, code: mask(c), text: mask(text))
        case let .forbidden(c, text): return .forbidden(code: c, text: mask(text))
        case let .unauthorized(c, text): return .unauthorized(code: c, text: mask(text))
        case let .network(host, cause): return .network(host: host, cause: mask(cause))
        default: return error
        }
    }
}
