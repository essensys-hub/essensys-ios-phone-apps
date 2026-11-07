//
//  ShutterNameDisclosure.swift
//  Fiche du volet, réservée à l'administrateur (spec shutter-names-clients) : champ « Nom » (1 à 40 caractères,
//  validé avant l'envoi), « Enregistrer » et « Nom d'origine ». Jumeau de LightNameDisclosure.
//  Le nom est du texte brut ; aucun ordre n'est envoyé à l'armoire.
//

import SwiftUI

struct ShutterNameDisclosure: View {
    let id: String
    let defaultName: String
    let names: ShutterNamesModel
    let enabled: Bool
    @State private var expanded = false
    @State private var text = ""
    @State private var error: String?
    @Environment(\.essensys) private var colors

    var body: some View {
        let busy = names.sending.contains(id)
        VStack(alignment: .leading, spacing: 8) {
            Button {
                if !expanded { text = names.customName(id) ?? "" }
                expanded.toggle()
            } label: {
                HStack {
                    Image(systemName: "pencil").foregroundStyle(colors.primary)
                    Text("Nom : \(names.displayName(id: id))").font(.caption).foregroundStyle(colors.text)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down").font(.caption).foregroundStyle(colors.textMuted)
                }
                .frame(minHeight: 36)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("shutter-\(id)-name-toggle")
            if expanded {
                TextField("Nom (1 à 40 caractères)", text: $text, prompt: Text(defaultName))
                    .autocorrectionDisabled()
                    .padding(8)
                    .overlay(RoundedRectangle(cornerRadius: Radius.button).stroke(colors.border))
                    .accessibilityIdentifier("shutter-\(id)-name-field")
                HStack(spacing: 8) {
                    ActionButton(label: "Enregistrer", loading: busy, enabled: enabled && !busy, compact: true) {
                        guard ShutterNameFormat.validate(text) != nil else {
                            error = ShutterNameFormat.invalidMessage
                            return
                        }
                        error = nil
                        Task { _ = await names.rename(id, to: text) }
                    }
                    .accessibilityIdentifier("shutter-\(id)-name-save")
                    ActionButton(label: "Nom d'origine", tone: .secondary, loading: false, enabled: enabled && !busy, compact: true) {
                        error = nil
                        text = ""
                        Task { _ = await names.restoreDefault(id) }
                    }
                    .accessibilityIdentifier("shutter-\(id)-name-reset")
                }
                if let error {
                    Text(error).font(.caption).foregroundStyle(colors.danger)
                        .accessibilityIdentifier("shutter-\(id)-name-error")
                }
            }
        }
    }
}
