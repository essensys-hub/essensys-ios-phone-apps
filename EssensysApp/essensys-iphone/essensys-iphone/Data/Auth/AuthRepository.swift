//
//  AuthRepository.swift
//  Authentification cloud (JWT) et LAN (cookie de session gateway). Spec mobile-auth.
//  Jumeau de AuthRepository.kt ; le mot de passe n'est jamais persisté.
//

import Foundation

enum LoginOutcome: Equatable, Sendable {
    case loggedIn
    case mustChangePassword
    case failed(String)
}

final class AuthRepository: Sendable {
    private let api: APIClient
    private let store: SessionStore

    init(api: APIClient, store: SessionStore) {
        self.api = api
        self.store = store
    }

    func login(email: String, password: String) async -> LoginOutcome {
        let mode = store.state.mode
        let body = LoginRequest(email: email.trimmingCharacters(in: .whitespaces), password: password)
        switch await api.send("POST", "/api/auth/login", body: body) {
        case let .failure(error):
            return .failed(loginMessage(error))
        case let .success(response):
            switch mode {
            case .cloud:
                guard let login = try? JSONDecoder().decode(CloudLoginResponse.self, from: response.body) else {
                    return .failed("Réponse du serveur illisible.")
                }
                let mustChange = login.passwordChangeRequired ?? false
                store.update { $0.token = login.token; $0.lanCookie = nil; $0.passwordChangeRequired = mustChange }
                return mustChange ? .mustChangePassword : .loggedIn
            case .lan:
                guard let cookie = APIClient.extractLanCookie(response.setCookie) else {
                    return .failed("La gateway n'a pas ouvert de session.")
                }
                store.update { $0.lanCookie = cookie; $0.token = nil; $0.passwordChangeRequired = false }
                return .loggedIn
            }
        }
    }

    /// Cloud : même jeton conservé. LAN : la gateway détruit toutes les sessions, y compris la courante.
    func changePassword(current: String, new: String) async -> Result<Void, APIError> {
        let mode = store.state.mode
        let body = PasswordChangeRequest(currentPassword: current, newPassword: new)
        let result = mode == .cloud
            ? await api.send("POST", "/api/auth/password/change", body: body)
            : await api.send("PUT", "/api/user/me/password", body: body)
        switch result {
        case let .failure(error): return .failure(error)
        case .success:
            if mode == .lan { store.clearSession() } else { store.update { $0.passwordChangeRequired = false } }
            return .success(())
        }
    }

    func logout() async {
        _ = await api.send("POST", "/api/auth/logout", body: EmptyBody?.none)
        store.clearSession()
    }

    /// Réaction centralisée (spec « Expiration et révocation »).
    func handle(_ error: APIError) {
        switch error {
        case .unauthorized: store.clearSession()
        case let .forbidden(code, _) where code == "account_forbidden" || code == "account_disabled": store.clearSession()
        case .passwordChangeRequired: store.update { $0.passwordChangeRequired = true }
        default: break
        }
    }

    private func loginMessage(_ error: APIError) -> String {
        switch error {
        case let .unauthorized(code, text):
            if code == "temporary_password_expired" { return error.userMessage }
            if text?.hasPrefix("Please login with") == true {
                return "Ce compte utilise une connexion Google ou Apple, non disponible dans l'app pour l'instant."
            }
            return "Email ou mot de passe incorrect."
        default:
            return error.userMessage
        }
    }
}
