//
//  SupportDiagnostics.swift
//  Tests de diagnostic du bouton Support, en lecture seule (jumeau de SupportDiagnostics.kt) : seules des
//  requêtes GET (`health`, `session`, `history/latest`, `/health` de la gateway), jamais d'injection.
//  Mêmes identifiants, libellés, statuts et ordre que l'Android (décision C1 de app-support-bundle-2026-10-013).
//

import Foundation
import Network
import UIKit
import os

enum CheckStatus: String, Codable, Sendable {
    case ok, warning, error
    case na = "n/a"

    var label: String {
        switch self {
        case .ok: "OK"
        case .warning: "Attention"
        case .error: "Échec"
        case .na: "Non applicable"
        }
    }
}

struct CheckResult: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let group: String
    let label: String
    let status: String
    let detail: String
    var checkStatus: CheckStatus { CheckStatus(rawValue: status) ?? .na }
}

struct DiagnosticReport: Codable, Equatable, Sendable {
    let platform: String
    var generatedAt: String
    let appVersion: String
    let appBuild: String
    let connectionMode: String
    let checks: [CheckResult]
}

enum NetworkType: String, Sendable {
    case wifi = "Wi-Fi", cellular = "Données mobiles", vpn = "VPN", other = "Autre réseau", none = "Aucun réseau"
}

/// Informations sur le téléphone et l'appli, lues sans permission particulière.
protocol DeviceProbe: Sendable {
    var appVersion: String { get }
    var appBuild: String { get }
    var osVersion: String { get }
    var model: String { get }
    var locale: String { get }
    var timeZone: String { get }
    func networkType() async -> NetworkType
}

struct IPhoneDeviceProbe: DeviceProbe {
    let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    let appBuild = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
    let osVersion = "iOS \(ProcessInfo.processInfo.operatingSystemVersionString)"
    var model: String {
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
    }
    var locale: String { Locale.current.identifier }
    var timeZone: String { TimeZone.current.identifier }

    /// Premier état publié par `NWPathMonitor` (immédiat en pratique ; 2 s au plus).
    func networkType() async -> NetworkType {
        await withCheckedContinuation { continuation in
            let monitor = NWPathMonitor()
            let done = OSAllocatedUnfairLock(initialState: false)
            let finish: @Sendable (NetworkType) -> Void = { type in
                guard done.withLock({ let first = !$0; $0 = true; return first }) else { return }
                monitor.cancel()
                continuation.resume(returning: type)
            }
            monitor.pathUpdateHandler = { path in
                guard path.status == .satisfied else { finish(.none); return }
                if path.usesInterfaceType(.other) && !path.usesInterfaceType(.wifi) && !path.usesInterfaceType(.cellular) { finish(.vpn) }
                else if path.usesInterfaceType(.wifi) { finish(.wifi) }
                else if path.usesInterfaceType(.cellular) { finish(.cellular) }
                else { finish(.other) }
            }
            monitor.start(queue: DispatchQueue(label: "essensys.support.path"))
            DispatchQueue.global().asyncAfter(deadline: .now() + 2) { finish(.other) }
        }
    }
}

/// Valeurs fixes : tests unitaires et backend simulé.
struct StaticDeviceProbe: DeviceProbe {
    var appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    var appBuild = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
    var osVersion = "test"
    var model = "test"
    var locale = "fr_FR"
    var timeZone = "Europe/Paris"
    var network: NetworkType = .wifi
    func networkType() async -> NetworkType { network }
}

final class SupportDiagnostics: Sendable {
    static let latencyTries = 5
    static let slowMs = 1_500.0
    static let maxSkew: TimeInterval = 120

    /// Ordre d'affichage et libellés, identiques sur l'Android.
    static let checks: [(id: String, group: String, label: String)] = [
        ("app", "Appareil", "Appli"),
        ("os", "Appareil", "Système"),
        ("model", "Appareil", "Modèle"),
        ("locale", "Appareil", "Langue et fuseau"),
        ("clock", "Appareil", "Heure du téléphone"),
        ("network", "Réseau", "Connexion"),
        ("dns", "Réseau", "Résolution DNS"),
        ("latency", "Réseau", "Temps de réponse HTTPS"),
        ("tls", "Réseau", "Certificat TLS"),
        ("health", "Portail", "Serveur Essensys"),
        ("session", "Portail", "Session"),
        ("armoire", "Portail", "Armoire associée"),
        ("online", "Portail", "Armoire en ligne"),
        ("last-action", "Portail", "Dernière action"),
        ("lan", "Mode local", "Gateway"),
        ("mode", "Réglages", "Mode de connexion"),
        ("test-mode", "Réglages", "Mode test"),
    ]

