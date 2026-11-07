//
//  LightTimers.swift
//  Temporisations d'extinction de six lumières (feature lumieres-temporisees-2026-11-003, spec
//  light-timers-clients). Clés de la table d'échange verrouillées par NR-ios-24 ; contrat d'API identique
//  cloud et gateway (design « Contrat d'API »).
//

import Foundation

extension IndexTable {
    struct LightTimer: Identifiable, Equatable, Sendable {
        let id: String
        let name: String
        /// Case de temporisation du boîtier : un octet, 1 à 255 minutes, 0 = jamais.
        let key: Int
    }

    /// Ordre fixe du contrat : dressing, wc1, wc2, pieceserv, ann1, ann2.
    static let lightTimers: [LightTimer] = [
        LightTimer(id: "dressing", name: "Dressing", key: 521),
        LightTimer(id: "wc1", name: "WC 1", key: 555),
        LightTimer(id: "wc2", name: "WC 2", key: 556),
        LightTimer(id: "pieceserv", name: "Service", key: 557),
        LightTimer(id: "ann1", name: "Annexe 1", key: 561),
        LightTimer(id: "ann2", name: "Annexe 2", key: 562),
    ]

    static func lightTimer(id: String) -> LightTimer? { lightTimers.first { $0.id == id } }

    static let lightTimerRange = 0...255
}

/// Valeur courante d'une temporisation ; `minutes == nil` : jamais lue (jamais 0 par défaut).
struct LightTimerState: Equatable, Identifiable, Sendable {
    let id: String
    let label: String
    let key: Int
    let minutes: Int?

    /// « 15 min », « 1 h », « 1 h 30 », « Jamais », « Inconnue » ; une valeur libre (7) s'affiche telle quelle.
    var display: String { LightTimerFormat.label(minutes: minutes) }
}

enum LightTimerFormat {
    /// Raccourcis proposés, dans l'ordre d'affichage (0 = Jamais).
    static let shortcuts: [(minutes: Int, label: String)] = [(15, "15 min"), (30, "30 min"), (60, "1 h"), (0, "Jamais")]

    static func label(minutes: Int?) -> String {
        guard let minutes else { return "Inconnue" }
        if minutes == 0 { return "Jamais" }
        if let shortcut = shortcuts.first(where: { $0.minutes == minutes }) { return shortcut.label }
        return "\(minutes) min"
    }

    /// Champ libre : entier de 1 à 255. 0 se choisit par « Jamais » ; 300, négatifs et texte sont refusés.
    static func parseFree(_ text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed.allSatisfy({ $0.isASCII && $0.isNumber }), let value = Int(trimmed) else { return nil }
        return (1...255).contains(value) ? value : nil
    }

    static let invalidMessage = "Saisissez une durée de 1 à 255 minutes (« Jamais » pour désactiver)."
}

// MARK: - Contrat d'API

struct LightTimerWire: Decodable {
    let id: String
    let label: String?
    let key: Int?
    let minutes: Int?
}

struct LightTimersResponse: Decodable { let timers: [LightTimerWire] }

struct LightTimerRequest: Codable { let minutes: Int }

struct LightTimerReply: Decodable {
    let id: String?
    let minutes: Int?
    let status: String?
}

extension ComfortRepository {
    /// Les six temporisations. Cloud GET /api/portal/lights/timers ; LAN GET /api/admin/lights/timers.
    func readLightTimers() async -> Result<[LightTimerState], APIError> {
        switch await api.get("\(timersPrefix)/lights/timers") {
        case let .failure(error):
            auth.handle(error)
            return .failure(error)
        case let .success(response):
            guard let decoded = try? JSONDecoder().decode(LightTimersResponse.self, from: response.body) else {
                return .failure(.http(status: response.status, code: "decode", text: "Réponse du serveur illisible."))
            }
            // Catalogue du serveur : on ne garde que les six lumières connues, dans l'ordre fixe du contrat.
            let states = IndexTable.lightTimers.map { known -> LightTimerState in
                let wire = decoded.timers.first { $0.id == known.id }
                let minutes = wire?.minutes.flatMap { IndexTable.lightTimerRange.contains($0) ? $0 : nil }
                return LightTimerState(id: known.id, label: wire?.label ?? known.name, key: wire?.key ?? known.key, minutes: minutes)
            }
            return .success(states)
        }
    }

    /// Cloud PUT /api/portal/admin/lights/timers/{id} ; LAN PUT /api/admin/lights/timers/{id}, corps {"minutes":n}.
    /// Identifiant inconnu ou valeur hors 0...255 : refusé sans requête (le serveur valide aussi).
    func setLightTimer(id: String, minutes: Int) async -> Result<InjectOutcome, APIError> {
        guard IndexTable.lightTimer(id: id) != nil else { return .failure(.invalidRequest("lumière inconnue")) }
        guard IndexTable.lightTimerRange.contains(minutes) else { return .failure(.invalidRequest(LightTimerFormat.invalidMessage)) }
        let path = store.state.mode == .cloud
            ? "/api/portal/admin/lights/timers/\(id)" : "/api/admin/lights/timers/\(id)"
        switch await api.send("PUT", path, body: LightTimerRequest(minutes: minutes)) {
        case let .failure(error):
            auth.handle(error)
            return .failure(error)
        case let .success(response):
            let reply = try? JSONDecoder().decode(LightTimerReply.self, from: response.body)
            return .success(reply?.status == "dry_run" ? .dryRunOK : .sent)
        }
    }

    private var timersPrefix: String { store.state.mode == .cloud ? "/api/portal" : "/api/admin" }
}
