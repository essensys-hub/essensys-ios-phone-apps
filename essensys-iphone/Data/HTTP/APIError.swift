//
//  APIError.swift
//  Erreurs normalisées (jumeau de ApiResult.kt Android, design D5 bis) : les backends renvoient
//  tantôt du JSON {"error"|"message"}, tantôt du text/plain.
//

import Foundation

enum APIError: Error, Equatable, Sendable {
    case unauthorized(code: String?, text: String?)
    case forbidden(code: String?, text: String?)
    case passwordChangeRequired
    case rateLimited
    case http(status: Int, code: String?, text: String?)
    case network(host: String, cause: String?)

    /// Échec TLS en LAN : certificat non confirmé ou différent de celui épinglé (design D4).
    var isCertificateProblem: Bool {
        guard case let .network(_, cause) = self, let cause else { return false }
        return cause.range(of: "certif|trust|non confirmé|SecTrust", options: [.regularExpression, .caseInsensitive]) != nil
    }

    var userMessage: String {
        switch self {
        case let .unauthorized(code, _):
            return code == "temporary_password_expired"
                ? "Mot de passe temporaire expiré. Demandez-en un nouveau."
                : "Session expirée, reconnectez-vous."
        case let .forbidden(code, text):
            if code == "account_forbidden" || code == "account_disabled" { return "Ce compte est désactivé." }
            return text?.contains("Portal access not approved") == true ? "Accès portail non approuvé." : "Accès refusé."
        case .passwordChangeRequired:
            return "Vous devez changer votre mot de passe."
        case .rateLimited:
            return "Trop de commandes, patientez."
        case let .http(status, _, text):
            if let text, !text.isEmpty { return text }
            return "Erreur serveur (\(status))."
        case let .network(host, _):
            return isCertificateProblem
                ? "Le certificat de la gateway (\(host)) n'est pas celui confirmé. Connexion bloquée."
                : "Connexion impossible à \(host)"
        }
    }
}

enum ErrorBody {
    /// Retourne (code `error`, message lisible) depuis un corps JSON ou texte brut.
    static func parse(_ data: Data?) -> (code: String?, text: String?) {
        let raw = String(data: data ?? Data(), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if raw.hasPrefix("{"),
           let object = try? JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any] {
            let code = object["error"] as? String
            let message = object["message"] as? String
            return (code, message ?? code)
        }
        return (nil, raw.isEmpty ? nil : raw)
    }

    static func toAPIError(status: Int, body: Data?) -> APIError {
        let (code, text) = parse(body)
        switch status {
        case 401: return .unauthorized(code: code, text: text)
        case 403: return .forbidden(code: code, text: text)
        case 409 where code == "password_change_required": return .passwordChangeRequired
        case 429: return .rateLimited
        default: return .http(status: status, code: code, text: text)
        }
    }
}
