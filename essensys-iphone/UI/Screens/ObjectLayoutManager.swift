//
//  ObjectLayoutManager.swift
//  Écran de gestion de l'affichage des lumières ou des volets, réservé à l'administrateur de l'armoire
//  (spec object-layout-clients) : tous les objets du genre, désactivés compris, un interrupteur Activé/Désactivé,
//  Monter/Descendre (échange avec le voisin du même groupe), « Ordre d'origine » et un seul « Enregistrer ».
//  Les modifications restent locales jusqu'à l'enregistrement ; les noms sont rendus en texte brut.
//

import SwiftUI

/// Bouton d'accès, présent seulement pour l'administrateur ; ouvre l'écran de gestion en feuille.
struct ObjectLayoutEntry: View {
    let kind: LayoutKind
    let model: ObjectLayoutModel
    let displayName: (String) -> String
    let enabled: Bool
    @State private var presented = false

    var body: some View {
        ActionButton(label: kind == .lights ? "Gérer l'affichage des lumières" : "Gérer l'affichage des volets",
                     tone: .secondary, enabled: enabled) {
            model.clearFeedback()
            presented = true
        }
        .accessibilityIdentifier("\(kind.rawValue)-layout-open")
        .sheet(isPresented: $presented) {
            ObjectLayoutManager(kind: kind, model: model, displayName: displayName, enabled: enabled)
        }
    }
}

struct ObjectLayoutManager: View {
    let kind: LayoutKind
    let model: ObjectLayoutModel
    let displayName: (String) -> String
    let enabled: Bool
    @State private var draft: ObjectLayoutDraft
    @Environment(\.dismiss) private var dismiss
    @Environment(\.essensys) private var colors

    init(kind: LayoutKind, model: ObjectLayoutModel, displayName: @escaping (String) -> String, enabled: Bool) {
        self.kind = kind
        self.model = model
        self.displayName = displayName
        self.enabled = enabled
        _draft = State(initialValue: ObjectLayoutDraft(kind: kind, layout: model.layout))
    }

    private var sections: [(title: String, group: IndexTable.Group)] {
        kind == .lights
            ? [("Éclairage principal", .main), ("Éclairage indirect", .indirect)]
            : [("Volets", .main), ("Volet Store et Store banne", .special)]
    }

    var body: some View {
        NavigationStack {
            ScreenColumn {
                FeedbackBanner(feedback: model.feedback)
                    .accessibilityIdentifier("layout-\(kind.rawValue)-feedback")
                ForEach(sections, id: \.title) { section in
                    EssensysCard(title: section.title, description: "Activez ou désactivez, puis montez ou descendez") {
                        ForEach(draft.order.filter { kind.group(of: $0) == section.group }, id: \.self) { id in
                            row(id)
                        }
                    }
                }
                HStack(spacing: 8) {
                    ActionButton(label: "Ordre d'origine", tone: .secondary, enabled: !model.saving) {
                        draft.resetToOrigin()
                    }
                    .accessibilityIdentifier("layout-\(kind.rawValue)-reset")
                    ActionButton(label: "Enregistrer", loading: model.saving, enabled: enabled && !model.saving) {
                        Task { if await model.save(draft) { dismiss() } }
                    }
                    .accessibilityIdentifier("layout-\(kind.rawValue)-save")
                }
            }
            .navigationTitle(kind == .lights ? "Affichage des lumières" : "Affichage des volets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }.accessibilityIdentifier("layout-\(kind.rawValue)-close")
                }
            }
        }
    }

    /// Le nom (jusqu'à 40 caractères) passe à la ligne ; l'interrupteur et les deux boutons gardent leur taille.
    private func row(_ id: String) -> some View {
        let on = !draft.isDisabled(id)
        let name = displayName(id)
        return HStack(spacing: 8) {
            Text(verbatim: name)
                .font(.subheadline).foregroundStyle(on ? colors.text : colors.textMuted)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("layout-\(kind.rawValue)-\(id)-name")
            Toggle(isOn: Binding(get: { on }, set: { _ in draft.toggle(id) })) { Text(verbatim: name) }
                .labelsHidden()
                .fixedSize()
                .accessibilityLabel(Text(verbatim: "\(name) : \(on ? "activé" : "désactivé")"))
                .accessibilityIdentifier("layout-\(kind.rawValue)-\(id)-toggle")
            moveButton(id, up: true)
            moveButton(id, up: false)
        }
        .padding(.vertical, 2)
    }

    private func moveButton(_ id: String, up: Bool) -> some View {
        Button {
            draft.move(id, up: up)
        } label: {
            Image(systemName: up ? "chevron.up" : "chevron.down")
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(colors.primary)
        .opacity(draft.canMove(id, up: up) ? 1 : 0.3)
        .disabled(!draft.canMove(id, up: up))
        .accessibilityLabel(up ? "Monter" : "Descendre")
        .accessibilityIdentifier("layout-\(kind.rawValue)-\(id)-\(up ? "up" : "down")")
    }
}