    private let store: SessionStore
    private let device: DeviceProbe
    private let cloudSession: URLSession
    private let lanSession: URLSession
    private let resolve: @Sendable (String) -> Int?
    private let totalTimeout: Duration
    private let timeZone: TimeZone

    /// - Parameter resolve: nombre d'adresses du nom, nil si introuvable (getaddrinfo par défaut).
    init(store: SessionStore, device: DeviceProbe, protocolClasses: [AnyClass]? = nil,
         resolve: @escaping @Sendable (String) -> Int? = SupportDiagnostics.getaddrinfoCount,
         totalTimeout: Duration = .seconds(25), timeZone: TimeZone = .current) {
        self.store = store
        self.device = device
        self.resolve = resolve
        self.totalTimeout = totalTimeout
        self.timeZone = timeZone
        // Sessions dédiées, sans journal (les tests ne doivent pas le remplir) et à délai court.
        func configuration() -> URLSessionConfiguration {
            let c = URLSessionConfiguration.ephemeral
            c.timeoutIntervalForRequest = 3
            c.httpShouldSetCookies = false
            if let protocolClasses { c.protocolClasses = protocolClasses }
            return c
        }
        cloudSession = URLSession(configuration: configuration())
        lanSession = protocolClasses == nil
            ? URLSession(configuration: configuration(), delegate: PinnedLanDelegate(store: store), delegateQueue: nil)
            : URLSession(configuration: configuration())
    }

    private final class Results: Sendable {
        private let items = OSAllocatedUnfairLock<[CheckResult]>(initialState: [])
        private let onResult: @Sendable (CheckResult) -> Void
        init(onResult: @escaping @Sendable (CheckResult) -> Void) { self.onResult = onResult }
        func emit(_ id: String, _ status: CheckStatus, _ detail: String) {
            guard let c = SupportDiagnostics.checks.first(where: { $0.id == id }) else { return }
            let r = CheckResult(id: id, group: c.group, label: c.label, status: status.rawValue, detail: detail)
            items.withLock { $0.append(r) }
            onResult(r)
        }
        var all: [CheckResult] { items.withLock { $0 } }
    }

    func run(onResult: @escaping @Sendable (CheckResult) -> Void = { _ in }) async -> DiagnosticReport {
        let state = store.state
        let results = Results(onResult: onResult)
        let emit = results.emit

        emit("app", .ok, "Version \(device.appVersion) (build \(device.appBuild))")
        emit("os", .ok, device.osVersion)
        emit("model", .ok, device.model)
        emit("locale", .ok, "\(device.locale) · \(device.timeZone)")
        emit("mode", .ok, state.mode == .cloud ? "Cloud (\(Self.hostLabel(state.cloudHost)))" : "Réseau local (\(Self.hostLabel(state.lanHost)))")
        if state.testMode { emit("test-mode", .warning, "Mode test actif : les commandes ne sont pas exécutées par l'armoire") }
        else { emit("test-mode", .ok, "Désactivé") }
        let net = await device.networkType()
        if net == .none { emit("network", .error, net.rawValue) }
        else if state.mode == .lan && net != .wifi { emit("network", .warning, "\(net.rawValue) : le mode réseau local demande le Wi-Fi de la maison") }
        else { emit("network", .ok, net.rawValue) }

        let work = Task {
            async let cloud: Void = cloudChecks(state, emit)
            async let lan: Void = lanCheck(state, emit)
            _ = await (cloud, lan)
        }
        let timer = Task { [totalTimeout] in try? await Task.sleep(for: totalTimeout); work.cancel() }
        await work.value
        timer.cancel()
        let done = Set(results.all.map(\.id))
        Self.checks.filter { !done.contains($0.id) }.forEach { emit($0.id, .error, "Délai dépassé") }

        let order = Self.checks.map(\.id)
        let ordered = results.all.sorted { order.firstIndex(of: $0.id)! < order.firstIndex(of: $1.id)! }
        return DiagnosticReport(platform: "ios", generatedAt: ISO8601DateFormatter().string(from: Date()),
                                appVersion: device.appVersion, appBuild: device.appBuild,
                                connectionMode: state.mode.rawValue, checks: ordered)
    }

