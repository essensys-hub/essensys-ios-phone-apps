//
//  HeatingScreen.swift
//  Chauffage — planning hebdomadaire par zone et mode immédiat (HeatingPage.tsx, spec heating-control).
//  Sur téléphone, la grille s'édite jour par jour (24 cases) au lieu de la grille 7 × 24 du portail.
//

import SwiftUI

struct HeatingScreen: View {
    @Bindable var model: HeatingModel
    let enabled: Bool
    let lanMode: Bool
    @Environment(\.essensys) private var colors

    var body: some View {
        let busy = model.saving || model.syncing
        ScreenColumn {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(IndexTable.heatingZones) { zone in
                        Chip(label: zone.name, selected: zone == model.zone) { if zone != model.zone { model.load(zone) } }
                            .disabled(busy)
                            .accessibilityIdentifier("zone-\(zone.id)")
                    }
                }
            }
            FeedbackBanner(feedback: model.feedback)
            if model.stale {
                Text("Données de l'armoire peut-être anciennes")
                    .font(.caption).foregroundStyle(colors.text)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(12)
                    .background(colors.warning.opacity(0.15))
                    .accessibilityIdentifier("heating-stale")
            }
            EssensysCard(title: "Planning — \(model.zone.name)", description: "Touchez une heure pour lui appliquer la consigne choisie") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(IndexTable.HeatingSlot.palette, id: \.self) { slot in
                            Chip(label: slot.label, selected: slot == model.brush, swatch: slot.color) { model.brush = slot }
                                .accessibilityIdentifier("brush-\(slot.name)")
                        }
                    }
                }
                HStack(spacing: 4) {
                    ForEach(0..<ScheduleGrid.days, id: \.self) { day in
                        Button { model.day = day } label: {
                            Text(ScheduleGrid.dayLabels[day]).font(.subheadline.weight(.medium)).lineLimit(1)
                                .frame(maxWidth: .infinity).frame(height: 34)
                                .foregroundStyle(day == model.day ? .white : colors.text)
                                .background(day == model.day ? colors.primary : colors.card, in: RoundedRectangle(cornerRadius: Radius.button))
                                .overlay(RoundedRectangle(cornerRadius: Radius.button).stroke(day == model.day ? colors.primary : colors.border))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("day-\(day)")
                        .accessibilityAddTraits(day == model.day ? .isSelected : [])
                    }
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 6), spacing: 4) {
                    ForEach(0..<ScheduleGrid.hours, id: \.self) { hour in
                        let slot = IndexTable.HeatingSlot(rawValue: model.grid[model.day, hour])
                        Button { model.paint(hour: hour) } label: {
                            VStack(spacing: 2) {
                                Text("\(hour)h").font(.caption2.weight(.semibold))
                                Text(slot?.short ?? "?").font(.caption2)
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity).frame(height: 44)
                            .background(slot.color, in: RoundedRectangle(cornerRadius: Radius.button))
                        }
                        .buttonStyle(.plain)
                        .disabled(!model.loaded || busy)
                        .accessibilityIdentifier("hour-\(hour)")
                        .accessibilityLabel("\(hour) h : \(slot?.label ?? "?")")
                    }
                }
                ActionButton(label: "Appliquer \(ScheduleGrid.dayLabels[model.day]) à toute la semaine", tone: .secondary,
                             enabled: model.loaded && !busy) { model.copyDayToAll() }
                    .accessibilityIdentifier("heating-copy-day")
                if let hint = model.pendingHint {
                    Text(hint).font(.caption).foregroundStyle(colors.textMuted).accessibilityIdentifier("heating-pending")
                }
                if let progress = model.progress {
                    Text(progress).font(.caption).foregroundStyle(colors.primary).accessibilityIdentifier("heating-progress")
                }
                HStack(spacing: 8) {
                    ActionButton(label: "Annuler", tone: .secondary, enabled: model.dirty && !busy) { model.revert() }
                        .accessibilityIdentifier("heating-revert")
                    ActionButton(label: "Enregistrer", loading: model.saving, enabled: model.dirty && enabled && !model.syncing) { model.save() }
                        .accessibilityIdentifier("heating-save")
                }
                ActionButton(label: lanMode ? "Synchroniser avec l'armoire" : "Relire les dernières valeurs", tone: .secondary,
                             loading: model.syncing, enabled: !model.saving && (enabled || !lanMode)) { model.syncFromArmoire() }
                    .accessibilityIdentifier("heating-sync")
            }
            EssensysCard(title: "Mode immédiat", description: "S'applique tout de suite à la zone \(model.zone.name)") {
                ForEach(model.zone.immediateModes, id: \.self) { mode in
                    ActionButton(label: mode.label, tone: mode == .auto ? .primary : .secondary,
                                 loading: model.modeInFlight == mode, enabled: enabled && model.modeInFlight == nil) { model.setMode(mode) }
                        .accessibilityIdentifier("mode-\(mode.name)")
                }
            }
        }
        .task { if !model.loaded { model.load() } }
    }
}

/// Pastille sélectionnable (zones, consignes), équivalent du FilterChip Android.
struct Chip: View {
    let label: String
    let selected: Bool
    var swatch: Color?
    let action: () -> Void
    @Environment(\.essensys) private var colors

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let swatch { RoundedRectangle(cornerRadius: 3).fill(swatch).frame(width: 12, height: 12) }
                Text(label).font(.subheadline).lineLimit(1)
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .foregroundStyle(selected ? colors.primary : colors.text)
            .background(selected ? colors.primary.opacity(0.12) : colors.card, in: RoundedRectangle(cornerRadius: Radius.button))
            .overlay(RoundedRectangle(cornerRadius: Radius.button).stroke(selected ? .clear : colors.border))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

extension IndexTable.HeatingSlot {
    /// Nom stable, identique à l'enum Kotlin (identifiants d'accessibilité).
    var name: String {
        switch self {
        case .off: "OFF"
        case .confort: "CONFORT"
        case .eco: "ECO"
        case .ecoPlus: "ECO_PLUS"
        case .ecoPlusPlus: "ECO_PLUS_PLUS"
        case .frost: "FROST"
        }
    }

    var short: String {
        switch self {
        case .off: "—"
        case .confort: "C"
        case .eco: "E"
        case .ecoPlus: "E+"
        case .ecoPlusPlus: "E++"
        case .frost: "HG"
        }
    }
}

extension Optional where Wrapped == IndexTable.HeatingSlot {
    /// Couleurs de l'écran physique SC945D, reprises du portail (SCHEDULE_MODES).
    var color: Color {
        switch self {
        case .confort?: Color(red: 0xEF / 255, green: 0x44 / 255, blue: 0x44 / 255)
        case .eco?: Color(red: 0xF9 / 255, green: 0x73 / 255, blue: 0x16 / 255)
        case .ecoPlus?: Color(red: 0xEA / 255, green: 0xB3 / 255, blue: 0x08 / 255)
        case .ecoPlusPlus?: Color(red: 0x06 / 255, green: 0xB6 / 255, blue: 0xD4 / 255)
        case .off?: Color(red: 0x64 / 255, green: 0x74 / 255, blue: 0x8B / 255)
        case .frost?: Color(red: 0x3B / 255, green: 0x82 / 255, blue: 0xF6 / 255)
        case nil: Color(red: 0x94 / 255, green: 0xA3 / 255, blue: 0xB8 / 255)
        }
    }
}

extension IndexTable.HeatingSlot {
    var color: Color { Optional(self).color }
}
