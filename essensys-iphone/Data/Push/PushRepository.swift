//
//  PushRepository.swift
//  Appareil mobile enregistré auprès du cloud pour la notification de la sonnette
//  (sonnette-plages-push-2026-11-008, essensys-feature-lifecycle#61). Le jeton APNs part au cloud, jamais
//  dans le journal du support ni dans un message d'erreur.
//

import Foundation

struct PushDevice: Decodable, Equatable, Sendable {
    let id: Int
    let platform: String?
    let doorbellNotify: Bool?
    enum CodingKeys: String, CodingKey { case id, platform, doorbellNotify = "doorbell_notify" }
}

struct DoorbellPreferences: Decodable, Equatable, Sendable {
    let available: Bool
    let devices: [PushDevice]
}

struct PushDeviceBody: Encodable {
    let platform = "ios"
    let token: String
    let appVersion: String
    let doorbellNotify: Bool
    enum CodingKeys: String, CodingKey { case platform, token, appVersion = "app_version", doorbellNotify = "doorbell_notify" }
}

/// Identifiant de l'appareil côté cloud (le cloud ne renvoie jamais le jeton : on ne retrouve l'appareil que par cet id).
protocol PushDeviceStore: Sendable {
    var deviceId: Int? { get }
    func set(_ id: Int?)
}

final class UserDefaultsPushDeviceStore: PushDeviceStore, @unchecked Sendable {
    private let key = "doorbell.push.device.id"
    var deviceId: Int? { UserDefaults.standard.object(forKey: key) as? Int }
    func set(_ id: Int?) {
        if let id { UserDefaults.standard.set(id, forKey: key) } else { UserDefaults.standard.removeObject(forKey: key) }
    }
}

final class InMemoryPushDeviceStore: PushDeviceStore, @unchecked Sendable {
    private let lock = NSLock()
    private var value: Int?
    init(_ id: Int? = nil) { value = id }
    var deviceId: Int? { lock.withLock { value } }
    func set(_ id: Int?) { lock.withLock { value = id } }
}

final class PushRepository: Sendable {
    private let api: APIClient
    private let auth: AuthRepository
    let devices: PushDeviceStore

    init(api: APIClient, auth: AuthRepository, devices: PushDeviceStore) {
        self.api = api
        self.auth = auth
        self.devices = devices
    }

    func register(token: String, appVersion: String, notify: Bool) async -> Result<PushDevice, APIError> {
        switch await api.send("PUT", "/api/portal/push/devices", body: PushDeviceBody(token: token, appVersion: appVersion, doorbellNotify: notify)) {
        case let .failure(error): auth.handle(error); return .failure(error)
        case let .success(response):
            guard let device = try? JSONDecoder().decode(PushDevice.self, from: response.body) else {
                return .failure(.http(status: response.status, code: "decode", text: "Réponse du serveur illisible."))
            }
            devices.set(device.id)
            return .success(device)
        }
    }

    func preferences() async -> Result<DoorbellPreferences, APIError> {
        switch await api.get("/api/portal/doorbell/preferences") {
        case let .failure(error): auth.handle(error); return .failure(error)
        case let .success(response):
            guard let prefs = try? JSONDecoder().decode(DoorbellPreferences.self, from: response.body) else {
                return .failure(.http(status: response.status, code: "decode", text: "Réponse du serveur illisible."))
            }
            return .success(prefs)
        }
    }

    /// Supprime l'appareil du cloud (204) ; un 404 vaut suppression. L'id local est oublié dans tous les cas :
    /// à la déconnexion, un appareil resté côté cloud ne sera plus joint (jeton rejeté plus tard par APNs).
    @discardableResult
    func deleteRegisteredDevice(using snapshot: SessionState? = nil) async -> Bool {
        guard let id = devices.deviceId else { return true }
        let result: Result<RawResponse, APIError> = await api.send("DELETE", "/api/portal/push/devices/\(id)", body: Optional<EmptyBody>.none, using: snapshot)
        devices.set(nil)
        switch result {
        case .success: return true
        case let .failure(error): if case .http(let status, _, _) = error, status == 404 { return true }; return false
        }
    }
}
