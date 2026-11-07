//
//  UITestBackend.swift
//  Backend simulé embarqué pour les tests XCUITest (DEBUG uniquement) : aucune requête ne quitte le
//  simulateur, aucune armoire réelle (spec ios-quality). Activé par la variable d'environnement
//  UITEST_BACKEND=1 ; options : UITEST_LINKED, UITEST_ONLINE, UITEST_TEMP_PASSWORD, UITEST_TOKEN,
//  UITEST_TEST_MODE, UITEST_THEME, UITEST_MODE, UITEST_INJECT_DELAY_MS, UITEST_EXCHANGE (« k=v,k=v »),
//  UITEST_FAIL_FIRST_INJECT, UITEST_ROLE (rôle du compte simulé, par défaut admin_local / lan_admin),
//  UITEST_LIGHT_NAMES (« id=Nom;id=Nom » : noms personnalisés au départ), UITEST_NAMES_READ_FAIL=1 (lecture des noms en 503),
//  UITEST_NAMES_WRITE=400|403|503 (écriture refusée avec ce code).
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
        if env["UITEST_TOKEN"] == "1" {
            state.token = "jwt-uitest"
            if state.mode == .lan { state.lanCookie = "uitest" }
        }
        state.isAdmin = AdminRole.isAdmin(role: role, mode: state.mode)
        state.testMode = env["UITEST_TEST_MODE"] == "1"
        state.theme = env["UITEST_THEME"].flatMap(ThemePreference.init(rawValue:)) ?? .system
        return state
    }

    /// Rôle du compte simulé : renvoyé par la connexion, la session et /api/user/me.
    static var role: String { env["UITEST_ROLE"] ?? (env["UITEST_MODE"] == "lan" ? "lan_admin" : "admin_local") }
    private static var roleIsAdmin: Bool { AdminRole.isAdmin(role: role, mode: env["UITEST_MODE"] == "lan" ? .lan : .cloud) }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var injections: [String] = []
    nonisolated(unsafe) private static var mutations: [String] = []
    nonisolated(unsafe) private static var failNextInject = env["UITEST_FAIL_FIRST_INJECT"] == "1"
    nonisolated(unsafe) private static var exchange: [Int: String] = {
        var values = [566: "25"]
        for pair in (env["UITEST_EXCHANGE"] ?? "").split(separator: ",") {
            let parts = pair.split(separator: "=")
            if parts.count == 2, let k = Int(parts[0]) { values[k] = String(parts[1]) }
        }
        return values
    }()
    /// Noms personnalisés des lumières (id → nom, version) ; la mise à jour incrémente la version.
    nonisolated(unsafe) private static var lightNames: [String: (name: String?, version: Int)] = {
        var values: [String: (name: String?, version: Int)] = [:]
        for pair in (env["UITEST_LIGHT_NAMES"] ?? "").split(separator: ";") {
            let parts = pair.split(separator: "=", maxSplits: 1)
            if parts.count == 2 { values[String(parts[0])] = (String(parts[1]), 1) }
        }
        return values
    }()
    nonisolated(unsafe) private static var temporaryPassword = env["UITEST_TEMP_PASSWORD"] == "1"

    static var injectionLog: [String] { lock.withLock { injections } }
    /// Connexions et déconnexions reçues (« login remember_me=true », « logout {corps} ») : sonde `uitest-logins`.
    nonisolated(unsafe) private static var logins: [String] = []
    static var loginLog: [String] { lock.withLock { logins } }
    /// Messages « envoyés » au support : le composeur Mail n'est jamais présenté en test.
    nonisolated(unsafe) private static var supportMails: [String] = []
    static var supportMailLog: [String] { lock.withLock { supportMails } }
    static func recordSupportMail(_ p: SupportMail.Parameters) {
        lock.withLock { supportMails.append("\(p.recipients.joined(separator: ","))|\(p.subject)|\(p.fileName)|\(p.mimeType)") }
    }
    /// Mutations hors inject (scénarios, alarme) : « METHOD chemin corps ».
    static var mutationLog: [String] { lock.withLock { mutations } }

    private static let testOK = #"{"status":"test_ok","dry_run":true,"validated_params":[]}"#

    static func reply(method: String, path: String, query: String? = nil, headers: [String: String], body: String) -> (Int, String) {
        let linked = env["UITEST_LINKED"] != "0"
        let online = env["UITEST_ONLINE"] != "0"
        switch path {
        case "/api/auth/login":
            let temp = lock.withLock { temporaryPassword }
            let remember = body.contains(#""remember_me":true"#)
            lock.withLock { logins.append("login remember_me=\(remember)") }
            // Session mémorisée simulée : fin à 30 jours, comme le serveur la fixe à la saisie du mot de passe.
            let until = ISO8601DateFormatter().string(from: Date().addingTimeInterval(30 * 86_400))
            let extra = remember ? #","remember_token":"remember-uitest","remember_expires_at":"\#(until)""# : ""
            return (200, #"{"token":"jwt-uitest","user":{"id":1,"role":"\#(role)"},"password_change_required":\#(temp)\#(extra)}"#)
        case "/api/auth/password/change":
            lock.withLock { temporaryPassword = false }
            return (200, #"{"message":"Mot de passe mis à jour."}"#)
        case "/api/auth/logout":
            lock.withLock { logins.append("logout \(body)") }
            return (200, "")
        case "/api/portal/link-request/status":
            return (200, linked ? #"{"status":"none","portal_access":true}"# : #"{"status":"none","portal_access":false}"#)
        case "/api/portal/session":
            return (200, sessionJSON(gatewayOnline: online))
        case "/api/user/me":
            return (200, #"{"user":{"id":1,"role":"\#(role)"}}"#)
        case "/api/portal/health", "/health":
            return (200, #"{"status":"ok"}"#)
        case "/api/portal/history/latest":
            return (200, #"{"lastAction":null,"message":"No actions yet"}"#)
        case "/api/portal/inject", "/api/portal/inject/batch", "/api/admin/inject":
            let fail = lock.withLock { () -> Bool in
                injections.append(body)
                defer { failNextInject = false }
                return failNextInject
            }
            if fail { return (429, "Rate limit exceeded") }
            if let delay = env["UITEST_INJECT_DELAY_MS"].flatMap(Double.init) { Thread.sleep(forTimeInterval: delay / 1000) }
            if headers["X-Essensys-Test-Mode"] == "dry-run" { return (200, testOK) }
            return (200, #"{"guid":"g","guids":["g"],"params":[]}"#)
        case "/api/portal/exchange", "/api/admin/exchange":
            return (200, exchangeReply(query))
        case "/api/admin/heating/sync":
            return (200, #"{"status":"started","sync":{"active":true,"received":0,"total":84}}"#)
        case "/api/admin/heating/sync/status":
            return (200, #"{"active":false,"received":84,"total":84,"chunksTotal":3,"chunksCompleted":3}"#)
        case "/api/portal/web/actions":
            lock.withLock { mutations.append("\(method) \(path) \(body)") }
            return headers["X-Essensys-Test-Mode"] == "dry-run" ? (200, testOK) : (200, #"{"status":"ok","message":"Action sent to queue"}"#)
        case "/api/portal/lights/timers", "/api/admin/lights/timers":
            return (200, timersReply())
        case "/api/portal/lights/names", "/api/lights/names":
            if env["UITEST_NAMES_READ_FAIL"] == "1" { return (503, #"{"error":"names_unavailable"}"#) }
            return (200, namesReply())
        default:
            if path.hasPrefix("/api/portal/admin/lights/names/") || path.hasPrefix("/api/admin/lights/names/") {
                return setName(path: path, headers: headers, body: body)
            }
            if path.hasPrefix("/api/portal/admin/lights/timers/") || path.hasPrefix("/api/admin/lights/timers/") {
                return setTimer(path: path, headers: headers, body: body)
            }
            if path.range(of: "^/api/(portal/)?scenarios", options: .regularExpression) != nil {
                return scenarios(method: method, path: path, headers: headers, body: body)
            }
            return (404, "Not found")
        }
    }

    /// Session portail simulée. `UITEST_GATEWAY=none` : installation sans gateway (pas de bloc `gateway`) ;
    /// `UITEST_ARMOIRE=none|seen|old` : armoire absente, vue il y a peu (`online`) ou ancienne.
    /// Par défaut, l'armoire est vue si la gateway est en ligne (essensys-feature-lifecycle#37).
    private static func sessionJSON(gatewayOnline: Bool) -> String {
        let hasGateway = env["UITEST_GATEWAY"] != "none"
        let gateway = hasGateway ? #","gateway":{"id":"gw-demo","online":\#(gatewayOnline)}"# : ""
        let armoire: String
        switch env["UITEST_ARMOIRE"] {
        case "none": armoire = ""
        case "seen": armoire = armoireJSON(online: true)
        case "old": armoire = armoireJSON(online: false)
        default: armoire = armoireJSON(online: hasGateway && gatewayOnline)
        }
        return #"{"user":{"id":1,"email":"demo@essensys.fr","first_name":"Camille","last_name":"Démo","role":"\#(role)"},"portal_access":true\#(gateway)\#(armoire)}"#
    }

    private static func armoireJSON(online: Bool) -> String {
        #","armoire":{"id":1,"no_serie":"SC944D-0001","last_seen":"2026-10-25T08:00:00Z","online":\#(online)}"#
    }

    /// Temporisations simulées : valeur lue dans la table d'échange simulée (jamais lue = null), comme le serveur.
    private static func timersReply() -> String {
        let values = lock.withLock { exchange }
        let items = IndexTable.lightTimers.map { timer -> String in
            let minutes = values[timer.key].map { $0 } ?? "null"
            return #"{"id":"\#(timer.id)","label":"\#(timer.name)","key":\#(timer.key),"minutes":\#(minutes)}"#
        }
        return #"{"timers":[\#(items.joined(separator: ","))]}"#
    }

    private static func nameJSON(_ light: IndexTable.Light) -> String {
        let entry = lock.withLock { lightNames[light.id] }
        let name = entry?.name.map { "\"\($0)\"" } ?? "null"
        let updated = entry.map { _ in #""2026-11-07T10:15:30.123Z""# } ?? "null"
        return #"{"id":"\#(light.id)","default":"\#(light.name)","name":\#(name),"version":\#(entry?.version ?? 0),"updated_at":\#(updated)"#
    }

    private static func namesReply() -> String {
        #"{"lights":[\#(IndexTable.lights.map { nameJSON($0) + "}" }.joined(separator: ","))]}"#
    }

    /// PUT …/lights/names/{id} : droits, validation (règle du nom) et mode essai à blanc comme le serveur.
    private static func setName(path: String, headers: [String: String], body: String) -> (Int, String) {
        guard roleIsAdmin else { return (403, #"{"error":"forbidden"}"#) }
        if let code = env["UITEST_NAMES_WRITE"].flatMap(Int.init) {
            let error = code == 503 ? "names_unavailable" : code == 403 ? "forbidden" : "invalid_name"
            return (code, #"{"error":"\#(error)"}"#)
        }
        let id = String(path.split(separator: "/").last ?? "")
        guard let light = IndexTable.lights.first(where: { $0.id == id }) else { return (400, #"{"error":"unknown_light"}"#) }
        guard let data = body.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any], object.keys.contains("name") else {
            return (400, #"{"error":"invalid_name"}"#)
        }
        var name: String?
        if let text = object["name"] as? String {
            guard let valid = LightNameFormat.validate(text) else { return (400, #"{"error":"invalid_name"}"#) }
            name = valid
        }
        lock.withLock { mutations.append("PUT \(path) \(body)") }
        let dry = headers["X-Essensys-Test-Mode"] == "dry-run"
        if !dry {
            lock.withLock { lightNames[id] = (name, (lightNames[id]?.version ?? 0) + 1) }
        }
        return (200, nameJSON(light) + #","status":"\#(dry ? "dry_run" : "saved")"}"#)
    }

    private static func setTimer(path: String, headers: [String: String], body: String) -> (Int, String) {
        guard roleIsAdmin else { return (403, #"{"error":"forbidden"}"#) }
        let id = String(path.split(separator: "/").last ?? "")
        guard let timer = IndexTable.lightTimer(id: id) else { return (400, #"{"error":"unknown_light"}"#) }
        guard let data = body.data(using: .utf8),
              let minutes = (try? JSONDecoder().decode(LightTimerRequest.self, from: data))?.minutes,
              (0...255).contains(minutes) else { return (400, #"{"error":"invalid_minutes"}"#) }
        lock.withLock { mutations.append("PUT \(path) \(body)") }
        if headers["X-Essensys-Test-Mode"] == "dry-run" { return (200, #"{"id":"\#(id)","minutes":\#(minutes),"status":"dry_run"}"#) }
        lock.withLock { exchange[timer.key] = String(minutes) }
        return (200, #"{"id":"\#(id)","minutes":\#(minutes),"status":"queued"}"#)
    }

    private static func exchangeReply(_ query: String?) -> String {
        let keys = (query ?? "").replacingOccurrences(of: "keys=", with: "").split(separator: ",").compactMap { Int($0) }
        let values = lock.withLock { exchange }
        let items = keys.compactMap { k in values[k].map { #"{"k":\#(k),"v":"\#($0)"}"# } }.joined(separator: ",")
        return #"{"values":[\#(items)],"stale":false,"source":"gateway_cache"}"#
    }

    private static func scenarios(method: String, path: String, headers: [String: String], body: String) -> (Int, String) {
        let rest = path.replacingOccurrences(of: "^/api/(portal/)?scenarios/?", with: "", options: .regularExpression)
        let labels = [2: "Je sors", 3: "Je pars en vacances", 4: "Je rentre", 5: "Je vais me coucher", 6: "Je me lève", 7: "Personnalisé 1", 8: "Personnalisé 2"]
        if rest.isEmpty {
            let slots = (1...8).map { slot -> String in
                let base = 592 + (slot - 1) * 41
                let last = slot == 2 ? #","last_launched":2"# : ""
                return #"{"slot_number":\#(slot),"label":"\#(labels[slot] ?? "Serveur")","base_index":\#(base),"end_index":\#(base + 40),"editable":\#(slot >= 2)\#(last)}"#
            }
            return (200, #"{"slots":[\#(slots.joined(separator: ","))]}"#)
        }
        if rest == "meta/bitmasks" {
            return (200, #"{"fields":[{"index":605,"name":"Eteindre_PDV_LSB","bits":[{"bit":0,"value":1,"label":"Entrée"},{"bit":1,"value":2,"label":"Salon 1"},{"bit":2,"value":4,"label":"Salon 2"}]},{"index":617,"name":"OuvrirVolets_PDV","bits":[{"bit":0,"value":1,"label":"Salon 1"},{"bit":5,"value":32,"label":"Bureau"}]}]}"#)
        }
        if method == "GET", let slot = Int(rest) {
            let base = 592 + (slot - 1) * 41
            let params = (base...(base + 40)).map { #"{"k":\#($0),"v":"0"}"# }.joined(separator: ",")
            return (200, #"{"slot_number":\#(slot),"label":"\#(labels[slot] ?? "")","editable":true,"params":[\#(params)]}"#)
        }
        lock.withLock { mutations.append("\(method) \(path) \(body)") }
        return headers["X-Essensys-Test-Mode"] == "dry-run" ? (200, testOK) : (200, #"{"status":"ok","guid":"g","guids":["g"]}"#)
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
            method: request.httpMethod ?? "GET", path: url.path, query: url.query,
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
            VStack {
                Text(UITestBackend.injectionLog.joined(separator: "|"))
                    .font(.system(size: 1)).opacity(0.01)
                    .accessibilityIdentifier("uitest-injections")
                    .accessibilityValue(UITestBackend.injectionLog.joined(separator: "|"))
                Text(UITestBackend.mutationLog.joined(separator: "|"))
                    .font(.system(size: 1)).opacity(0.01)
                    .accessibilityIdentifier("uitest-mutations")
                    .accessibilityValue(UITestBackend.mutationLog.joined(separator: "|"))
                Text(UITestBackend.loginLog.joined(separator: "|"))
                    .font(.system(size: 1)).opacity(0.01)
                    .accessibilityIdentifier("uitest-logins")
                    .accessibilityValue(UITestBackend.loginLog.joined(separator: "|"))
                Text(UITestBackend.supportMailLog.joined(separator: "\n"))
                    .font(.system(size: 1)).opacity(0.01)
                    .accessibilityIdentifier("uitest-support-mail")
                    .accessibilityValue(UITestBackend.supportMailLog.joined(separator: "\n"))
            }
        }
        .allowsHitTesting(false)
    }
}
#endif
