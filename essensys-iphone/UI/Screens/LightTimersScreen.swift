//
//  LightTimersScreen.swift
//  Temporisations d'extinction des six lumières (spec light-timers-clients) : menu « Temporisations » et
//  même réglage dans la ligne de chaque lumière concernée. Réservé à l'administrateur de l'armoire.
//

import SwiftUI

/// Menu central : les six lumières avec leur délai courant. Masqué (tuile absente) si !isAdmin.
struct LightTimersScreen: View {
    let model: LightTimersModel
    let enabled: Bool
    let isAdmin: Bool
    @Environment(\.essensys) private var colors

    var body: some View {
        ScreenColumn {
            FeedbackBanner(feedback: model.feedback)
            if !isAdmin {
                EssensysCard(title: "Temporisations") {
                    Text("Réservé à l'administrateur de l'armoire.")
                        .foregroundStyle(colors.textMuted).accessibilityIdentifier("timers-forbidden")
                }
            } else {
                EssensysCard(title: "Temporisations", description: "Délai avant l'extinction automatique de chaque lumière") {
                    if !enabled {
                        Text("Armoire hors ligne : réglages indisponibles.")
                            .foregroundStyle(colors.textMuted).accessibilityIdentifier("timers-offline")
                    }
                    ForEach(IndexTable.lightTimers) { timer in
                        VStack(alignment: .leading, spacing: 8) {
                            LightTimerHeader(id: timer.id, name: timer.name, model: model, context: "menu")
                            LightTimerControl(id: timer.id, model: model, enabled: enabled, context: "menu")
                        }
                        .padding(.vertical, 4)
                    }
                    Text("Une valeur libre (par exemple 7 min) n'apparaît pas sur l'écran de l'armoire.")
                        .font(.caption).foregroundStyle(colors.textMuted)
                }
            }
        }
        .task(id: isAdmin) { if isAdmin { await model.load() } }
    }
}

private struct LightTimerHeader: View {
    let id: String
    let name: String
    let model: LightTimersModel
    let context: String
    @Environment(\.essensys) private var colors

    var body: some View {
        HStack {
            Text(name).font(.subheadline.weight(.semibold)).foregroundStyle(colors.text)
            Spacer()
            let waiting = model.waiting.contains(id)
            Text(waiting ? "En attente de l'armoire…" : model.state(id)?.display ?? (model.loaded ? "Inconnue" : "…"))
                .font(.subheadline).foregroundStyle(waiting ? colors.warning : colors.textMuted)
                .accessibilityIdentifier("timer-\(context)-\(id)-current")
        }
    }
}

/// Ligne repliable sous une lumière : « Temporisation : 15 min » puis le même réglage.
struct LightTimerDisclosure: View {
    let id: String
    let model: LightTimersModel
    let enabled: Bool
    @State private var expanded = false
    @Environment(\.essensys) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                expanded.toggle()
            } label: {
                HStack {
                    Image(systemName: "timer").foregroundStyle(colors.primary)
                    Text("Temporisation : \(model.state(id)?.display ?? "…")")
                        .font(.caption).foregroundStyle(colors.text)
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down").font(.caption).foregroundStyle(colors.textMuted)
                }
                .frame(minHeight: 36)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("light-\(id)-timer-toggle")
            if expanded {
                LightTimerControl(id: id, model: model, enabled: enabled, context: "light")
            }
        }
    }
}

/// Raccourcis 15 min, 30 min, 1 h, Jamais, plus une valeur libre de 1 à 255 minutes (refusée avant l'envoi sinon).
struct LightTimerControl: View {
    let id: String
    let model: LightTimersModel
    let enabled: Bool
    let context: String
    @State private var text = ""
    @State private var error: String?
    @Environment(\.essensys) private var colors

    var body: some View {
        let current = model.state(id)?.minutes
        let idle = enabled && !model.sending.contains(id)
        VStack(alignment: .leading, spacing: 8) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                ForEach(LightTimerFormat.shortcuts, id: \.minutes) { shortcut in
                    ActionButton(label: shortcut.label, tone: current == shortcut.minutes ? .primary : .secondary,
                                 loading: false, enabled: idle, compact: true) {
                        error = nil
                        model.set(id, minutes: shortcut.minutes)
                    }
                    .accessibilityIdentifier("timer-\(context)-\(id)-\(shortcut.minutes)")
                }
            }
            HStack(spacing: 8) {
                TextField("Autre (1 à 255 min)", text: Binding(get: { text }, set: { text = String($0.filter(\.isNumber).prefix(3)) }))
                    .keyboardType(.numberPad)
                    .padding(8)
                    .overlay(RoundedRectangle(cornerRadius: Radius.button).stroke(colors.border))
                    .accessibilityIdentifier("timer-\(context)-\(id)-field")
                ActionButton(label: "Valider", loading: model.sending.contains(id), enabled: idle, compact: true) {
                    guard let minutes = LightTimerFormat.parseFree(text) else {
                        error = LightTimerFormat.invalidMessage
                        return
                    }
                    error = nil
                    text = ""
                    model.set(id, minutes: minutes)
                }
                .accessibilityIdentifier("timer-\(context)-\(id)-apply")
            }
            if let error {
                Text(error).font(.caption).foregroundStyle(colors.danger)
                    .accessibilityIdentifier("timer-\(context)-\(id)-error")
            }
        }
    }
}
