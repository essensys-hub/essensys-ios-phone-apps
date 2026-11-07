//
//  ObjectLayout.swift
//  Activation et ordre d'affichage des lumières et des volets (feature affichage-objets-2026-11-006, spec
//  object-layout-clients). Un document par genre, contrat d'API identique cloud et gateway (design « Contrat
//  d'API ») : {"order":[…],"disabled":[…],"version":n,"updated_at":…}. Rien n'est écrit dans l'armoire.
//

import Foundation

/// Genre d'objet qui porte une disposition : `lights` (33 identifiants) ou `shutters` (16).
enum LayoutKind: String, Sendable, CaseIterable {
    case lights, shutters

    /// Identifiants du catalogue, dans l'ordre d'origine (l'ordre de `IndexTable`, clé de repli).
    var catalogue: [String] {
        switch self {
        case .lights: IndexTable.lights.map(\.id)
        case .shutters: IndexTable.shutters.map(\.id)
        }
    }

    /// Groupe d'affichage d'un identifiant du catalogue (nil s'il n'en fait pas partie).
    func group(of id: String) -> IndexTable.Group? {
        switch self {
        case .lights: IndexTable.lights.first { $0.id == id }?.group
        case .shutters: IndexTable.shutters.first { $0.id == id }?.group
        }
    }

    /// Cloud : /api/portal/{genre}/layout ; réseau local : /api/{genre}/layout.
    func readPath(cloud: Bool) -> String { cloud ? "/api/portal/\(rawValue)/layout" : "/api/\(rawValue)/layout" }
    /// Cloud : /api/portal/admin/{genre}/layout ; réseau local : /api/admin/{genre}/layout.
    func writePath(cloud: Bool) -> String { cloud ? "/api/portal/admin/\(rawValue)/layout" : "/api/admin/\(rawValue)/layout" }

    var unknownCode: String { self == .lights ? "unknown_light" : "unknown_shutter" }
    var unknownMessage: String { self == .lights ? "Lumière inconnue." : "Volet inconnu." }
    var emptyGroupText: String { self == .lights ? "Aucune lumière activée" : "Aucun volet activé" }
}

/// Disposition d'un genre. `order` peut être incomplet ou contenir d'anciens identifiants : ils sont tolérés.
struct ObjectLayout: Decodable, Equatable, Sendable {
    var order: [String]
    var disabled: [String]
    var version: Int
    var updatedAt: String?

    /// Disposition par défaut (version 0) : ordre du catalogue, rien de désactivé.
    static let original = ObjectLayout(order: [], disabled: [])

    enum CodingKeys: String, CodingKey { case order, disabled, version, updatedAt = "updated_at" }

    init(order: [String], disabled: [String], version: Int = 0, updatedAt: String? = nil) {
        self.order = order
        self.disabled = disabled
        self.version = version
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        order = try c.decodeIfPresent([String].self, forKey: .order) ?? []
        disabled = try c.decodeIfPresent([String].self, forKey: .disabled) ?? []
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 0
        updatedAt = try c.decodeIfPresent(String.self, forKey: .updatedAt)
    }

    /// Ordre effectif (règle commune aux quatre clients) : les identifiants de `order` qui sont dans le
    /// catalogue (premier exemplaire seulement), puis ceux du catalogue absents de `order`, dans l'ordre du
    /// catalogue. Les identifiants inconnus sont ignorés.
    func orderedIDs(catalogue: [String]) -> [String] {
        let known = Set(catalogue)
        var seen = Set<String>()
        var result: [String] = []
        for id in order where known.contains(id) && seen.insert(id).inserted { result.append(id) }
        for id in catalogue where seen.insert(id).inserted { result.append(id) }
        return result
    }

    /// Désactivés : `disabled` ∩ catalogue.
    func disabledIDs(catalogue: [String]) -> Set<String> { Set(disabled).intersection(catalogue) }
}

/// Réponse du PUT : le document enregistré (sans `updated_by`) plus `status` (« saved » ou « dry_run »).
struct ObjectLayoutReply: Decodable {
    let layout: ObjectLayout
    let status: String?
    init(from decoder: Decoder) throws {
        layout = try ObjectLayout(from: decoder)
        status = try decoder.container(keyedBy: StatusKey.self).decodeIfPresent(String.self, forKey: .status)
    }
    private enum StatusKey: String, CodingKey { case status }
}

/// Corps du PUT : `{"order":[…],"disabled":[…]}` (les deux clés sont obligatoires) ou `{"reset":true}`.
struct ObjectLayoutRequest: Encodable {
    let order: [String]
    let disabled: [String]
    let reset: Bool

    enum CodingKeys: String, CodingKey { case order, disabled, reset }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        if reset {
            try c.encode(true, forKey: .reset)
        } else {
            try c.encode(order, forKey: .order)
            try c.encode(disabled, forKey: .disabled)
        }
    }
}

