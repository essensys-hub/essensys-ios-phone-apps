//
//  APIClient.swift
//  Client HTTP async/await (jumeau de ApiCaller.kt). Bearer en cloud, cookie essensys_lan_session
//  en LAN, en-tête dry-run en mode test. Aucun repli « démo » (spec connection-modes).
//

import Foundation

struct RawResponse: Sendable {
    let status: Int
    let body: Data
    let setCookie: String?
}

final class APIClient: Sendable {
    static let lanCookieName = "essensys_lan_session"

    private let store: SessionStore
    private let cloudSession: URLSession
    private let lanSession: URLSession
    private let guardNoArmoire: NoArmoireGuard?
    private let log: AppLog?
    private let now: @Sendable () -> Date
    private let remember = RememberRefresher()

    /// - Parameter protocolClasses: backend simulé (tests, mode UI-test) ; nil en production.
    /// - Parameter log: journal du bouton Support (méthode, chemin, code, durée ; jamais d'en-tête ni de corps).
    /// - Parameter now: horloge, contrôlée dans les tests de la session mémorisée.
    init(store: SessionStore, guardNoArmoire: Bool, protocolClasses: [AnyClass]? = nil, log: AppLog? = nil,
         now: @escaping @Sendable () -> Date = { Date() }) {
        self.store = store
        self.log = log
        self.now = now
        self.guardNoArmoire = guardNoArmoire ? NoArmoireGuard() : nil
        func configuration() -> URLSessionConfiguration {
            let c = URLSessionConfiguration.ephemeral
            c.timeoutIntervalForRequest = 15
            c.httpShouldSetCookies = false // cookie LAN géré explicitement et stocké dans le Keychain
            if let protocolClasses { c.protocolClasses = protocolClasses }
            return c
        }
        cloudSession = URLSession(configuration: configuration())
        lanSession = protocolClasses == nil
            ? URLSession(configuration: configuration(), delegate: PinnedLanDelegate(store: store), delegateQueue: nil)
            : URLSession(configuration: configuration())
    }

    func get(_ path: String) async -> Result<RawResponse, APIError> {
        await execute(method: "GET", path: path, body: nil)
    }

    /// Clés triées : corps déterministes ({"k":…,"v":…}), comparables entre iOS, Android et les tests.
    private static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    /// - Parameter snapshot: identifiants à utiliser à la place de ceux du magasin (déconnexion : la session locale
    ///   est déjà effacée quand la requête part).
    func send<Body: Encodable>(_ method: String, _ path: String, body: Body?,
                               using snapshot: SessionState? = nil) async -> Result<RawResponse, APIError> {
        let data = body.flatMap { try? Self.encoder().encode($0) }
        return await execute(method: method, path: path, body: data, using: snapshot)
    }

    private static let authPrefix = "/api/auth/"

    /// Session mémorisée, en cloud, pour une route qui n'est pas elle-même l'authentification (un 401 y a un autre sens).
    private func isRenewable(path: String, sent: SessionState) -> Bool {
        sent.mode == .cloud && sent.rememberToken != nil && !path.hasPrefix(Self.authPrefix)
    }

    private func execute(method: String, path: String, body: Data?,
                         using snapshot: SessionState? = nil) async -> Result<RawResponse, APIError> {
        let sent = snapshot ?? store.state
        let first = await perform(method: method, path: path, body: body, state: sent)
        guard snapshot == nil, case .failure(.unauthorized) = first, isRenewable(path: path, sent: sent) else { return first }
        // L'horloge locale ne fait qu'éviter un appel inutile : le serveur reste l'autorité sur la fin des 30 jours.
        if let until = sent.rememberExpiresAt, until <= now() {
            store.clearSession(ended: true)
            log?.event("session", "Session mémorisée arrivée à échéance")
            return first
        }
        switch await remember.renew(staleToken: sent.token, current: { [store] in store.state.token },
                                    perform: { [self] in await renewAccess() }) {
        case .renewed: return await perform(method: method, path: path, body: body, state: store.state)
        case .rejected: return first
        case .unavailable:
            // Pas de 401 : les dépôts effaceraient la session mémorisée alors que le serveur n'a rien refusé.
            let host = URL(string: sent.baseURL)?.host ?? sent.baseURL
            return .failure(.network(host: host, cause: "renouvellement de la session impossible"))
        }
    }

