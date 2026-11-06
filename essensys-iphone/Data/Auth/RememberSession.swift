//
//  RememberSession.swift
//  Session « Se souvenir de moi » (session-30-jours-2026-11-001, jumeau de RememberSession.kt) : lecture de la
//  date de fin envoyée par le serveur, affichage, et renouvellement du jeton d'accès sans mot de passe.
//

import Foundation

enum RememberDate {
    /// Le serveur envoie du RFC 3339, avec ou sans fraction de seconde (Go : jusqu'à 9 chiffres).
    static func parse(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        let plain = ISO8601DateFormatter()
        if let date = plain.date(from: raw) { return date }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: raw) { return date }
        let trimmed = raw.replacingOccurrences(of: #"\.\d+"#, with: "", options: .regularExpression)
        return plain.date(from: trimmed)
    }
}

/// « Connecté jusqu'au 10/12/2026 » : date locale de la fin de session mémorisée.
func formatRememberUntil(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "dd/MM/yyyy"
    return formatter.string(from: date)
}

/// Un seul renouvellement à la fois : les requêtes qui reçoivent un 401 en même temps attendent la même tâche
/// (spec « Renouvellement transparent »), puis chacune est rejouée une fois.
actor RememberRefresher {
    enum Outcome: Sendable, Equatable {
        /// Nouveau jeton d'accès en place : rejouer la requête.
        case renewed
        /// Le serveur a refusé (expirée, révoquée, compte désactivé) : la session est effacée.
        case rejected
        /// Réseau ou serveur indisponible : la session est conservée, rien n'est rejoué.
        case unavailable
    }

    private var inflight: Task<Outcome, Never>?

    /// - Parameter staleToken: jeton d'accès avec lequel la requête a échoué.
    /// - Parameter current: jeton d'accès actuel du magasin ; différent de `staleToken`, un autre renouvellement vient d'aboutir.
    func renew(staleToken: String?, current: @Sendable () -> String?,
               perform: @escaping @Sendable () async -> Outcome) async -> Outcome {
        guard let now = current() else { return .rejected }
        if now != staleToken { return .renewed }
        if let inflight { return await inflight.value }
        let task = Task { await perform() }
        inflight = task
        let outcome = await task.value
        inflight = nil
        return outcome
    }
}