/// Brouillon de l'écran de gestion : les modifications restent locales jusqu'à « Enregistrer ».
struct ObjectLayoutDraft: Equatable {
    let kind: LayoutKind
    /// Tous les objets du genre, dans l'ordre effectif.
    private(set) var order: [String]
    private(set) var disabled: Set<String>
    /// « Ordre d'origine » demandé et aucune modification depuis : l'enregistrement envoie `{"reset":true}`.
    private(set) var isReset = false

    init(kind: LayoutKind, layout: ObjectLayout) {
        self.kind = kind
        order = layout.orderedIDs(catalogue: kind.catalogue)
        disabled = layout.disabledIDs(catalogue: kind.catalogue)
    }

    func isDisabled(_ id: String) -> Bool { disabled.contains(id) }

    mutating func toggle(_ id: String) {
        guard order.contains(id) else { return }
        if !disabled.insert(id).inserted { disabled.remove(id) }
        isReset = false
    }

    /// Voisin du même groupe d'affichage, au-dessus ou en dessous dans l'ordre global.
    private func neighbour(of id: String, up: Bool) -> Int? {
        guard let index = order.firstIndex(of: id), let group = kind.group(of: id) else { return nil }
        var i = up ? index - 1 : index + 1
        while order.indices.contains(i) {
            if kind.group(of: order[i]) == group { return i }
            i += up ? -1 : 1
        }
        return nil
    }

    func canMove(_ id: String, up: Bool) -> Bool { neighbour(of: id, up: up) != nil }

    /// Échange l'élément avec son voisin du même groupe : il ne change jamais de groupe.
    mutating func move(_ id: String, up: Bool) {
        guard let index = order.firstIndex(of: id), let other = neighbour(of: id, up: up) else { return }
        order.swapAt(index, other)
        isReset = false
    }

    /// « Ordre d'origine » : ordre du catalogue, tous les objets réactivés.
    mutating func resetToOrigin() {
        order = kind.catalogue
        disabled = []
        isReset = true
    }

}

enum ObjectLayoutFormat {
    static let invalidMessage = "La disposition est refusée par le serveur. Vérifiez la liste puis réessayez."

    /// Messages clairs pour 400, 403 et 503 (texte brut). Les modifications restent à l'écran.
    static func message(for error: APIError, kind: LayoutKind) -> String {
        switch error {
        case let .http(status, code, _) where status == 400:
            return code == kind.unknownCode ? kind.unknownMessage : invalidMessage
        case let .forbidden(code, _) where code == "forbidden" || code == nil:
            return "Réservé à l'administrateur de l'armoire."
        case let .http(status, _, _) where status == 503:
            return "L'affichage ne peut pas être enregistré pour le moment (stockage indisponible)."
        case let .invalidRequest(reason):
            return reason.contains("inconn") ? kind.unknownMessage : invalidMessage
        default:
            return error.userMessage
        }
    }
}

extension ComfortRepository {
    /// Cloud GET /api/portal/{genre}/layout ; local GET /api/{genre}/layout. 404 (ancien serveur) : échec simple.
    func readObjectLayout(_ kind: LayoutKind) async -> Result<ObjectLayout, APIError> {
        switch await api.get(kind.readPath(cloud: store.state.mode == .cloud)) {
        case let .failure(error):
            auth.handle(error)
            return .failure(error)
        case let .success(response):
            guard let decoded = try? JSONDecoder().decode(ObjectLayout.self, from: response.body) else {
                return .failure(.http(status: response.status, code: "decode", text: "Réponse du serveur illisible."))
            }
            return .success(decoded)
        }
    }

    /// Cloud PUT /api/portal/admin/{genre}/layout ; local PUT /api/admin/{genre}/layout. Une seule écriture.
    /// Identifiant inconnu, d'un autre genre ou en double : refusé sans requête.
    func writeObjectLayout(_ kind: LayoutKind, order: [String], disabled: [String], reset: Bool = false) async -> Result<ObjectLayoutReply, APIError> {
        if !reset {
            let known = Set(kind.catalogue)
            guard order.allSatisfy(known.contains), disabled.allSatisfy(known.contains) else {
                return .failure(.invalidRequest("identifiant inconnu"))
            }
            guard Set(order).count == order.count, Set(disabled).count == disabled.count else {
                return .failure(.invalidRequest("doublon dans la disposition"))
            }
        }
        let path = kind.writePath(cloud: store.state.mode == .cloud)
        switch await api.send("PUT", path, body: ObjectLayoutRequest(order: order, disabled: disabled, reset: reset)) {
        case let .failure(error):
            auth.handle(error)
            return .failure(error)
        case let .success(response):
            guard let reply = try? JSONDecoder().decode(ObjectLayoutReply.self, from: response.body) else {
                return .failure(.http(status: response.status, code: "decode", text: "Réponse du serveur illisible."))
            }
            return .success(reply)
        }
    }
}
