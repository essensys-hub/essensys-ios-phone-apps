//
//  UITestBackend.swift
//  Backend simulé embarqué pour les tests XCUITest (DEBUG uniquement) : aucune requête ne quitte le
//  simulateur, aucune armoire réelle (spec ios-quality). Activé par la variable d'environnement
//  UITEST_BACKEND=1 ; options : UITEST_LINKED, UITEST_ONLINE, UITEST_TEMP_PASSWORD, UITEST_TOKEN,
//  UITEST_TEST_MODE, UITEST_THEME, UITEST_MODE, UITEST_INJECT_DELAY_MS.
//

#if DEBUG
import Foundation
import SwiftUI

enum UITestBackend {
    static let host = "essensys.uitest"
    private static let env = ProcessInfo.processInfo.environment

    static var isEnabled: Bool { env["UITEST_BACKEND"] == "1" }

    static func initialState() -> SessionState {
        var state = SessionState()
        state.cloudHost = "https://\(host)"
        state.lanHost = "https://\(host)"
        state.mode = env["UITEST_MODE"] == "lan" ? .lan : .cloud
        if env["UITEST_TOKEN"] == "1" { state.token = "jwt-uitest" }
        state.testMode = env["UITEST_TEST_MODE"] == "1"
        state.theme = env["UITEST_THEME"].flatMap(ThemePreference.init(rawValue:)) ?? .system
        return state
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var injections: [String] = []
    nonisolated(unsafe) private static var temporaryPassword = env["UITEST_TEMP_PASSWORD"] == "1"

    static var injectionLog: [String] { lock.withLock { injections } }

    static func reply(method: String, path: String, headers: [String: String], body: String) -> (Int, String) {
        let linked = env["UITEST_LINKED"] != "0"
        let online = env["UITEST_ONLINE"] != "0"
        switch path {
        case "/api/auth/login":
            let temp = lock.withLock { temporaryPassword }
            return (200, #"{"token":"jwt-uitest","password_change_required":\#(temp)}"#)
        case "/api/auth/password/change":
            lock.withLock { temporaryPassword = false }
            return (200, #"{"message":"Mot de passe mis à jour."}"#)
        case "/api/auth/logout": return (200, "")
        case "/api/portal/link-request/status":
            return (200, linked ? #"{"status":"none","portal_access":true}"# : #"{"status":"none","portal_access":false}"#)
        case "/api/portal/session":
            return (200, #"{"portal_access":true,"gateway":{"id":"gw-demo","online":\#(online)}}"#)
        case "/api/portal/history/latest":
            return (200, #"{"lastAction":null,"message":"No actions yet"}"#)
        case "/api/portal/inject":
            lock.withLock { injections.append(body) }
            if let delay = env["UITEST_INJECT_DELAY_MS"].flatMap(Double.init) { Thread.sleep(forTimeInterval: delay / 1000) }
            if headers["X-Essensys-Test-Mode"] == "dry-run" {
                return (200, #"{"status":"test_ok","dry_run":true,"validated_params":[]}"#)
            }
            return (200, #"{"guid":"g","params":[]}"#)
        case "/api/portal/exchange":
            return (200, #"{"values":[{"k":566,"v":"25"}],"stale":false,"source":"gateway_cache"}"#)
        default:
            return (404, "Not found")
        }
    }
}

final class UITestURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == UITestBackend.host }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let url = request.url!
        var body = request.httpBody ?? Data()
        if body.isEmpty, let stream = request.httpBodyStream {
            stream.open(); defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable { let n = stream.read(&buffer, maxLength: buffer.count); if n <= 0 { break }; body.append(buffer, count: n) }
        }
        let (status, text) = UITestBackend.reply(
            method: request.httpMethod ?? "GET", path: url.path,
            headers: request.allHTTPHeaderFields ?? [:], body: String(decoding: body, as: UTF8.self))
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1",
                                       headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(text.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

/// Sonde lue par les tests UI : journal des injections reçues par le backend simulé.
struct UITestProbe: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.2)) { _ in
            Text(UITestBackend.injectionLog.joined(separator: "|"))
                .font(.system(size: 1)).opacity(0.01)
                .accessibilityIdentifier("uitest-injections")
                .accessibilityValue(UITestBackend.injectionLog.joined(separator: "|"))
        }
        .allowsHitTesting(false)
    }
}
#endif
