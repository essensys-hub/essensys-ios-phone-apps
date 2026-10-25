//
//  ControlScreens.swift
//  Éclairage et Volets — même structure que LightingPage.tsx / ShuttersPage.tsx (spec domotic-controls).
//

import SwiftUI

struct GroupActions: View {
    let labels: (String, String)
    let tag: String
    let model: ControlModel
    let enabled: Bool
    let onAll: (Bool) -> Void

    var body: some View {
        let busy = model.inFlight.contains { $0.hasPrefix(tag) }
        HStack(spacing: 8) {
            ActionButton(label: labels.0, loading: model.inFlight.contains("\(tag)-true"), enabled: enabled && !busy) { onAll(true) }
                .accessibilityIdentifier("\(tag)-all-on")
            ActionButton(label: labels.1, tone: .secondary, loading: model.inFlight.contains("\(tag)-false"), enabled: enabled && !busy) { onAll(false) }
                .accessibilityIdentifier("\(tag)-all-off")
        }
    }
}

struct CommandRow: View {
    let name: String
    var detail: String?
    let tag: String
    let primary: (String, Bool, () -> Void)
    let secondary: (String, Bool, () -> Void)
    let enabled: Bool
    @Environment(\.essensys) private var colors

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.subheadline).foregroundStyle(colors.text)
                if let detail { Text(detail).font(.caption).foregroundStyle(colors.textMuted) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            ActionButton(label: primary.0, loading: primary.1, enabled: enabled, compact: true, action: primary.2)
                .accessibilityIdentifier("\(tag)-primary")
            ActionButton(label: secondary.0, tone: .secondary, loading: secondary.1, enabled: enabled, compact: true, action: secondary.2)
                .accessibilityIdentifier("\(tag)-secondary")
        }
    }
}

struct LightingScreen: View {
    let model: ControlModel
    let enabled: Bool

    var body: some View {
        ScreenColumn {
            FeedbackBanner(feedback: model.feedback)
            ForEach([(IndexTable.Group.main, "Éclairage principal", "Plafonniers et appliques"),
                     (.indirect, "Éclairage indirect", "Ambiance, chevets, miroirs")], id: \.1) { group, title, description in
                let lights = IndexTable.lights.filter { $0.group == group }
                EssensysCard(title: title, description: description) {
                    GroupActions(labels: ("Tout allumer", "Tout éteindre"), tag: "group-\(group)", model: model, enabled: enabled) { on in
                        model.send(key: "group-\(group)-\(on)", label: on ? "Tout allumer" : "Tout éteindre", injections: lights.map { $0.command(on: on) })
                    }
                    ForEach(lights) { light in
                        CommandRow(
                            name: light.name, tag: "light-\(light.id)",
                            primary: ("Allumer", model.inFlight.contains("\(light.id)-on"), {
                                model.send(key: "\(light.id)-on", label: light.name, injections: [light.command(on: true)])
                            }),
                            secondary: ("Éteindre", model.inFlight.contains("\(light.id)-off"), {
                                model.send(key: "\(light.id)-off", label: light.name, injections: [light.command(on: false)])
                            }),
                            enabled: enabled)
                    }
                }
            }
        }
    }
}

struct ShuttersScreen: View {
    let model: ControlModel
    let enabled: Bool

    var body: some View {
        ScreenColumn {
            FeedbackBanner(feedback: model.feedback)
            ForEach([(IndexTable.Group.main, "Volets", "Volets roulants"),
                     (.special, "Volet Store et Store banne", "Éléments spéciaux")], id: \.1) { group, title, description in
                let items = IndexTable.shutters.filter { $0.group == group }
                EssensysCard(title: title, description: description) {
                    GroupActions(labels: ("Tout ouvrir", "Tout fermer"), tag: "group-\(group)", model: model, enabled: enabled) { open in
                        model.send(key: "group-\(group)-\(open)", label: open ? "Tout ouvrir" : "Tout fermer", injections: items.map { $0.command(open: open) })
                    }
                    ForEach(items) { shutter in
                        CommandRow(
                            name: shutter.name,
                            detail: model.travelTimes[shutter.travelTimeIndex].map { "Temps de course : \($0) s" },
                            tag: "shutter-\(shutter.id)",
                            primary: ("Ouvrir", model.inFlight.contains("\(shutter.id)-open"), {
                                model.send(key: "\(shutter.id)-open", label: shutter.name, injections: [shutter.command(open: true)])
                            }),
                            secondary: ("Fermer", model.inFlight.contains("\(shutter.id)-close"), {
                                model.send(key: "\(shutter.id)-close", label: shutter.name, injections: [shutter.command(open: false)])
                            }),
                            enabled: enabled)
                    }
                }
            }
            TravelTimeCard(model: model, enabled: enabled)
        }
        .task { await model.loadTravelTimes() }
    }
}

/// Réglage du temps de course, comme la carte « Temps de course » du portail (spec shutter-travel-time).
private struct TravelTimeCard: View {
    let model: ControlModel
    let enabled: Bool
    @State private var edited: [String: String] = [:]
    @Environment(\.essensys) private var colors

    var body: some View {
        EssensysCard(title: "Temps de course", description: "Durée de commande du moteur, à l'ouverture et à la fermeture (1 à 255 secondes)") {
            ForEach(IndexTable.shutters) { shutter in
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(shutter.name).font(.subheadline).foregroundStyle(colors.text)
                        Text(model.travelTimes[shutter.travelTimeIndex].map { "Actuel : \($0) s" } ?? "Non transmis (défaut usine : 120 s, store : 255 s)")
                            .font(.caption).foregroundStyle(colors.textMuted)
                            .accessibilityIdentifier("time-current-\(shutter.id)")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    TextField("s", text: Binding(get: { edited[shutter.id] ?? "" },
                                                 set: { edited[shutter.id] = String($0.filter(\.isNumber).prefix(3)) }))
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .frame(width: 64).padding(.vertical, 8)
                        .overlay(RoundedRectangle(cornerRadius: Radius.button).stroke(colors.border))
                        .accessibilityIdentifier("time-input-\(shutter.id)")
                    ActionButton(label: "OK", loading: model.inFlight.contains("time-\(shutter.id)"),
                                 enabled: enabled && !(edited[shutter.id] ?? "").isEmpty, compact: true) {
                        if model.saveTravelTime(shutter, raw: edited[shutter.id] ?? "") { edited[shutter.id] = nil }
                    }
                    .accessibilityIdentifier("time-save-\(shutter.id)")
                }
            }
        }
    }
}
