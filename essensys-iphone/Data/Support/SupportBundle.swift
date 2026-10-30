//
//  SupportBundle.swift
//  Bundle zip du support (jumeau de SupportBundle.kt) : `resume.txt`, `diagnostics.json`, `journal.jsonl`.
//  Construit par liste blanche (décision C4) ; en dernier rempart, les secrets connus de la session
//  (jeton, cookie LAN) sont masqués partout. Zip produit sans dépendance par NSFileCoordinator (design D3).
//

import Foundation

/// Ce que l'utilisateur envoie : le zip, son résumé lisible et l'objet du message.
struct SupportPackage: Equatable, Sendable {
    let zip: URL
    let summary: String
    let subject: String
}

final class SupportBundle: Sendable {
    static let prefix = "essensys-support-ios-"
    private let directory: URL
    private let store: SessionStore
    private let log: AppLog
    private let timeZone: TimeZone

    init(directory: URL, store: SessionStore, log: AppLog, timeZone: TimeZone = .current) {
        self.directory = directory
        self.store = store
        self.log = log
        self.timeZone = timeZone
    }

    /// Dossier par défaut : tmp/support (vidé par le système, aucun bundle ne s'accumule).
    static func defaultDirectory() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("support") }

    func create(_ report: DiagnosticReport) throws -> SupportPackage {
        let generated = ISO8601DateFormatter().date(from: report.generatedAt) ?? Date()
        let summary = redact(summary(report))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let files: [(String, String)] = [
            ("resume.txt", summary),
            ("diagnostics.json", String(decoding: try encoder.encode(report), as: UTF8.self)),
            ("journal.jsonl", log.jsonLines()),
        ].map { ($0.0, redact($0.1)) }

        let fm = FileManager.default
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        for old in (try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
            where old.lastPathComponent.hasPrefix(Self.prefix) { try? fm.removeItem(at: old) }

        let name = "\(Self.prefix)\(report.appVersion)-\(format(generated, "yyyyMMdd-HHmmss"))"
        let staging = fm.temporaryDirectory.appendingPathComponent("\(UUID().uuidString)/\(name)")
        try fm.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: staging.deletingLastPathComponent()) }
        for (file, text) in files { try Data(text.utf8).write(to: staging.appendingPathComponent(file)) }

        let zip = directory.appendingPathComponent("\(name).zip")
        var coordinationError: NSError?
        var copyError: Error?
        NSFileCoordinator().coordinate(readingItemAt: staging, options: .forUploading, error: &coordinationError) { zipped in
            do { try fm.copyItem(at: zipped, to: zip) } catch { copyError = error }
        }
        if let error = coordinationError ?? copyError { throw error }
        return SupportPackage(zip: zip, summary: summary, subject: "Support Essensys — \(report.appVersion) — \(format(generated, "dd/MM/yyyy HH:mm"))")
    }

    /// Résumé lisible, montré à l'utilisateur avant l'envoi et repris dans le corps du message.
    func summary(_ report: DiagnosticReport) -> String {
        let generated = ISO8601DateFormatter().date(from: report.generatedAt) ?? Date()
        var lines = ["Diagnostic Essensys — iPhone \(report.appVersion) (build \(report.appBuild))",
                     "Généré le \(format(generated, "dd/MM/yyyy HH:mm"))"]
        var groups: [String] = []
        for check in report.checks where !groups.contains(check.group) { groups.append(check.group) }
        for group in groups {
            lines += ["", group]
            lines += report.checks.filter { $0.group == group }.map { "- [\($0.checkStatus.label)] \($0.label) : \($0.detail)" }
        }
        return lines.joined(separator: "\n")
    }

    private func redact(_ text: String) -> String {
        let state = store.state
        return [state.token, state.lanCookie].compactMap { $0 }.filter { $0.count >= 6 }
            .reduce(text) { $0.replacingOccurrences(of: $1, with: "•••") }
    }

    private func format(_ date: Date, _ pattern: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.timeZone = timeZone
        f.dateFormat = pattern
        return f.string(from: date)
    }
}
