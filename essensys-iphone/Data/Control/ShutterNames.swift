//
//  ShutterNames.swift
//  Noms personnalisés des volets et stores (feature noms-volets-2026-11-005, spec shutter-names-clients).
//  Jumeau de LightNames.swift : contrat d'API identique cloud et gateway (design « Contrat d'API »).
//  Le nom est toujours rendu en texte brut ; renommer n'envoie aucun ordre à l'armoire.
//

import Foundation

/// Un élément de `GET …/shutters/names`. `name == nil` : aucun nom défini, on affiche `defaultName`.
struct ShutterName: Decodable, Equatable, Identifiable, Sendable {
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

struct ShutterNamesResponse: Decodable { let shutters: [ShutterName] }

/// Corps du PUT : `{"name":"Volet baie vitrée"}` ou `{"name":null}` (remise à zéro). `null` est encodé explicitement.
struct ShutterNameRequest: Encodable {
    let name: String?
    enum CodingKeys: String, CodingKey { case name }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        if let name { try c.encode(name, forKey: .name) } else { try c.encodeNil(forKey: .name) }
    }
}

/// Réponse du PUT : l'élément mis à jour plus `status` (« saved » ou « dry_run »).
struct ShutterNameReply: Decodable {
    let shutter: ShutterName
    let status: String?
    init(from decoder: Decoder) throws {
        shutter = try ShutterName(from: decoder)
        status = try decoder.container(keyedBy: StatusKey.self).decodeIfPresent(String.self, forKey: .status)
    }
    private enum StatusKey: String, CodingKey { case status }
}

enum ShutterNameFormat {
    static let maxLength = 40
    static let invalidMessage = "Le nom doit comporter de 1 à 40 caractères, sans < ni >."

    /// Même règle que les lumières : après suppression des espaces de début et de fin, 1 à 40 caractères Unicode,
    /// sans caractère de contrôle ni « < » ni « > ». Retourne le nom nettoyé, ou nil s'il est refusé.
    static func validate(_ text: String) -> String? { LightNameFormat.validate(text) }

    /// Messages clairs pour 400, 403 et 503 (texte brut).
    static func message(for error: APIError) -> String {
        switch error {
        case let .http(status, code, _) where status == 400:
            return code == "unknown_shutter" ? "Volet inconnu." : invalidMessage
        case let .forbidden(code, _) where code == "forbidden" || code == nil:
            return "Réservé à l'administrateur de l'armoire."
        case let .http(status, _, _) where status == 503:
            return "Les noms ne peuvent pas être enregistrés pour le moment (stockage indisponible)."
        case let .invalidRequest(reason):
            return reason.hasPrefix("Le nom") ? reason : "Volet inconnu."
        default:
            return error.userMessage
        }
    }
}

extension ComfortRepository {
    /// Cloud GET /api/portal/shutters/names ; local GET /api/shutters/names.
    func readShutterNames() async -> Result<[ShutterName], APIError> {
        let path = store.state.mode == .cloud ? "/api/portal/shutters/names" : "/api/shutters/names"
        switch await api.get(path) {
        case let .failure(error):
            auth.handle(error)
            return .failure(error)
        case let .success(response):
            guard let decoded = try? JSONDecoder().decode(ShutterNamesResponse.self, from: response.body) else {
                return .failure(.http(status: response.status, code: "decode", text: "Réponse du serveur illisible."))
            }
            return .success(decoded.shutters)
        }
    }

    /// Cloud PUT /api/portal/admin/shutters/names/{id} ; local PUT /api/admin/shutters/names/{id}, corps {"name":…}.
    /// `name == nil` : retour au nom d'origine. Nom invalide ou volet inconnu : refusé sans requête.
    func setShutterName(id: String, name: String?) async -> Result<ShutterNameReply, APIError> {
        guard IndexTable.shutters.contains(where: { $0.id == id }) else { return .failure(.invalidRequest("volet inconnu")) }
        var sent: String?
        if let name {
            guard let valid = ShutterNameFormat.validate(name) else { return .failure(.invalidRequest(ShutterNameFormat.invalidMessage)) }
            sent = valid
        }
        let path = store.state.mode == .cloud ? "/api/portal/admin/shutters/names/\(id)" : "/api/admin/shutters/names/\(id)"
        switch await api.send("PUT", path, body: ShutterNameRequest(name: sent)) {
        case let .failure(error):
            auth.handle(error)
            return .failure(error)
        case let .success(response):
            guard let reply = try? JSONDecoder().decode(ShutterNameReply.self, from: response.body) else {
                return .failure(.http(status: response.status, code: "decode", text: "Réponse du serveur illisible."))
            }
            return .success(reply)
        }
    }
}
