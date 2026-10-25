//
//  FeatureScreens.swift
//  Scénarios, Chauffe-eau, Arrosage et Alarme (specs scenarios, comfort-controls, alarm-control),
//  écrans poussés depuis l'accueil. Jumeaux de ScenariosScreen.kt et ComfortScreens.kt.
//

import SwiftUI

struct ScenariosScreen: View {
    @Bindable var model: ScenariosModel
    let enabled: Bool
    @Environment(\.essensys) private var colors

    var body: some View {
        ScreenColumn {
            FeedbackBanner(feedback: model.feedback)
            if let editor = model.editor { editorCard(editor) }
            ForEach(model.slots) { slot in
                EssensysCard(title: slot.label) {
                    if slot.lastLaunched == slot.slot {
                        StatusPill(text: "Dernier lancé", color: colors.success).accessibilityIdentifier("last-\(slot.slot)")
                    }
                    HStack(spacing: 8) {
                        ActionButton(label: "Lancer", loading: model.inFlight.contains("launch-\(slot.slot)"), enabled: enabled) {
                            model.launch(slot.slot, label: slot.label)
                        }
                        .accessibilityIdentifier("launch-\(slot.slot)")
                        if slot.editable {
                            ActionButton(label: "Éditer", tone: .secondary, enabled: model.editor == nil) { model.openEditor(slot) }
                                .accessibilityIdentifier("edit-\(slot.slot)")
                        }
                    }
                    if IndexTable.restorableScenarioSlots.contains(slot.slot) {
                        ActionButton(label: "Réglages d'usine", tone: .secondary,
                                     loading: model.inFlight.contains("restore-\(slot.slot)"), enabled: enabled) { model.confirmRestore = slot }
                            .accessibilityIdentifier("restore-\(slot.slot)")
                    }
                }
            }
        }
        .task { await model.load() }
        .alert("Réglages d'usine", isPresented: Binding(get: { model.confirmRestore != nil }, set: { if !$0 { model.confirmRestore = nil } }),
               presenting: model.confirmRestore) { _ in
            Button("Remettre", role: .destructive) { model.confirmRestoreNow() }.accessibilityIdentifier("restore-confirm")
            Button("Annuler", role: .cancel) { model.confirmRestore = nil }.accessibilityIdentifier("restore-cancel")
        } message: { slot in
            Text("Remettre « \(slot.label) » dans son état d'origine ? Vos modifications de ce scénario seront perdues.")
        }
    }

    @ViewBuilder private func editorCard(_ editor: ScenarioEditor) -> some View {
        EssensysCard(title: "Éditer — \(editor.slot.label)", description: "Lumières et volets commandés par ce scénario") {
            if editor.loading {
                Text("Chargement…").foregroundStyle(colors.textMuted)
            } else if editor.incomplete {
                Text("La définition de ce scénario n'est pas encore connue (l'armoire ne l'a pas transmise). "
                     + "L'enregistrer remettrait à zéro ses autres réglages : modification impossible pour l'instant.")
                    .foregroundStyle(colors.textMuted).accessibilityIdentifier("scenario-incomplete")
            } else {
                ForEach(editor.fields, id: \.index) { field in
                    Text(field.title).font(.subheadline.weight(.semibold)).foregroundStyle(colors.text)
                    ForEach(field.bits, id: \.value) { bit in
                        Toggle(bit.label, isOn: Binding(
                            get: { editor.definition?.isSet(metaIndex: field.index, bitValue: bit.value) == true },
                            set: { model.toggle(metaIndex: field.index, bitValue: bit.value, on: $0) }))
                            .foregroundStyle(colors.text)
                            .disabled(editor.saving)
                            .accessibilityIdentifier("bit-\(field.index)-\(bit.value)")
                    }
                }
            }
            HStack(spacing: 8) {
                ActionButton(label: "Fermer", tone: .secondary) { model.closeEditor() }.accessibilityIdentifier("editor-close")
                ActionButton(label: "Enregistrer", loading: editor.saving, enabled: enabled && editor.definition != nil) { model.saveEditor() }
                    .accessibilityIdentifier("editor-save")
            }
        }
    }
}

extension BitmaskField {
    /// Libellé lisible des champs meta/bitmasks (le portail affiche le nom brut).
    var title: String {
        if name.hasPrefix("Eteindre_PDV") { return "Éteindre — pièces de vie" }
        if name.hasPrefix("Eteindre_CHB") { return "Éteindre — chambres" }
        if name.hasPrefix("Allumer_CHB") { return "Allumer — chambres" }
        if name.hasPrefix("Allumer_PDV") { return "Allumer — pièces de vie" }
        if name.hasPrefix("OuvrirVolets") { return "Ouvrir les volets — pièces de vie" }
        if name.hasPrefix("FermerVolets") { return "Fermer les volets — pièces de vie" }
        return name
    }
}