    private func cloudChecks(_ state: SessionState, _ emit: (String, CheckStatus, String) -> Void) async {
        let base = state.cloudHost.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let host = URL(string: base)?.host ?? base
        let resolve = self.resolve
        let count = await Task.detached { resolve(host) }.value
        if let count { emit("dns", .ok, "\(host) → \(count) adresse(s)") } else { emit("dns", .error, "\(host) : nom introuvable") }

        var tries: [Timed] = []
        for _ in 0..<Self.latencyTries { tries.append(await timedGet(cloudSession, base + "/api/portal/health")) }
        let ok = tries.filter { (200..<300).contains($0.code ?? 0) }
        let firstFailure = tries.first { !(200..<300).contains($0.code ?? 0) }
        if let first = ok.first { emit("health", .ok, "Répond (HTTP \(first.code ?? 0))") }
        else { emit("health", .error, firstFailure?.describe ?? "Pas de réponse") }

        if ok.isEmpty {
            emit("latency", .error, "0/\(Self.latencyTries) réponses : \(firstFailure?.describe ?? "—")")
        } else {
            let ms = ok.map(\.ms)
            let average = Double(ms.reduce(0, +)) / Double(ms.count)
            let detail = "min \(ms.min()!) ms · moyenne \(Int(average)) ms · max \(ms.max()!) ms · \(ok.count)/\(Self.latencyTries) réponses"
            emit("latency", ok.count == Self.latencyTries && average < Self.slowMs ? .ok : .warning, detail)
        }

        if base.hasPrefix("http://") { emit("tls", .na, "Connexion non chiffrée (serveur de test)") }
        else if !ok.isEmpty { emit("tls", .ok, "Certificat valide") }
        else if let tls = tries.first(where: \.isCertificateError) { emit("tls", .error, "Certificat refusé : \(tls.describe)") }
        else { emit("tls", .na, "Non vérifié : serveur injoignable") }

        if let date = ok.compactMap(\.date).first {
            let skew = Int(Date().timeIntervalSince(date).rounded())
            let detail = skew == 0 ? "À l'heure" : "Écart de \(abs(skew)) s \(skew > 0 ? "en avance" : "en retard") sur le serveur"
            emit("clock", Double(abs(skew)) <= Self.maxSkew ? .ok : .warning, detail)
        } else {
            emit("clock", .na, "Heure du serveur inconnue")
        }

        await portalChecks(state, base, emit)
    }

    private func portalChecks(_ state: SessionState, _ base: String, _ emit: (String, CheckStatus, String) -> Void) async {
        let ids = ["session", "armoire", "online", "last-action"]
        guard state.mode == .cloud, let token = state.token else {
            let why = state.mode == .lan ? "Mode réseau local" : "Non connecté"
            ids.forEach { emit($0, .na, why) }
            return
        }
        let auth = ["Authorization": "Bearer \(token)"]
        let s = await timedGet(cloudSession, base + "/api/portal/session", headers: auth)
        guard (200..<300).contains(s.code ?? 0), let session = try? JSONDecoder().decode(PortalSession.self, from: s.body) else {
            emit("session", .error, s.code == 401 ? "Session expirée : reconnectez-vous" : (s.code.map { (200..<300).contains($0) } == true ? "Réponse illisible" : s.describe))
            ids.dropFirst().forEach { emit($0, .na, "Session indisponible") }
            return
        }
        emit("session", .ok, "Session valide" + (session.user?.email.map { " — \($0)" } ?? ""))

        if let armoire = session.armoire {
            let (status, detail) = Self.armoireCheck(armoire, gatewayOnline: session.gateway?.online == true, now: Date(), timeZone: timeZone)
            emit("armoire", status, detail)
        } else {
            emit("armoire", .warning, "Aucune armoire vue par le serveur")
        }
        let gateway = switch session.gateway?.online { case true?: "en ligne"; case false?: "hors ligne"; case nil: session.gateway == nil ? "absente" : "hors ligne" }
        let rule = "gateway \(gateway) · armoire \(session.armoire?.online == true ? "vue" : "non vue") depuis 2 min"
        if session.armoireOnline { emit("online", .ok, "En ligne (\(rule))") } else { emit("online", .error, "Hors ligne (\(rule))") }

        let h = await timedGet(cloudSession, base + "/api/portal/history/latest", headers: auth)
        if !(200..<300).contains(h.code ?? 0) { emit("last-action", .warning, h.describe) }
        else if let action = (try? JSONDecoder().decode(HistoryLatest.self, from: h.body))?.lastAction {
            emit("last-action", .ok, "\(action.actionInfo ?? "—") (\(action.isDone == false ? "en cours" : "terminée"))")
        } else {
            emit("last-action", .ok, "Aucune action récente")
        }
    }

