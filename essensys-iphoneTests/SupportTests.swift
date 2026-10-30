import Compression
import Foundation
import Testing
@testable import essensys_iphone

/// Bouton Support (app-support-bundle-2026-10-013) : journal, diagnostics et bundle, contre le backend simulé.
/// Mêmes cas que AppLogTest.kt, SupportDiagnosticsTest.kt et SupportBundleTest.kt (Android).
@Suite struct SupportTests {

    // MARK: Backend simulé routé par chemin (cloud et LAN interrogés en parallèle)

    struct Routes: Sendable {
        var health = 200
        var session = 200
        var sessionJSON = #"{"user":{"email":"demo@essensys.fr"},"portal_access":true,"gateway":{"online":false},"armoire":{"no_serie":"SC944D-0001","last_seen":"2026-10-30T10:00:00Z","online":true}}"#
        var lanHealth = 200
    }

    /// Garde les backends en vie : `TestBackend` désenregistre son hôte à sa libération, et ARC peut la libérer
    /// dès le dernier usage de `t`, avant la fin du test.
    private final class Keeper: @unchecked Sendable {
        private let lock = NSLock()
        private var items: [AnyObject] = []
        func keep(_ o: AnyObject) { lock.withLock { items.append(o) } }
    }
    private static let alive = Keeper()

    private static func make(_ state: (inout SessionState) -> Void = { _ in }, routes: Routes = Routes(),
                             network: NetworkType = .wifi, directory: URL? = nil) -> (TestBackend, AppContainer) {
        let t = TestBackend(token: "jwt")
        alive.keep(t)
        t.store.update(state)
        t.route { r in
            let headers = ["Content-Type": "application/json", "Date": Self.httpDate()]
            switch r.path {
            case "/api/portal/health": return MockReply(status: routes.health, body: #"{"status":"ok"}"#, headers: headers)
            case "/api/portal/session": return MockReply(status: routes.session, body: routes.session == 200 ? routes.sessionJSON : #"{"error":"unauthorized"}"#, headers: headers)
            case "/api/portal/history/latest": return MockReply(body: #"{"lastAction":{"actionInfo":"Lumière salon","isDone":true}}"#, headers: headers)
            case "/health": return MockReply(status: routes.lanHealth, body: #"{"status":"ok"}"#, headers: headers)
            default: return MockReply(status: 404, body: "{}", headers: headers)
            }
        }
        let dir = directory ?? FileManager.default.temporaryDirectory.appendingPathComponent("support-\(UUID().uuidString)")
        let container = AppContainer(store: t.store, guardNoArmoire: true, protocolClasses: [MockURLProtocol.self],
                                     device: StaticDeviceProbe(network: network), supportDirectory: dir, resolve: { _ in 1 })
        return (t, container)
    }

    private static func httpDate() -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = TimeZone(identifier: "GMT")
        f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"; return f.string(from: Date())
    }

    private func status(_ r: DiagnosticReport, _ id: String) -> CheckStatus { r.checks.first { $0.id == id }!.checkStatus }
    private func detail(_ r: DiagnosticReport, _ id: String) -> String { r.checks.first { $0.id == id }!.detail }

    // MARK: Journal (tâche 1.1)

    @Test func ring_keeps_only_the_last_entries() {
        let log = AppLog(capacity: 3)
        for i in 0..<5 { log.event("test", "e\(i)") }
        #expect(log.snapshot.map(\.msg) == ["e2", "e3", "e4"])
    }

    @Test func journal_is_reloaded_after_restart() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString)/journal.jsonl")
        let log = AppLog(file: file)
        log.event("app", "avant")
        log.http(method: "GET", path: "/api/portal/session", code: 200, ms: 42)
        log.flush()
        let reloaded = AppLog(file: file)
        #expect(reloaded.snapshot.map(\.msg) == ["avant", "GET /api/portal/session"])
        #expect(reloaded.snapshot.last?.ms == 42)
    }

    @Test func journal_is_written_every_fifty_entries() {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString)/journal.jsonl")
        let log = AppLog(file: file)
        for i in 0..<49 { log.event("test", "e\(i)") }
        #expect(!FileManager.default.fileExists(atPath: file.path))
        log.event("test", "e49")
        #expect((try? String(contentsOf: file, encoding: .utf8))?.split(separator: "\n").count == 50)
    }