/// Chauffe-eau (spec comfort-controls) : Cumulus_Mode, indice 353.
struct WaterHeaterScreen: View {
    let model: ComfortModel
    let enabled: Bool
    @Environment(\.essensys) private var colors

    var body: some View {
        ScreenColumn {
            FeedbackBanner(feedback: model.feedback)
            EssensysCard(title: "Mode de fonctionnement", description: "Mode actuel : \(model.modes?.waterHeater?.label ?? "inconnu")") {
                ForEach(IndexTable.WaterHeaterMode.allCases, id: \.self) { mode in
                    ActionButton(label: mode.label, tone: model.modes?.waterHeater == mode ? .primary : .secondary,
                                 loading: model.inFlight.contains("heater-\(mode.name)"), enabled: enabled) { model.setWaterHeater(mode) }
                        .accessibilityIdentifier("heater-\(mode.name)")
                }
                Text("Heures creuses : le chauffe-eau ne chauffe que pendant les heures creuses de votre contrat.")
                    .font(.caption).foregroundStyle(colors.textMuted)
            }
        }
        .task { await model.loadModes() }
    }
}

/// Arrosage (spec comfort-controls) : Arrose_Mode, indice 363.
struct SprinklerScreen: View {
    let model: ComfortModel
    let enabled: Bool
    @Environment(\.essensys) private var colors

    var body: some View {
        ScreenColumn {
            FeedbackBanner(feedback: model.feedback)
            EssensysCard(title: "Mode d'arrosage", description: "Mode actuel : \(model.modes?.sprinklerLabel ?? "inconnu")") {
                ForEach(IndexTable.SprinklerMode.allCases, id: \.self) { mode in
                    ActionButton(label: mode.label, tone: model.modes?.sprinklerMinutes == mode.rawValue ? .primary : .secondary,
                                 loading: model.inFlight.contains("sprinkler-\(mode.name)"), enabled: enabled) { model.setSprinkler(mode) }
                        .accessibilityIdentifier("sprinkler-\(mode.name)")
                }
                Text("Automatique : l'armoire suit le planning d'arrosage programmé.")
                    .font(.caption).foregroundStyle(colors.textMuted)
            }
        }
        .task { await model.loadModes() }
    }
}

/// Alarme (spec alarm-control). Le code vit seulement dans cet écran (@State, jamais @SceneStorage ni
/// Keychain), vidé après chaque envoi et dès que l'app quitte le premier plan.
struct AlarmScreen: View {
    let model: ComfortModel
    let enabled: Bool
    let lanMode: Bool
    @State private var code = ""
    @State private var confirmOff = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.essensys) private var colors

    var body: some View {
        ScreenColumn {
            FeedbackBanner(feedback: model.feedback)
            if lanMode {
                EssensysCard(title: "Alarme") {
                    Text("Disponible en mode cloud seulement. La gateway locale ne permet pas encore de piloter l'alarme : connectez-vous en mode cloud.")
                        .foregroundStyle(colors.textMuted).accessibilityIdentifier("alarm-cloud-only")
                }
            } else {
                EssensysCard(title: "Contrôle de l'alarme", description: "Entrez votre code à 4 chiffres") {
                    SecureField("Code", text: Binding(get: { code }, set: { code = String($0.filter(\.isNumber).prefix(4)) }))
                        .keyboardType(.numberPad)
                        .textContentType(nil)
                        .autocorrectionDisabled()
                        .padding(10)
                        .overlay(RoundedRectangle(cornerRadius: Radius.button).stroke(colors.border))
                        .accessibilityIdentifier("alarm-code")
                    let ready = code.count == 4 && enabled
                    HStack(spacing: 8) {
                        ActionButton(label: "Mettre en service", loading: model.inFlight.contains("alarm-on"), enabled: ready) {
                            model.alarm(on: true, code: code)
                            code = ""
                        }
                        .accessibilityIdentifier("alarm-on")
                        ActionButton(label: "Arrêter", tone: .danger, loading: model.inFlight.contains("alarm-off"), enabled: ready) { confirmOff = true }
                            .accessibilityIdentifier("alarm-off")
                    }
                    Text("L'envoi ne garantit pas l'état de l'alarme. Vérifiez l'état sur le clavier de l'armoire.")
                        .font(.caption).foregroundStyle(colors.textMuted).accessibilityIdentifier("alarm-reminder")
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in if phase != .active { code = ""; confirmOff = false } }
        .alert("Arrêter l'alarme", isPresented: $confirmOff) {
            Button("Arrêter", role: .destructive) { model.alarm(on: false, code: code); code = "" }.accessibilityIdentifier("alarm-off-confirm")
            Button("Annuler", role: .cancel) {}.accessibilityIdentifier("alarm-off-cancel")
        } message: {
            Text("Confirmez-vous l'arrêt de l'alarme ?")
        }
    }
}
