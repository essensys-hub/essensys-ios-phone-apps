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

struct KeyValue: Decodable { let k: Int; let v: String }
struct ExchangeResponse: Decodable { let values: [KeyValue] }

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

struct GatewayInfo: Decodable { let online: Bool? }
struct PortalSession: Decodable { let gateway: GatewayInfo? }

struct LastAction: Decodable, Equatable, Sendable {
    let actionInfo: String?
    let isDone: Bool?
}
struct HistoryLatest: Decodable { let lastAction: LastAction? }

struct LanUserResponse: Decodable { struct User: Decodable { let id: Int? }; let user: User? }

/// Corps vide pour les requêtes sans contenu.
struct EmptyBody: Encodable {}