    @Test func requests_are_logged_without_headers_body_or_query() async {
        let (_, c) = Self.make { $0.token = "jwt-secret-token" }
        _ = await c.api.send("POST", "/api/auth/login?debug=1", body: ["email": "demo@essensys.fr", "password": "mot-de-passe-fictif"])
        let entry = c.appLog.snapshot.last
        #expect(entry?.msg == "POST /api/auth/login")
        #expect(entry?.code == 404)
        let text = c.appLog.jsonLines()
        for secret in ["jwt-secret-token", "mot-de-passe-fictif", "debug=1", "Authorization"] { #expect(!text.contains(secret), "\(secret)") }
    }

    // MARK: Diagnostics (tâche 1.2)

    @Test func cloud_all_good_reports_every_check_in_order() async {
        let (_, c) = Self.make()
        let r = await c.supportDiagnostics.run()
        #expect(r.checks.map(\.id) == SupportDiagnostics.checks.map(\.id))
        #expect(r.platform == "ios")
        #expect(r.checks.allSatisfy { $0.checkStatus != .error }, "\(r.checks.filter { $0.checkStatus == .error })")
        #expect(status(r, "online") == .ok)
        #expect(detail(r, "online").contains("gateway hors ligne · armoire vue"))
        #expect(detail(r, "session").contains("demo@essensys.fr"))
        #expect(detail(r, "last-action").contains("Lumière salon"))
        #expect(detail(r, "latency").contains("5/5 réponses"))
        #expect(status(r, "lan") == .na)
    }

    @Test func diagnostics_never_send_a_command() async {
        let (t, c) = Self.make()
        _ = await c.supportDiagnostics.run()
        #expect(t.requests.allSatisfy { $0.method == "GET" })
        #expect(!t.requests.contains { $0.path.contains("inject") || $0.path.contains("web/actions") })
    }

    @Test func test_mode_is_a_warning() async {
        let (_, c) = Self.make { $0.testMode = true }
        let r = await c.supportDiagnostics.run()
        #expect(status(r, "test-mode") == .warning)
        #expect(detail(r, "test-mode").contains("Mode test actif"))
    }

    @Test func unreachable_portal_fails_network_checks_but_keeps_device_ones() async {
        let (t, c) = Self.make()
        MockURLProtocol.unregister(host: t.host)
        let r = await c.supportDiagnostics.run()
        #expect(status(r, "health") == .error)
        #expect(status(r, "latency") == .error)
        #expect(detail(r, "health").contains("Connexion refusée"))
        for id in ["app", "os", "model", "locale", "mode", "test-mode"] { #expect(status(r, id) == .ok, "\(id)") }
    }

    @Test func expired_session_is_reported() async {
        let (_, c) = Self.make(routes: Routes(session: 401))
        let r = await c.supportDiagnostics.run()
        #expect(status(r, "session") == .error)
        #expect(detail(r, "session") == "Session expirée : reconnectez-vous")
        #expect(status(r, "online") == .na)
    }

    @Test func not_logged_in_skips_portal_checks() async {
        let (t, c) = Self.make { $0.token = nil }
        let r = await c.supportDiagnostics.run()
        for id in ["session", "armoire", "online", "last-action"] { #expect(status(r, id) == .na, "\(id)") }
        #expect(status(r, "health") == .ok)
        #expect(!t.requests.contains { $0.path == "/api/portal/session" })
    }

    @Test func offline_armoire_is_an_error_with_the_rule() async {
        var routes = Routes()
        routes.sessionJSON = #"{"user":{},"portal_access":true,"armoire":{"no_serie":"X","last_seen":"2026-10-29T10:00:00Z","online":false}}"#
        let (_, c) = Self.make(routes: routes)
        let r = await c.supportDiagnostics.run()
        #expect(status(r, "online") == .error)
        #expect(detail(r, "online").contains("gateway absente · armoire non vue"))
    }

    @Test func lan_gateway_reachable_or_not() async {
        let (_, ok) = Self.make { $0.mode = .lan; $0.lanCookie = "c" }
        let r = await ok.supportDiagnostics.run()
        #expect(status(r, "lan") == .ok)
        #expect(status(r, "session") == .na)
        let (_, down) = Self.make({ $0.mode = .lan; $0.lanCookie = "c" }, routes: Routes(lanHealth: 502))
        #expect(status(await down.supportDiagnostics.run(), "lan") == .error)
    }

    @Test func lan_mode_on_mobile_data_is_a_warning() async {
        let (_, c) = Self.make({ $0.mode = .lan; $0.lanCookie = "c" }, network: .cellular)
        let r = await c.supportDiagnostics.run()
        #expect(status(r, "network") == .warning)
        #expect(detail(r, "network").hasPrefix("Données mobiles"))
    }

    // MARK: Dernier contact de l'armoire (tâche 4.1, #33)

    private static let now = ISO8601DateFormatter().date(from: "2026-10-30T14:00:00Z")!
    private static let paris = TimeZone(identifier: "Europe/Paris")!
    private func rule(_ lastSeen: String?, online: Bool = false, gateway: Bool = false) -> (CheckStatus, String) {
        SupportDiagnostics.armoireCheck(ArmoireInfo(serial: "SC944D-0001", lastSeen: lastSeen, online: online),
                                        gatewayOnline: gateway, now: Self.now, timeZone: Self.paris)
    }

    @Test func armoire_last_seen_is_local_with_elapsed_time() {
        let (status, detail) = rule("2026-10-30T13:59:30Z", online: true)
        #expect(status == .ok)
        #expect(detail == "Armoire SC944D-0001 · dernier contact 30/10/2026 14:59 (il y a moins d'1 min)")
    }

    @Test func armoire_last_seen_rule_follows_gateway_and_age() {
        let old = "2026-01-22T21:53:02.966462Z"
        let behindGateway = rule(old, gateway: true)
        #expect(behindGateway.0 == .ok)
        #expect(behindGateway.1 == "Armoire SC944D-0001 · dernier contact 22/01/2026 22:53 (il y a 280 j) · contact assuré par la gateway")
        let alone = rule(old)
        #expect(alone.0 == .warning)
        #expect(alone.1 == "Armoire SC944D-0001 · dernier contact 22/01/2026 22:53 (il y a 280 j)")
        #expect(rule("2026-10-30T09:00:00Z").0 == .ok)
        #expect(rule("2026-10-29T13:00:00Z").0 == .warning)
        #expect(rule("2026-10-29T13:00:00+00:00", online: true).0 == .ok)
    }

    @Test func armoire_last_seen_unknown_is_a_warning() {
        let unknown = rule(nil, online: true)
        #expect(unknown.0 == .warning)
        #expect(unknown.1 == "Armoire SC944D-0001 · dernier contact inconnu")
        #expect(rule("hier").0 == .warning)
    }

    @Test func elapsed_labels_match_the_android() {
        #expect(SupportDiagnostics.elapsed(59) == "il y a moins d'1 min")
        #expect(SupportDiagnostics.elapsed(3 * 60) == "il y a 3 min")
        #expect(SupportDiagnostics.elapsed(5 * 3600) == "il y a 5 h")
        #expect(SupportDiagnostics.elapsed(47 * 3600) == "il y a 47 h")
        #expect(SupportDiagnostics.elapsed(48 * 3600) == "il y a 2 j")
    }

    // NR: NR-ios-21 essensys-hub/essensys-ios-phone-apps#33
    // Une armoire vue il y a 9 mois ne doit plus être « OK » sans explication.
    @Test func stale_armoire_last_seen_NR_ios_21() async {
        let seen = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-281 * 86_400))
        func routes(gateway: Bool) -> Routes {
            var r = Routes()
            r.sessionJSON = #"{"user":{},"portal_access":true,"gateway":{"online":\#(gateway)},"armoire":{"no_serie":"X","last_seen":"\#(seen)","online":false}}"#
            return r
        }
        let (_, withGateway) = Self.make(routes: routes(gateway: true))
        let a = await withGateway.supportDiagnostics.run()
        #expect(status(a, "armoire") == .ok)
        #expect(detail(a, "armoire").hasSuffix("(il y a 281 j) · contact assuré par la gateway"), "\(detail(a, "armoire"))")
        let (_, alone) = Self.make(routes: routes(gateway: false))
        let b = await alone.supportDiagnostics.run()
        #expect(status(b, "armoire") == .warning)
        #expect(detail(b, "armoire").hasSuffix("(il y a 281 j)"), "\(detail(b, "armoire"))")
    }

    // MARK: Bundle (tâche 2.1)

    /// Lecteur zip minimal (répertoire central, entrées stockées ou deflate) : pas d'outil d'extraction sur iOS.
    private func unzip(_ zip: URL) throws -> [String: String] {
        let d = try Data(contentsOf: zip)
        func u16(_ o: Int) -> Int { Int(d[o]) | Int(d[o + 1]) << 8 }
        func u32(_ o: Int) -> Int { u16(o) | u16(o + 2) << 16 }
        guard let eocd = stride(from: d.count - 22, through: 0, by: -1).first(where: { u32($0) == 0x06054b50 }) else { return [:] }
        var files: [String: String] = [:]
        var p = u32(eocd + 16)
        for _ in 0..<u16(eocd + 10) {
            let method = u16(p + 10), size = u32(p + 20), raw = u32(p + 24)
            let nameLength = u16(p + 28), extra = u16(p + 30), comment = u16(p + 32), local = u32(p + 42)
            let name = String(decoding: d[(p + 46)..<(p + 46 + nameLength)], as: UTF8.self)
            let start = local + 30 + u16(local + 26) + u16(local + 28)
            let payload = Data(d[start..<(start + size)])
            var content = payload
            if method == 8 {
                var out = Data(count: max(raw, 1))
                let n = out.withUnsafeMutableBytes { dst in payload.withUnsafeBytes { src in
                    compression_decode_buffer(dst.bindMemory(to: UInt8.self).baseAddress!, raw,
                                              src.bindMemory(to: UInt8.self).baseAddress!, size, nil, COMPRESSION_ZLIB)
                } }
                content = out.prefix(n)
            }
            if !name.hasSuffix("/") { files[(name as NSString).lastPathComponent] = String(decoding: content, as: UTF8.self) }
            p += 46 + nameLength + extra + comment
        }
        return files
    }

    @Test func zip_holds_summary_diagnostics_and_journal() async throws {
        let (_, c) = Self.make { $0.testMode = true }
        c.appLog.event("session", "Connecté (cloud)")
        var report = await c.supportDiagnostics.run()
        report.generatedAt = "2026-10-30T10:15:30Z"
        let bundle = SupportBundle(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString),
                                   store: c.store, log: c.appLog, timeZone: TimeZone(identifier: "Europe/Paris")!)
        let pkg = try bundle.create(report)
        #expect(pkg.zip.lastPathComponent == "essensys-support-ios-\(report.appVersion)-20261030-111530.zip")
        #expect(pkg.subject == "Support Essensys — \(report.appVersion) — 30/10/2026 11:15")
        let files = try unzip(pkg.zip)
        #expect(Set(files.keys) == ["resume.txt", "diagnostics.json", "journal.jsonl"])
        #expect(files["resume.txt"]?.contains("[Attention] Mode test : Mode test actif") == true)
        #expect(files["diagnostics.json"]?.contains(#""platform" : "ios""#) == true)
        #expect(files["journal.jsonl"]?.contains("Connecté (cloud)") == true)
        #expect(files["resume.txt"] == pkg.summary)
    }

