//
//  AppLog.swift
//  Journal interne du bouton Support (app-support-bundle-2026-10-013, jumeau de AppLog.kt) : les 500 dernières
//  entrées, écrites en JSON lignes toutes les 50 entrées et à la mise en arrière-plan. Jamais de corps
//  de requête ni d'en-tête : méthode, chemin sans paramètres, code, durée.
//

import Foundation
import os

struct LogEntry: Codable, Equatable, Sendable {
    let t: String
    let kind: String
    let msg: String
    var method: String?
    var path: String?
    var code: Int?
    var ms: Int?
    var error: String?
}

final class AppLog: Sendable {
    static let capacity = 500
    static let flushEvery = 50

    private struct Buffer { var entries: [LogEntry] = []; var unsaved = 0 }
    private let file: URL?
    private let capacity: Int
    private let buffer: OSAllocatedUnfairLock<Buffer>

    /// - Parameter file: nil = journal en mémoire seulement (tests).
    init(file: URL? = nil, capacity: Int = AppLog.capacity) {
        self.file = file
        self.capacity = capacity
        var initial = Buffer()
        if let file, let text = try? String(contentsOf: file, encoding: .utf8) {
            let decoder = JSONDecoder()
            initial.entries = text.split(separator: "\n")
                .compactMap { try? decoder.decode(LogEntry.self, from: Data($0.utf8)) }
                .suffix(capacity)
        }
        buffer = OSAllocatedUnfairLock(initialState: initial)
    }

    /// Fichier par défaut : Application Support/support/journal.jsonl.
    static func defaultFile() -> URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("support/journal.jsonl")
    }

    func http(method: String, path: String, code: Int?, ms: Int, error: String? = nil) {
        add(LogEntry(t: Self.now(), kind: "http", msg: "\(method) \(path)", method: method, path: path, code: code, ms: ms, error: error))
    }

    func event(_ kind: String, _ msg: String) { add(LogEntry(t: Self.now(), kind: kind, msg: msg)) }

    var snapshot: [LogEntry] { buffer.withLock { $0.entries } }

    func jsonLines() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return snapshot.compactMap { try? encoder.encode($0) }.map { String(decoding: $0, as: UTF8.self) }.joined(separator: "\n")
    }

    func flush() {
        guard let file else { return }
        let text = jsonLines()
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        if (try? text.write(to: file, atomically: true, encoding: .utf8)) != nil {
            buffer.withLock { $0.unsaved = 0 }
        }
    }

    private func add(_ entry: LogEntry) {
        let save = buffer.withLock { b -> Bool in
            b.entries.append(entry)
            if b.entries.count > capacity { b.entries.removeFirst(b.entries.count - capacity) }
            b.unsaved += 1
            return b.unsaved >= Self.flushEvery
        }
        if save { flush() }
    }

    private static func now() -> String { ISO8601DateFormatter().string(from: Date()) }
}
