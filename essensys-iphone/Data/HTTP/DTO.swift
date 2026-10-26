//
//  DTO.swift
//  Contrats lus dans essensys-user-portal-backend et essensys-server-backend (design D5 bis Android).
//

import Foundation

struct LoginRequest: Encodable { let email: String; let password: String }

struct CloudLoginResponse: Decodable {
    let token: String
    let passwordChangeRequired: Bool?
    enum CodingKeys: String, CodingKey { case token, passwordChangeRequired = "password_change_required" }
}

struct PasswordChangeRequest: Encodable {
    let currentPassword: String
    let newPassword: String
    enum CodingKeys: String, CodingKey { case currentPassword = "current_password", newPassword = "new_password" }
}

struct InjectRequest: Encodable { let k: Int; let v: String }

struct InjectResponse: Decodable {
    let status: String?
    let dryRun: Bool?
    enum CodingKeys: String, CodingKey { case status, dryRun = "dry_run" }
}

struct KeyValue: Codable, Equatable, Sendable { let k: Int; let v: String }

struct ExchangeResponse: Decodable {
    let values: [KeyValue]
    let stale: Bool?
    let source: String?
}

struct InjectBatchRequest: Encodable { let params: [KeyValue] }

// Synchronisation du planning de chauffage, LAN seulement (essensys-server-backend handlers.go).
struct HeatingSyncRequest: Encodable { let startIndex: Int; let byteCount: Int }

struct HeatingSyncStatus: Decodable, Equatable, Sendable {
    var active: Bool? = nil
    var received: Int? = nil
    var total: Int? = nil
}

struct HeatingSyncStarted: Decodable { let status: String?; let sync: HeatingSyncStatus? }

// Scénarios : cloud /api/portal/scenarios*, LAN /api/scenarios* (même format, handlers/scenarios.go).
struct ScenarioSlot: Decodable, Equatable, Identifiable, Sendable {
    let slot: Int
    let label: String
    let editable: Bool
    var lastLaunched: Int?
    let params: [KeyValue]?
    var id: Int { slot }
    enum CodingKeys: String, CodingKey { case slot = "slot_number", label, editable, lastLaunched = "last_launched", params }
}

struct ScenarioList: Decodable { let slots: [ScenarioSlot] }

struct BitmaskBit: Decodable, Equatable, Sendable { let bit: Int; let value: Int; let label: String }
struct BitmaskField: Decodable, Equatable, Sendable { let index: Int; let name: String; let bits: [BitmaskBit] }
struct BitmaskMeta: Decodable { let fields: [BitmaskField] }

struct ScenarioSaveRequest: Encodable { let params: [String: String] }

/// Alarme (cloud POST /api/portal/web/actions) : le code n'est jamais stocké ni journalisé par l'app.
struct AlarmRequest: Encodable, CustomStringConvertible, CustomDebugStringConvertible {
    let alarme: String
    let codealarme: String
    var description: String { "AlarmRequest(alarme: \(alarme), codealarme: ••••)" }
    var debugDescription: String { description }
}

struct LinkRequestInfo: Decodable {
    let machineSerial: String?
    let status: String?
    enum CodingKeys: String, CodingKey { case machineSerial = "machine_serial", status }
}

struct LinkStatusResponse: Decodable {
    let status: String?
    let linkRequest: LinkRequestInfo?
    let portalAccess: Bool?
    enum CodingKeys: String, CodingKey { case status, linkRequest = "link_request", portalAccess = "portal_access" }
}

struct LinkRequestBody: Encodable {
    let machineSerial: String
    let message: String
    enum CodingKeys: String, CodingKey { case machineSerial = "machine_serial", message }
}

struct GatewayInfo: Decodable, Equatable, Sendable { let online: Bool? }

struct CloudUser: Decodable, Equatable, Sendable {
    let email: String?
    let firstName: String?
    let lastName: String?
    enum CodingKeys: String, CodingKey { case email, firstName = "first_name", lastName = "last_name" }
}

struct ArmoireInfo: Decodable, Equatable, Sendable {
    let serial: String?
    let lastSeen: String?
    /// Dernier contact de l'armoire de 2 min au plus ; absent d'un ancien backend, donc faux.
    let online: Bool?
    enum CodingKeys: String, CodingKey { case serial = "no_serie", lastSeen = "last_seen", online }
}

struct PortalSession: Decodable, Equatable, Sendable {
    let user: CloudUser?
    let gateway: GatewayInfo?
    let armoire: ArmoireInfo?

    /// Armoire en ligne : la gateway OU l'armoire elle-même a été vue depuis 2 min au plus.
    /// Une installation sans gateway n'a pas de bloc `gateway` : seul `armoire.online` compte
    /// (armoire-online-sans-gateway-2026-10-012, essensys-feature-lifecycle#37).
    var armoireOnline: Bool { gateway?.online == true || armoire?.online == true }
}

struct LastAction: Decodable, Equatable, Sendable {
    let actionInfo: String?
    let isDone: Bool?
}
struct HistoryLatest: Decodable { let lastAction: LastAction? }

struct LanUserResponse: Decodable { struct User: Decodable { let id: Int? }; let user: User? }

/// Corps vide pour les requêtes sans contenu.
struct EmptyBody: Encodable {}