    @Test func a_new_bundle_replaces_the_previous_one() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let (_, c) = Self.make(directory: dir)
        var report = await c.supportDiagnostics.run()
        report.generatedAt = "2026-10-30T10:00:00Z"
        _ = try c.supportBundle.create(report)
        report.generatedAt = "2026-10-30T10:05:00Z"
        let second = try c.supportBundle.create(report)
        #expect(try FileManager.default.contentsOfDirectory(atPath: dir.path) == [second.zip.lastPathComponent])
    }

    @Test func email_parameters_target_support_with_the_zip() {
        let pkg = SupportPackage(zip: URL(fileURLWithPath: "/tmp/essensys-support-ios-test.zip"), summary: "Résumé", subject: "Support Essensys — test")
        let p = SupportMail.parameters(pkg)
        #expect(p == SupportMail.Parameters(recipients: ["support_essensys@rhinosys.fr"], subject: "Support Essensys — test",
                                            body: "Résumé", mimeType: "application/zip", fileName: "essensys-support-ios-test.zip"))
    }

    // NR: NR-ios-20 essensys-hub/essensys-ios-phone-apps#29
    // Le bundle part par email : aucun secret de session ni saisi par l'utilisateur ne doit s'y trouver.
    @Test func bundle_contains_no_secret_NR_ios_20() async throws {
        let token = "jwt-SECRET-token-0123456789"
        let cookie = "lan-SECRET-cookie-abcdef"
        let password = "mot-de-passe-fictif!"
        let accessKey = "73195624081357924680135792468013"
        let alarmCode = "4826"
        let (_, c) = Self.make { $0.token = token; $0.lanCookie = cookie }
        _ = await c.api.send("POST", "/api/auth/login", body: ["email": "demo@essensys.fr", "password": password])
        _ = await c.api.send("POST", "/api/portal/web/actions", body: ["alarme": "on", "codealarme": alarmCode])
        _ = await c.api.send("PUT", "/api/portal/remote-key", body: ["key": accessKey])
        c.appLog.event("session", "Connecté (cloud)")
        let report = await c.supportDiagnostics.run()
        let files = try unzip(try c.supportBundle.create(report).zip)
        #expect(files["journal.jsonl"]?.contains("POST /api/auth/login") == true)
        for (name, text) in files {
            for secret in [token, cookie, password, accessKey, alarmCode, "Authorization", "Cookie"] {
                #expect(!text.contains(secret), "\(secret) dans \(name)")
            }
        }
    }
}
