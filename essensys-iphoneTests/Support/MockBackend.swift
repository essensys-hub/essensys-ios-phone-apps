//
//  MockBackend.swift
//  Backend simulé par URLProtocol (jumeau de TestServer.kt / MockWebServer). Chaque test enregistre
//  un hôte unique `<uuid>.essensys.test` : les tests peuvent tourner en parallèle sans interférer.
//

import Foundation
@testable import essensys_iphone

struct MockReply: Sendable {
    var status = 200
    var body = ""
    var headers: [String: String] = ["Content-Type": "application/json"]
}

struct RecordedRequest: Sendable {
    let method: String
    let path: String
    let query: String?
    let headers: [String: String]
    let body: String
}

final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var handlers: [String: @Sendable (RecordedRequest) -> MockReply] = [:]
    nonisolated(unsafe) private static var log: [String: [RecordedRequest]] = [:]

    static func register(host: String, handler: @escaping @Sendable (RecordedRequest) -> MockReply) {
        lock.withLock { handlers[host] = handler; log[host] = [] }
    }
    static func requests(host: String) -> [RecordedRequest] { lock.withLock { log[host] ?? [] } }
    static func unregister(host: String) { lock.withLock { handlers[host] = nil; log[host] = nil } }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let url = request.url!
        let host = url.host ?? ""
        let recorded = RecordedRequest(
            method: request.httpMethod ?? "GET", path: url.path, query: url.query,
            headers: request.allHTTPHeaderFields ?? [:], body: Self.bodyString(request))
        let handler = Self.lock.withLock { () -> (@Sendable (RecordedRequest) -> MockReply)? in
            Self.log[host, default: []].append(recorded)
            return Self.handlers[host]
        }
        guard let handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.cannotConnectToHost)); return
        }
        let reply = handler(recorded)
        let response = HTTPURLResponse(url: url, statusCode: reply.status, httpVersion: "HTTP/1.1", headerFields: reply.headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(reply.body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func bodyString(_ request: URLRequest) -> String {
        if let body = request.httpBody { return String(decoding: body, as: UTF8.self) }
        guard let stream = request.httpBodyStream else { return "" }
        stream.open(); defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: buffer.count)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return String(decoding: data, as: UTF8.self)
    }
}

/// Backend simulé + conteneur câblé dessus, garde no-armoire active (spec ios-quality).
final class TestBackend {
    let host = "\(UUID().uuidString.lowercased()).essensys.test"
    let store: SessionStore
    let container: AppContainer
    private var replies: [MockReply] = []
    private let queue = ReplyQueue()

    init(mode: ConnectionMode = .cloud, token: String? = nil, testMode: Bool = false) {
        var state = SessionState()
        state.mode = mode
        state.cloudHost = "https://\(host)"
        state.lanHost = "https://\(host)"
        state.token = token
        state.testMode = testMode
        store = SessionStore(persistence: InMemoryPersistence(initial: state))
        container = AppContainer(store: store, guardNoArmoire: true, protocolClasses: [MockURLProtocol.self])
        let queue = self.queue
        MockURLProtocol.register(host: host) { _ in queue.next() }
    }

    deinit { MockURLProtocol.unregister(host: host) }

    /// Réponses servies dans l'ordre (comme MockWebServer.enqueue).
    func enqueue(_ status: Int, _ body: String = "", headers: [String: String] = ["Content-Type": "application/json"]) {
        queue.push(MockReply(status: status, body: body, headers: headers))
    }

    /// Routage par chemin (comme un Dispatcher MockWebServer).
    func route(_ handler: @escaping @Sendable (RecordedRequest) -> MockReply) {
        MockURLProtocol.register(host: host, handler: handler)
    }

    var requests: [RecordedRequest] { MockURLProtocol.requests(host: host) }

    static func fixture(_ name: String) -> String {
        let url = Bundle(for: BundleToken.self).url(forResource: name, withExtension: "json")!
        return try! String(contentsOf: url, encoding: .utf8)
    }
}

final class BundleToken {}

final class ReplyQueue: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [MockReply] = []
    func push(_ reply: MockReply) { lock.withLock { items.append(reply) } }
    func next() -> MockReply {
        lock.withLock { items.isEmpty ? MockReply(status: 500, body: "queue vide") : items.removeFirst() }
    }
}
