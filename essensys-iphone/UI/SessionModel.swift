//
//  SessionModel.swift
//  État de session vu par l'UI (jumeau de SessionViewModel.kt) : connexion, certificat LAN, liaison,
//  état de l'armoire, dernière action, réglages. Spec connection-modes / mobile-auth.
//

import Foundation
import Observation

/// Certificat LAN présenté, en attente de confirmation par l'utilisateur (design D4).
struct PendingCertificate: Equatable {
    let host: String
    let fingerprint: String
    let der: Data
}

@MainActor @Observable
final class SessionModel {
    static let sessionPeriod: Duration = .seconds(60)
    static let lastActionPeriod: Duration = .seconds(2)

    private(set) var session: SessionState
    private(set) var busy = false
    var error: String?
    var info: String?
    var pendingCertificate: PendingCertificate?
    private(set) var link: LinkState?
    private(set) var gatewayOnline: Bool?
    private(set) var lastAction: LastAction?

    private let container: AppContainer
    private let probe: @Sendable (String) async -> Data?
    private let sessionPeriod: Duration
    private let lastActionPeriod: Duration

    init(container: AppContainer,
         probe: @escaping @Sendable (String) async -> Data? = { await APIClient.probeCertificate(baseURL: $0) },
         sessionPeriod: Duration = SessionModel.sessionPeriod,
         lastActionPeriod: Duration = SessionModel.lastActionPeriod) {
        self.container = container
        self.probe = probe
        self.sessionPeriod = sessionPeriod
        self.lastActionPeriod = lastActionPeriod
        session = container.store.state
        container.store.observe { [weak self] state in
            Task { @MainActor in self?.session = state }
        }
    }

    private var store: SessionStore { container.store }

    func setMode(_ mode: ConnectionMode) {
        guard mode != session.mode else { return }
        store.update { $0.mode = mode; $0.token = nil; $0.lanCookie = nil; $0.passwordChangeRequired = false }
        session = store.state
        link = nil
        error = nil
    }

    /// Refuse le HTTP en clair (spec « HTTPS uniquement »).
    @discardableResult
    func setLanHost(_ raw: String) -> Bool {
        let host = raw.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if host.lowercased().hasPrefix("http://") {
            error = "Seule une connexion sécurisée (https://) est possible."
            return false
        }
        let normalized = host.lowercased().hasPrefix("https://") ? host : "https://\(host)"
        if normalized != session.lanHost {
            store.update { $0.lanHost = normalized; $0.pinnedLanCertificate = nil }
            session = store.state
        }
        error = nil
        return true
    }

    func login(email: String, password: String) async {
        error = nil
        if session.mode == .lan, session.pinnedLanCertificate == nil {
            busy = true
            defer { busy = false }
            guard let der = await probe(session.lanHost) else {
                error = APIError.network(host: URL(string: session.lanHost)?.host ?? session.lanHost, cause: nil).userMessage
                return
            }
            pendingCertificate = PendingCertificate(
                host: URL(string: session.lanHost)?.host ?? session.lanHost, fingerprint: LanTrust.sha256(der), der: der)
            return
        }
        busy = true
        defer { busy = false }
        switch await container.auth.login(email: email, password: password) {
        case let .failed(message): error = message
        case .loggedIn, .mustChangePassword: session = store.state; await refreshLink()
        }
    }

    func confirmCertificate(_ accept: Bool) {
        guard let pending = pendingCertificate else { return }
        pendingCertificate = nil
        if accept {
            store.update { $0.pinnedLanCertificate = pending.der }
            session = store.state
            info = "Certificat de la gateway confirmé. Vous pouvez vous connecter."
        }
    }

    func forgetLanCertificate() {
        store.update { $0.pinnedLanCertificate = nil }
        session = store.state
    }

    func changePassword(current: String, new: String) async {
        guard new.count >= 8 else { error = "Le mot de passe doit contenir au moins 8 caractères."; return }
        busy = true
        defer { busy = false }
        let wasLan = session.mode == .lan
        switch await container.auth.changePassword(current: current, new: new) {
        case let .failure(e): error = e.userMessage
        case .success:
            error = nil
            info = wasLan ? "Mot de passe changé. La gateway a fermé vos sessions : reconnectez-vous." : "Mot de passe mis à jour."
            session = store.state
        }
    }

    func refreshLink() async {
        if session.mode == .lan { link = .linked; return }
        switch await container.portal.linkState() {
        case let .success(state): link = state
        case let .failure(e): error = e.userMessage; link = nil
        }
        session = store.state
    }

    func requestLink(serial: String, message: String) async {
        guard !serial.trimmingCharacters(in: .whitespaces).isEmpty else { error = "Le numéro de série est obligatoire."; return }
        switch await container.portal.requestLink(serial: serial, message: message) {
        case .success: await refreshLink()
        case let .failure(e): error = e.userMessage
        }
    }

    /// Rafraîchissements au premier plan (design D6 Android) : la tâche est annulée hors premier plan.
    func pollWhileVisible() async {
        if session.mode == .lan {
            _ = await container.portal.lanSessionValid()
            gatewayOnline = true
            session = store.state
            return
        }
        async let session: Void = pollGateway()
        async let action: Void = pollLastAction()
        _ = await (session, action)
    }

    private func pollGateway() async {
        while !Task.isCancelled {
            if case let .success(online) = await container.portal.gatewayOnline() { gatewayOnline = online }
            session = store.state
            try? await Task.sleep(for: sessionPeriod)
        }
    }

    private func pollLastAction() async {
        while !Task.isCancelled {
            if case let .success(action) = await container.portal.lastAction() { lastAction = action }
            try? await Task.sleep(for: lastActionPeriod)
        }
    }

    func setTheme(_ theme: ThemePreference) { store.update { $0.theme = theme }; session = store.state }
    func setTestMode(_ enabled: Bool) { store.update { $0.testMode = enabled }; session = store.state }

    func logout() async {
        await container.auth.logout()
        link = nil
        lastAction = nil
        session = store.state
    }
}
