//
//  DoorbellPush.swift
//  Réception APNs de la sonnette (sonnette-plages-push-2026-11-008, essensys-feature-lifecycle#61) : autorisation,
//  jeton, dédoublonnage par ring_id. Aucun SDK Firebase : le cloud envoie en APNs direct (bundle id
//  essensys.essensys-iphone). Le jeton n'est jamais journalisé.
//

import Foundation
import UIKit
import UserNotifications

extension Notification.Name { static let doorbellOpened = Notification.Name("essensys.doorbell.opened") }

enum PushAuthorization: Equatable, Sendable { case notDetermined, denied, granted }

/// Frontière avec le système (autorisation, jeton) : remplacée par un faux dans les tests et le mode UI-test.
protocol PushSystem: Sendable {
    func authorization() async -> PushAuthorization
    /// Affiche la demande du système si elle n'a jamais été posée ; vrai si la notification est autorisée.
    func requestAuthorization() async -> Bool
    /// Demande l'enregistrement APNs et attend le jeton (nil si le système n'en donne pas à temps).
    func deviceToken() async -> String?
}

/// Faux fixe (tests unitaires, mode UI-test) : aucune demande système, aucun jeton réel.
final class StaticPushSystem: PushSystem, @unchecked Sendable {
    private let lock = NSLock()
    private var state: PushAuthorization
    private let grantOnRequest: Bool
    private let token: String?
    private var requests = 0
    init(authorization: PushAuthorization = .granted, grantOnRequest: Bool = true, token: String? = "ab12cd34ef56") {
        state = authorization
        self.grantOnRequest = grantOnRequest
        self.token = token
    }
    var requestCount: Int { lock.withLock { requests } }
    func setAuthorization(_ value: PushAuthorization) { lock.withLock { state = value } }
    func authorization() async -> PushAuthorization { lock.withLock { state } }
    func requestAuthorization() async -> Bool {
        lock.withLock {
            requests += 1
            if state == .notDetermined { state = grantOnRequest ? .granted : .denied }
            return state == .granted
        }
    }
    func deviceToken() async -> String? { token }
}

/// Jeton hexadécimal minuscule, tel que le cloud l'attend pour APNs.
enum PushToken {
    static func hex(_ data: Data) -> String { data.map { String(format: "%02x", $0) }.joined() }
}

/// Relais entre le délégué d'application (callbacks UIKit) et ceux qui attendent le jeton.
final class PushTokenHub: @unchecked Sendable {
    static let shared = PushTokenHub()
    private let lock = NSLock()
    private var latest: String?
    private var waiters: [UUID: CheckedContinuation<String?, Never>] = [:]

    func deliver(_ data: Data) { resolve(PushToken.hex(data)) }
    func fail() { resolve(nil) }

    private func resolve(_ token: String?) {
        let pending = lock.withLock { () -> [CheckedContinuation<String?, Never>] in
            if let token { latest = token }
            defer { waiters.removeAll() }
            return Array(waiters.values)
        }
        pending.forEach { $0.resume(returning: token) }
    }

    /// Attend le prochain jeton (ou échec) ; le dernier jeton connu sert de repli à l'expiration.
    func next(timeout: Duration = .seconds(10)) async -> String? {
        let id = UUID()
        return await withCheckedContinuation { (continuation: CheckedContinuation<String?, Never>) in
            lock.withLock { waiters[id] = continuation }
            Task { [weak self] in
                try? await Task.sleep(for: timeout)
                guard let self else { return }
                let waiting = self.lock.withLock { self.waiters.removeValue(forKey: id) }
                waiting?.resume(returning: self.lock.withLock { self.latest })
            }
        }
    }
}

final class SystemPushSystem: PushSystem, Sendable {
    func authorization() async -> PushAuthorization {
        switch await UNUserNotificationCenter.current().notificationSettings().authorizationStatus {
        case .notDetermined: .notDetermined
        case .denied: .denied
        default: .granted // authorized, provisional, ephemeral
        }
    }

    func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func deviceToken() async -> String? {
        async let token = PushTokenHub.shared.next()
        await MainActor.run { UIApplication.shared.registerForRemoteNotifications() }
        return await token
    }
}

/// Dédoublonnage par `ring_id` : une sonnette qui arrive deux fois n'affiche qu'une notification.
final class RingDeduper: @unchecked Sendable {
    static let shared = RingDeduper(defaults: .standard)
    private let lock = NSLock()
    private let defaults: UserDefaults?
    private let key = "doorbell.seen.ring.ids"
    private let capacity = 50
    private var seen: [String]

    init(defaults: UserDefaults? = nil) {
        self.defaults = defaults
        seen = defaults?.stringArray(forKey: key) ?? []
    }

    /// Vrai la première fois qu'un `ring_id` est vu ; un identifiant vide n'est jamais dédoublonné.
    func firstSight(_ ringId: String?) -> Bool {
        guard let ringId, !ringId.isEmpty else { return true }
        return lock.withLock {
            if seen.contains(ringId) { return false }
            seen.append(ringId)
            if seen.count > capacity { seen.removeFirst(seen.count - capacity) }
            defaults?.set(seen, forKey: key)
            return true
        }
    }
}

enum DoorbellPayload {
    /// `ring_id` d'une notification de sonnette (`{"type":"doorbell","ring_id","at"}` à côté de `aps`) ; nil sinon.
    static func ringId(_ userInfo: [AnyHashable: Any]) -> String? {
        guard userInfo["type"] as? String == "doorbell" else { return nil }
        return userInfo["ring_id"] as? String ?? ""
    }
}

/// Délégué d'application : jeton APNs et notifications de la sonnette. Au toucher, l'app s'ouvre sur l'accueil
/// (l'écran qu'elle montre au premier plan) : aucune route particulière.
final class EssensysAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        PushTokenHub.shared.deliver(deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        PushTokenHub.shared.fail()
    }

    /// Premier plan : une notification de la sonnette déjà vue (même `ring_id`) est silencieuse, et la
    /// précédente de même `ring_id` encore au centre de notifications est retirée.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping @Sendable (UNNotificationPresentationOptions) -> Void) {
        let identifier = notification.request.identifier
        guard let ringId = DoorbellPayload.ringId(notification.request.content.userInfo) else { completionHandler([.banner, .sound]); return }
        guard RingDeduper.shared.firstSight(ringId) else { completionHandler([]); return }
        center.getDeliveredNotifications { delivered in
            let twins = delivered.filter { $0.request.identifier != identifier && DoorbellPayload.ringId($0.request.content.userInfo) == ringId }
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: twins.map(\.request.identifier))
            completionHandler([.banner, .sound])
        }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping @Sendable () -> Void) {
        // Le toucher ouvre l'app, sur l'écran d'accueil.
        let ringId = DoorbellPayload.ringId(response.notification.request.content.userInfo)
        if let ringId {
            _ = RingDeduper.shared.firstSight(ringId)
            DispatchQueue.main.async { NotificationCenter.default.post(name: .doorbellOpened, object: nil) }
        }
        completionHandler()
    }
}
