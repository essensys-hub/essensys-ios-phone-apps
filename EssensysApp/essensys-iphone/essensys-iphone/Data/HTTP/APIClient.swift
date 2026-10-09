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

    /// - Parameter protocolClasses: backend simulé (tests, mode UI-test) ; nil en production.
    init(store: SessionStore, guardNoArmoire: Bool, protocolClasses: [AnyClass]? = nil) {
        self.store = store
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

    func send<Body: Encodable>(_ method: String, _ path: String, body: Body?) async -> Result<RawResponse, APIError> {
        let data = body.flatMap { try? JSONEncoder().encode($0) }
        return await execute(method: method, path: path, body: data)
    }

    private func execute(method: String, path: String, body: Data?) async -> Result<RawResponse, APIError> {
        let state = store.state
        let base = state.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let host = URL(string: base)?.host ?? base
        guard let url = URL(string: base + path) else { return .failure(.network(host: host, cause: "URL invalide")) }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        if body != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        switch state.mode {
        case .cloud: if let token = state.token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        case .lan: if let cookie = state.lanCookie { request.setValue("\(Self.lanCookieName)=\(cookie)", forHTTPHeaderField: "Cookie") }
        }
        if state.testMode { request.setValue(NoArmoireGuard.dryRun, forHTTPHeaderField: NoArmoireGuard.testModeHeader) }
        if let guardNoArmoire, guardNoArmoire.shouldBlock(request) {
            // Jamais d'armoire réelle en test : l'appel échoue sans partir sur le réseau.
            return .failure(.http(status: 0, code: "no_armoire", text: ArmoireMutationBlocked(request: "\(method) \(url)").description))
        }
        do {
            let session = state.mode == .cloud ? cloudSession : lanSession
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return .failure(.network(host: host, cause: "réponse invalide")) }
            guard (200..<300).contains(http.statusCode) else {
                return .failure(ErrorBody.toAPIError(status: http.statusCode, body: data))
            }
            return .success(RawResponse(status: http.statusCode, body: data, setCookie: http.value(forHTTPHeaderField: "Set-Cookie")))
        } catch let error as URLError where error.code == .cancelled || error.code == .serverCertificateUntrusted
                    || error.code == .secureConnectionFailed || error.code == .serverCertificateHasUnknownRoot {
            return .failure(.network(host: host, cause: "certificat non confirmé (\(error.code.rawValue))"))
        } catch {
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