    /// Échange la session mémorisée contre un jeton d'accès de 24 h. `remember_expires_at` n'est jamais relu :
    /// les 30 jours partent de la saisie du mot de passe.
    private func renewAccess() async -> RememberRefresher.Outcome {
        let state = store.state
        guard let rememberToken = state.rememberToken else { return .rejected }
        let body = try? Self.encoder().encode(RememberRefreshRequest(rememberToken: rememberToken))
        switch await perform(method: "POST", path: Self.authPrefix + "remember/refresh", body: body, state: state, authenticated: false) {
        case let .success(response):
            guard let renewed = try? JSONDecoder().decode(RememberRefreshResponse.self, from: response.body) else { return .unavailable }
            store.update {
                $0.token = renewed.token
                if let mustChange = renewed.passwordChangeRequired { $0.passwordChangeRequired = mustChange }
            }
            log?.event("session", "Accès renouvelé par la session mémorisée")
            return .renewed
        case .failure(.unauthorized), .failure(.forbidden):
            store.clearSession(ended: true)
            log?.event("session", "Session mémorisée terminée par le serveur")
            return .rejected
        case .failure:
            return .unavailable
        }
    }

    private func perform(method: String, path: String, body: Data?, state: SessionState,
                         authenticated: Bool = true) async -> Result<RawResponse, APIError> {
        let base = state.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let host = URL(string: base)?.host ?? base
        guard let url = URL(string: base + path) else { return .failure(.network(host: host, cause: "URL invalide")) }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        if body != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        if authenticated {
            switch state.mode {
            case .cloud: if let token = state.token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
            case .lan: if let cookie = state.lanCookie { request.setValue("\(Self.lanCookieName)=\(cookie)", forHTTPHeaderField: "Cookie") }
            }
        }
        if state.testMode { request.setValue(NoArmoireGuard.dryRun, forHTTPHeaderField: NoArmoireGuard.testModeHeader) }
        if let guardNoArmoire, guardNoArmoire.shouldBlock(request) {
            // Jamais d'armoire réelle en test : l'appel échoue sans partir sur le réseau.
            return .failure(.http(status: 0, code: "no_armoire", text: ArmoireMutationBlocked(request: "\(method) \(url)").description))
        }
        let start = ContinuousClock.now
        let elapsed = { Int((ContinuousClock.now - start) / .milliseconds(1)) }
        do {
            let session = state.mode == .cloud ? cloudSession : lanSession
            let (data, response) = try await session.data(for: request)
            log?.http(method: method, path: url.path, code: (response as? HTTPURLResponse)?.statusCode, ms: elapsed())
            guard let http = response as? HTTPURLResponse else { return .failure(.network(host: host, cause: "réponse invalide")) }
            guard (200..<300).contains(http.statusCode) else {
                return .failure(ErrorBody.toAPIError(status: http.statusCode, body: data))
            }
            return .success(RawResponse(status: http.statusCode, body: data, setCookie: http.value(forHTTPHeaderField: "Set-Cookie")))
        } catch let error as URLError where error.code == .cancelled || error.code == .serverCertificateUntrusted
                    || error.code == .secureConnectionFailed || error.code == .serverCertificateHasUnknownRoot {
            log?.http(method: method, path: url.path, code: nil, ms: elapsed(), error: "URLError(\(error.code.rawValue))")
            return .failure(.network(host: host, cause: "certificat non confirmé (\(error.code.rawValue))"))
        } catch {
            log?.http(method: method, path: url.path, code: nil, ms: elapsed(), error: (error as? URLError).map { "URLError(\($0.code.rawValue))" } ?? String(describing: type(of: error)))
            return .failure(.network(host: host, cause: error.localizedDescription))
        }
    }

    /// Sonde le certificat présenté par une gateway LAN (design D4).
    static func probeCertificate(baseURL: String, protocolClasses: [AnyClass]? = nil) async -> Data? {
        let delegate = ProbeDelegate()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 5
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        guard let url = URL(string: baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        _ = try? await session.data(for: request)
        return delegate.captured
    }

    static func extractLanCookie(_ setCookie: String?) -> String? {
        guard let setCookie else { return nil }
        let prefix = "\(lanCookieName)="
        for header in setCookie.components(separatedBy: ",") {
            let pair = header.components(separatedBy: ";")[0].trimmingCharacters(in: .whitespaces)
            guard pair.hasPrefix(prefix) else { continue }
            let value = String(pair.dropFirst(prefix.count))
            return value.isEmpty ? nil : value
        }
        return nil
    }

}
