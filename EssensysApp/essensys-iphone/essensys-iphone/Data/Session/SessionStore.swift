//
//  SessionStore.swift
//  État de session (jumeau de SessionStore.kt). Les secrets (jeton, cookie, certificat épinglé)
//  sont persistés dans le Keychain par SessionPersistence ; le mot de passe n'est jamais stocké.
//

import Foundation
import os

enum ConnectionMode: String, Codable, Sendable { case cloud, lan }

enum ThemePreference: String, Codable, Sendable, CaseIterable { case system, light, dark }

enum Hosts {
    static let cloud = "https://mon.essensys.fr"
    static let lanDefault = "https://mon.essensys.local"
}

struct SessionState: Equatable, Sendable {
    var mode: ConnectionMode = .cloud
    var lanHost: String = Hosts.lanDefault
    var token: String?
    var lanCookie: String?
    var passwordChangeRequired = false
    var theme: ThemePreference = .system
    var testMode = false
    /// Certificat de la gateway LAN (DER) confirmé par l'utilisateur (design D4).
    var pinnedLanCertificate: Data?
    /// Non modifiable par l'utilisateur ; surchargé uniquement par les tests (backend simulé).
    var cloudHost: String = Hosts.cloud

    var baseURL: String { mode == .cloud ? cloudHost : lanHost }
    var isAuthenticated: Bool { mode == .cloud ? token != nil : lanCookie != nil }
}

/// Persistance de la session ; implémentée par le Keychain en production, en mémoire dans les tests.
protocol SessionPersistence: Sendable {
    func load() -> SessionState
    func save(_ state: SessionState)
}

struct InMemoryPersistence: SessionPersistence {
    var initial = SessionState()
    func load() -> SessionState { initial }
    func save(_ state: SessionState) {}
}

/// Magasin de session partagé entre l'UI (MainActor) et la couche réseau (threads URLSession).
final class SessionStore: Sendable {
    private let lock: OSAllocatedUnfairLock<SessionState>
    private let persistence: SessionPersistence
    private let observers = OSAllocatedUnfairLock<[@Sendable (SessionState) -> Void]>(initialState: [])

    init(persistence: SessionPersistence) {
        self.persistence = persistence
        self.lock = OSAllocatedUnfairLock(initialState: persistence.load())
    }

    var state: SessionState { lock.withLock { $0 } }

    func update(_ transform: (inout SessionState) -> Void) {
        let next = lock.withLockUnchecked { state -> SessionState in
            transform(&state)
            return state
        }
        persistence.save(next)
        observers.withLock { $0 }.forEach { $0(next) }
    }

    /// Efface jeton, cookie et verrou ; garde les préférences (mode, hôte, thème, certificat épinglé).
    func clearSession() {
        update { $0.token = nil; $0.lanCookie = nil; $0.passwordChangeRequired = false }
    }

    func observe(_ observer: @escaping @Sendable (SessionState) -> Void) {
        observers.withLock { $0.append(observer) }
    }
}