    private func lanCheck(_ state: SessionState, _ emit: (String, CheckStatus, String) -> Void) async {
        guard state.mode == .lan else { emit("lan", .na, "Mode cloud : gateway non testée"); return }
        let r = await timedGet(lanSession, state.lanHost.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/health")
        if (200..<300).contains(r.code ?? 0) { emit("lan", .ok, "Joignable en \(r.ms) ms") } else { emit("lan", .error, r.describe) }
    }

    private struct Timed {
        var code: Int?
        var ms: Int
        var body = Data()
        var date: Date?
        var error: Error?

        var isCertificateError: Bool {
            guard let e = error as? URLError else { return false }
            return [.serverCertificateUntrusted, .serverCertificateHasUnknownRoot, .serverCertificateHasBadDate,
                    .serverCertificateNotYetValid, .secureConnectionFailed].contains(e.code)
        }

        var describe: String {
            guard let error else { return "HTTP \(code ?? 0)" }
            guard let e = error as? URLError else { return String(describing: type(of: error)) }
            switch e.code {
            case .cannotFindHost, .dnsLookupFailed: return "Nom introuvable (DNS)"
            case .timedOut: return "Délai dépassé"
            case .cannotConnectToHost: return "Connexion refusée"
            case .notConnectedToInternet: return "Pas de connexion Internet"
            case .cancelled: return "Délai dépassé"
            default: return isCertificateError ? "Certificat refusé" : "URLError(\(e.code.rawValue))"
            }
        }
    }

    private func timedGet(_ session: URLSession, _ url: String, headers: [String: String] = [:]) async -> Timed {
        let start = ContinuousClock.now
        let elapsed = { Int((ContinuousClock.now - start) / .milliseconds(1)) }
        guard let u = URL(string: url) else { return Timed(code: nil, ms: 0, error: URLError(.badURL)) }
        var request = URLRequest(url: u)
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        do {
            let (data, response) = try await session.data(for: request)
            let http = response as? HTTPURLResponse
            let date = http?.value(forHTTPHeaderField: "Date").flatMap(Self.httpDate)
            return Timed(code: http?.statusCode, ms: elapsed(), body: data, date: date)
        } catch {
            return Timed(code: nil, ms: elapsed(), error: error)
        }
    }

    private static func httpDate(_ text: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "GMT")
        f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return f.date(from: text)
    }

    static let staleAfter: TimeInterval = 24 * 3600

    /// Test « Armoire associée » (#33) : date locale et durée écoulée. « Attention » si la date manque, ou si
    /// elle a plus de 24 h sans gateway en ligne pour assurer le contact. `online` vient du serveur (2 min).
    static func armoireCheck(_ armoire: ArmoireInfo, gatewayOnline: Bool, now: Date, timeZone: TimeZone) -> (CheckStatus, String) {
        let prefix = "Armoire \(armoire.serial ?? "—") · dernier contact"
        guard let seen = armoire.lastSeen.flatMap(parseInstant) else { return (.warning, "\(prefix) inconnu") }
        let age = max(0, now.timeIntervalSince(seen))
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = timeZone
        f.dateFormat = "dd/MM/yyyy HH:mm"
        let detail = "\(prefix) \(f.string(from: seen)) (\(elapsed(age)))"
        if armoire.online == true { return (.ok, detail) }
        if gatewayOnline { return (.ok, "\(detail) · contact assuré par la gateway") }
        return (age > staleAfter ? .warning : .ok, detail)
    }

    /// Libellé identique sur l'Android.
    static func elapsed(_ seconds: TimeInterval) -> String {
        switch seconds {
        case ..<60: "il y a moins d'1 min"
        case ..<3600: "il y a \(Int(seconds / 60)) min"
        case ..<(48 * 3600): "il y a \(Int(seconds / 3600)) h"
        default: "il y a \(Int(seconds / 86_400)) j"
        }
    }

    /// ISO 8601 du serveur, avec ou sans fraction de seconde (jusqu'à la microseconde) et avec `Z` ou un décalage.
    private static func parseInstant(_ raw: String) -> Date? {
        ISO8601DateFormatter().date(from: raw.replacingOccurrences(of: #"\.\d+"#, with: "", options: .regularExpression))
    }

    private static func hostLabel(_ url: String) -> String { URL(string: url)?.host ?? url }

    @Sendable static func getaddrinfoCount(_ host: String) -> Int? {
        var result: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host, nil, nil, &result) == 0, let first = result else { return nil }
        defer { freeaddrinfo(first) }
        var count = 0
        var cursor: UnsafeMutablePointer<addrinfo>? = first
        while let c = cursor { if c.pointee.ai_socktype == SOCK_STREAM || c.pointee.ai_socktype == 0 { count += 1 }; cursor = c.pointee.ai_next }
        return max(count, 1)
    }
}
