//
//  LightNames.swift
//  Noms personnalisés des lumières (feature noms-lumieres-2026-11-004, spec light-names-clients).
//  Contrat d'API identique cloud et gateway (design « Contrat d'API »). Le nom est toujours rendu en texte
//  brut ; renommer n'envoie aucun ordre à l'armoire.
//

import Foundation

/// Un élément de `GET …/lights/names`. `name == nil` : aucun nom défini, on affiche `defaultName`.
struct LightName: Decodable, Equatable, Identifiable, Sendable {
    let id: String
    let defaultName: String
    let name: String?
    let version: Int
    let updatedAt: String?

    enum CodingKeys: String, CodingKey { case id, defaultName = "default", name, version, updatedAt = "updated_at" }

    init(id: String, defaultName: String, name: String? = nil, version: Int = 0, updatedAt: String? = nil) {
        self.id = id
        self.defaultName = defaultName
        self.name = name
        self.version = version
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        defaultName = try c.decodeIfPresent(String.self, forKey: .defaultName) ?? ""
        name = try c.decodeIfPresent(String.self, forKey: .name)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 0
        updatedAt = try c.decodeIfPresent(String.self, forKey: .updatedAt)
    }

    /// Nom à afficher : `name` s'il est non vide, sinon le nom d'origine.
    var displayName: String {
        if let name, !name.trimmingCharacters(in: .whitespaces).isEmpty { return name }
        return defaultName
    }
}

struct LightNamesResponse: Decodable { let lights: [LightName] }

/// Corps du PUT : `{"name":"WC 3"}` ou `{"name":null}` (remise à zéro). `null` est encodé explicitement.
struct LightNameRequest: Encodable {
    let name: String?
    enum CodingKeys: String, CodingKey { case name }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        if let name { try c.encode(name, forKey: .name) } else { try c.encodeNil(forKey: .name) }
    }
}

/// Réponse du PUT : l'élément mis à jour plus `status` (« saved » ou « dry_run »).
struct LightNameReply: Decodable {
    let light: LightName
    let status: String?
    init(from decoder: Decoder) throws {
        light = try LightName(from: decoder)
        status = try decoder.container(keyedBy: StatusKey.self).decodeIfPresent(String.self, forKey: .status)
    }
    private enum StatusKey: String, CodingKey { case status }
}

enum LightNameFormat {
    static let maxLength = 40
    static let invalidMessage = "Le nom doit comporter de 1 à 40 caractères, sans < ni >."

    /// Après suppression des espaces de début et de fin : 1 à 40 caractères Unicode, sans caractère de contrôle
    /// (U+0000–U+001F, U+007F), sans « < » ni « > ». Retourne le nom nettoyé, ou nil s'il est refusé.
    static func validate(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let scalars = trimmed.unicodeScalars
        guard (1...maxLength).contains(scalars.count) else { return nil }
        for scalar in scalars {
            if scalar.value <= 0x1F || scalar.value == 0x7F || scalar == "<" || scalar == ">" { return nil }
        }
        return trimmed
    }

    /// Messages clairs pour 400, 403 et 503 (texte brut).
    static func message(for error: APIError) -> String {
        switch error {
        case let .http(status, code, _) where status == 400:
            return code == "unknown_light" ? "Lumière inconnue." : invalidMessage
        case let .forbidden(code, _) where code == "forbidden" || code == nil:
            return "Réservé à l'administrateur de l'armoire."
        case let .http(status, _, _) where status == 503:
            return "Les noms ne peuvent pas être enregistrés pour le moment (stockage indisponible)."
        case let .invalidRequest(reason):
            return reason.hasPrefix("Le nom") ? reason : "Lumière inconnue."
        default:
            return error.userMessage
        }
    }
}

extension IndexTable {
    /// Lumière commandée par un bit de scénario (index d'allumage ou d'extinction + masque), nil pour un volet.
    static func light(metaIndex: Int, bitValue: Int) -> Light? {
        lights.first { $0.mask == bitValue && ($0.onIndex == metaIndex || $0.offIndex == metaIndex) }
    }
}

extension ComfortRepository {
    /// Cloud GET /api/portal/lights/names ; local GET /api/lights/names.
    func readLightNames() async -> Result<[LightName], APIError> {
        let path = store.state.mode == .cloud ? "/api/portal/lights/names" : "/api/lights/names"
        switch await api.get(path) {
        case let .failure(error):
            auth.handle(error)
            return .failure(error)
        case let .success(response):
            guard let decoded = try? JSONDecoder().decode(LightNamesResponse.self, from: response.body) else {
                return .failure(.http(status: response.status, code: "decode", text: "Réponse du serveur illisible."))
            }
            return .success(decoded.lights)
        }
    }

    /// Cloud PUT /api/portal/admin/lights/names/{id} ; local PUT /api/admin/lights/names/{id}, corps {"name":…}.
    /// `name == nil` : retour au nom d'origine. Nom invalide ou lumière inconnue : refusé sans requête.
    func setLightName(id: String, name: String?) async -> Result<LightNameReply, APIError> {
        guard IndexTable.lights.contains(where: { $0.id == id }) else { return .failure(.invalidRequest("lumière inconnue")) }
        var sent: String?
        if let name {
            guard let valid = LightNameFormat.validate(name) else { return .failure(.invalidRequest(LightNameFormat.invalidMessage)) }
            sent = valid
        }
        let path = store.state.mode == .cloud ? "/api/portal/admin/lights/names/\(id)" : "/api/admin/lights/names/\(id)"
        switch await api.send("PUT", path, body: LightNameRequest(name: sent)) {
        case let .failure(error):
            auth.handle(error)
            return .failure(error)
        case let .success(response):
            guard let reply = try? JSONDecoder().decode(LightNameReply.self, from: response.body) else {
                return .failure(.http(status: response.status, code: "decode", text: "Réponse du serveur illisible."))
            }
            return .success(reply)
        }
    }
}
