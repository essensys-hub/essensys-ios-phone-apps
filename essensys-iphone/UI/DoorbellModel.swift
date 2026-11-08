//
//  DoorbellModel.swift
//  Option « Sonnette » des Réglages (sonnette-plages-push-2026-11-008, essensys-feature-lifecycle#61) :
//  visible seulement si une gateway est liée, interrupteur « Me prévenir quand quelqu'un sonne »,
//  autorisation du système, enregistrement de l'appareil dans le cloud.
//

import Foundation
import Observation

/// Présence de la gateway vue du cloud (`gateway_state` de `GET /api/portal/session`).
enum GatewayPresence: Equatable, Sendable {
    case none, offline, online

    init?(_ raw: String?) {
        switch raw {
        case "none": self = .none
        case "offline": self = .offline
        case "online": self = .online
        default: return nil // champ absent ou inconnu : affichage actuel conservé
        }
    }

    var label: String {
        switch self {
        case .none: "Aucune gateway liée"
        case .online: "Gateway en ligne"
        case .offline: "Gateway hors ligne"
        }
    }
}

@MainActor @Observable
final class DoorbellModel {
    static let deniedMessage = "Les notifications sont refusées pour l'app. Autorisez-les dans Réglages > Notifications > Essensys pour être prévenu."
    static let failureMessage = "L'option n'a pas pu être enregistrée. Réessayez."

    private(set) var notifyEnabled = false
    private(set) var busy = false
    private(set) var message: String?

    private let push: PushRepository
    private let system: PushSystem
    private let appVersion: String

    init(push: PushRepository, system: PushSystem,
         appVersion: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?") {
        self.push = push
        self.system = system
        self.appVersion = appVersion
    }

    /// Relit l'état à l'ouverture : l'interrupteur est actif si le cloud a cet appareil avec `doorbell_notify`
    /// ET si le système autorise encore les notifications (autorisation retirée depuis : retombe à zéro).
    func load() async {
        message = nil
        guard case let .success(prefs) = await push.preferences(), prefs.available else { notifyEnabled = false; return }
        let device = push.devices.deviceId.flatMap { id in prefs.devices.first { $0.id == id } }
        let serverOn = device?.doorbellNotify == true
        let granted = await system.authorization() == .granted
        notifyEnabled = serverOn && granted
        if serverOn && granted, let token = await system.deviceToken() {
            // Le jeton APNs peut changer : on le renvoie à chaque ouverture (rafraîchit aussi `last_seen`).
            _ = await push.register(token: token, appVersion: appVersion, notify: true)
        }
    }

    func setNotify(_ on: Bool) async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        message = nil
        if on { await enable() } else { await disable() }
    }

    private func enable() async {
        var status = await system.authorization()
        if status == .notDetermined { status = await system.requestAuthorization() ? .granted : .denied }
        guard status == .granted else {
            notifyEnabled = false
            message = Self.deniedMessage
            return
        }
        guard let token = await system.deviceToken() else { notifyEnabled = false; message = Self.failureMessage; return }
        switch await push.register(token: token, appVersion: appVersion, notify: true) {
        case let .success(device): notifyEnabled = device.doorbellNotify ?? true
        case .failure: notifyEnabled = false; message = Self.failureMessage
        }
    }

    private func disable() async {
        // `doorbell_notify=false` : l'appareil reste enregistré, sans notification. Les lumières ne sont pas concernées.
        guard let token = await system.deviceToken() else { message = Self.failureMessage; return }
        switch await push.register(token: token, appVersion: appVersion, notify: false) {
        case .success: notifyEnabled = false
        case .failure: message = Self.failureMessage
        }
    }
}
