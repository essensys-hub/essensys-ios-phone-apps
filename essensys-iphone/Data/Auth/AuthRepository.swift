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

    /// - Parameter rememberMe: demande une session de 30 jours. Un serveur qui ne la prend pas en charge ne renvoie
    ///   rien : la connexion réussit alors comme sans l'option (spec « Serveur sans prise en charge »).
    func login(email: String, password: String, rememberMe: Bool = false) async -> LoginOutcome {
        let mode = store.state.mode
        let body = LoginRequest(email: email.trimmingCharacters(in: .whitespaces), password: password,
                                rememberMe: rememberMe ? true : nil)
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
                let until = rememberMe ? RememberDate.parse(login.rememberExpiresAt) : nil
                let remembered = until != nil ? login.rememberToken.flatMap { $0.isEmpty ? nil : $0 } : nil
                store.update {
                    $0.token = login.token; $0.lanCookie = nil; $0.passwordChangeRequired = mustChange; $0.sessionEnded = false
                    $0.rememberToken = remembered
                    $0.rememberExpiresAt = remembered == nil ? nil : until
                }
                return mustChange ? .mustChangePassword : .loggedIn
            case .lan:
                guard let cookie = APIClient.extractLanCookie(response.setCookie) else {
                    return .failed("La gateway n'a pas ouvert de session.")
                }
                let until = rememberMe
                    ? (try? JSONDecoder().decode(LanLoginResponse.self, from: response.body)).flatMap { RememberDate.parse($0.rememberExpiresAt) }
                    : nil
                store.update {
                    $0.lanCookie = cookie; $0.token = nil; $0.passwordChangeRequired = false; $0.sessionEnded = false
                    $0.rememberToken = nil; $0.rememberExpiresAt = until
                }
                return .loggedIn
            }
        }
    }

    /// Cloud : même jeton d'accès conservé, mais le serveur a révoqué toutes les sessions mémorisées, y compris celle
    /// de ce téléphone : on l'oublie. LAN : la gateway détruit toutes les sessions, y compris la courante.
    func changePassword(current: String, new: String) async -> Result<Void, APIError> {
        let mode = store.state.mode
        let body = PasswordChangeRequest(currentPassword: current, newPassword: new)
        let result = mode == .cloud
            ? await api.send("POST", "/api/auth/password/change", body: body)
            : await api.send("PUT", "/api/user/me/password", body: body)
        switch result {
        case let .failure(error): return .failure(error)
        case .success:
            if mode == .lan {
                store.clearSession()
            } else {
                store.update { $0.passwordChangeRequired = false; $0.rememberToken = nil; $0.rememberExpiresAt = nil }
            }
            return .success(())
        }
    }

    /// La session locale disparaît tout de suite, réseau ou non ; la révocation côté serveur part ensuite avec
    /// les identifiants d'avant, au mieux : son échec n'est jamais montré.
    func logout() async {
        let before = store.state
        store.clearSession()
        let body = before.mode == .cloud ? before.rememberToken.map(LogoutRequest.init) : nil
        _ = await api.send("POST", "/api/auth/logout", body: body, using: before)
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
