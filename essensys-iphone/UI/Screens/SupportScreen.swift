//
//  SupportScreen.swift
//  Bouton Support (app-support-bundle-2026-10-013, jumeau de SupportScreen.kt) : tests au fil de l'eau,
//  résumé, puis composeur Mail (repli : feuille de partage). Rien n'est envoyé sans l'utilisateur.
//

import MessageUI
import SwiftUI

/// Paramètres du message, testés sans présenter le composeur (design D4, D6).
enum SupportMail {
    static var address: String {
        Bundle.main.object(forInfoDictionaryKey: "EssensysSupportEmail") as? String ?? "support_essensys@rhinosys.fr"
    }

    struct Parameters: Equatable {
        let recipients: [String]
        let subject: String
        let body: String
        let mimeType: String
        let fileName: String
    }

    static func parameters(_ pkg: SupportPackage) -> Parameters {
        Parameters(recipients: [address], subject: pkg.subject, body: pkg.summary,
                   mimeType: "application/zip", fileName: pkg.zip.lastPathComponent)
    }
}

@MainActor @Observable
final class SupportModel {
    private(set) var results: [CheckResult] = []
    private(set) var running = false
    private(set) var ready: SupportPackage?
    private(set) var error: String?
    private let diagnostics: SupportDiagnostics
    private let bundle: SupportBundle
    private let log: AppLog

    init(container: AppContainer) {
        diagnostics = container.supportDiagnostics
        bundle = container.supportBundle
        log = container.appLog
    }

    func run() async {
        guard !running else { return }
        running = true
        results = []
        ready = nil
        error = nil
        log.event("support", "Diagnostic lancé")
        let report = await diagnostics.run { result in Task { @MainActor [weak self] in self?.append(result) } }
        results = report.checks
        do { ready = try bundle.create(report) } catch { self.error = "Impossible de préparer le fichier : \(error.localizedDescription)" }
        running = false
    }

    private func append(_ result: CheckResult) {
        if running, !results.contains(where: { $0.id == result.id }) { results.append(result) }
    }

    func sent() { log.event("support", "Bundle transmis à l'appli email") }
}

struct SupportScreen: View {
    let model: SupportModel
    var onClose: () -> Void
    @State private var showMail = false
    @State private var showShare = false
    @Environment(\.essensys) private var colors

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Support").font(.title2.weight(.semibold)).foregroundStyle(colors.text)
                Spacer()
                Button("Fermer", action: onClose).accessibilityIdentifier("support-close")
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(colors.card)
            ScreenColumn {
                EssensysCard(title: "Diagnostic", description: "Tests en lecture seule depuis ce téléphone : aucune commande n'est envoyée à l'armoire.") {
                    if model.running { Text("Tests en cours…").foregroundStyle(colors.textMuted).accessibilityIdentifier("support-running") }
                    ForEach(groups, id: \.self) { group in
                        Text(group).font(.subheadline.weight(.semibold)).foregroundStyle(colors.text)
                        ForEach(model.results.filter { $0.group == group }) { CheckRow(check: $0) }
                    }
                }
                if let error = model.error { FeedbackBanner(feedback: Feedback(text: error, kind: .error)) }
                if let pkg = model.ready {
                    EssensysCard(title: "Envoyer au support", description: "Votre appli email s'ouvre avec ce résumé et le fichier joint. Vous pouvez le relire avant d'envoyer.") {
                        Text("Destinataire : \(SupportMail.address)").foregroundStyle(colors.text)
                        Text(pkg.zip.lastPathComponent).font(.caption).foregroundStyle(colors.textMuted).accessibilityIdentifier("support-zip")
                        ActionButton(label: "Envoyer au support") { send(pkg) }.accessibilityIdentifier("support-send")
                        ActionButton(label: "Relancer les tests", tone: .secondary) { Task { await model.run() } }
                            .accessibilityIdentifier("support-rerun")
                    }
                }
            }
        }
        .background(colors.background)
        .task { if model.results.isEmpty && !model.running { await model.run() } }
        .sheet(isPresented: $showMail) { if let pkg = model.ready { MailComposer(pkg: pkg).ignoresSafeArea() } }
        .sheet(isPresented: $showShare) { if let pkg = model.ready { ShareSheet(items: [pkg.summary, pkg.zip]) } }
    }

    private var groups: [String] {
        var seen: [String] = []
        for r in model.results where !seen.contains(r.group) { seen.append(r.group) }
        return seen
    }

    private func send(_ pkg: SupportPackage) {
        model.sent()
        #if DEBUG
        if UITestBackend.isEnabled { UITestBackend.recordSupportMail(SupportMail.parameters(pkg)); return }
        #endif
        if MFMailComposeViewController.canSendMail() { showMail = true } else { showShare = true }
    }
}

private struct CheckRow: View {
    let check: CheckResult
    @Environment(\.essensys) private var colors

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(check.checkStatus.label).font(.caption.weight(.semibold)).foregroundStyle(color)
                .accessibilityIdentifier("check-\(check.id)-status")
            VStack(alignment: .leading, spacing: 2) {
                Text(check.label).foregroundStyle(colors.text)
                Text(check.detail).font(.caption).foregroundStyle(colors.textMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var color: Color {
        switch check.checkStatus {
        case .ok: colors.success
        case .warning: colors.warning
        case .error: colors.danger
        case .na: colors.textMuted
        }
    }
}

private struct MailComposer: UIViewControllerRepresentable {
    let pkg: SupportPackage
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(dismiss: dismiss) }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let p = SupportMail.parameters(pkg)
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setToRecipients(p.recipients)
        vc.setSubject(p.subject)
        vc.setMessageBody(p.body, isHTML: false)
        if let data = try? Data(contentsOf: pkg.zip) { vc.addAttachmentData(data, mimeType: p.mimeType, fileName: p.fileName) }
        return vc
    }

    func updateUIViewController(_ vc: MFMailComposeViewController, context: Context) {}

    // MessageUI appelle son délégué sur le fil principal.
    @MainActor final class Coordinator: NSObject, @preconcurrency MFMailComposeViewControllerDelegate {
        let dismiss: DismissAction
        init(dismiss: DismissAction) { self.dismiss = dismiss }
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            dismiss()
        }
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
