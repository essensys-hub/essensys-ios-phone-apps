//
//  MainScreens.swift
//  Accueil V1 (sans données fictives) et Réglages.
//

import SwiftUI

enum Destination: String, CaseIterable, Hashable {
    case home, lighting, shutters, settings
    var label: String {
        switch self {
        case .home: "Accueil"
        case .lighting: "Éclairage"
        case .shutters: "Volets"
        case .settings: "Réglages"
        }
    }
    var title: String {
        switch self {
        case .home: "Essensys"
        case .lighting: "Éclairage"
        case .shutters: "Volets & stores"
        case .settings: "Réglages"
        }
    }
    var icon: String {
        switch self {
        case .home: "house"
        case .lighting: "lightbulb"
        case .shutters: "blinds.horizontal.closed"
        case .settings: "gearshape"
        }
    }
}

struct HomeScreen: View {
    let open: (Destination) -> Void
    @Environment(\.essensys) private var colors

    var body: some View {
        ScreenColumn {
            EssensysCard(title: "Commandes", description: "Pilotez votre installation") {
                ActionButton(label: "Éclairage") { open(.lighting) }.accessibilityIdentifier("open-lighting")
                ActionButton(label: "Volets & stores") { open(.shutters) }.accessibilityIdentifier("open-shutters")
            }
            EssensysCard(title: "Bientôt disponible", description: "Prochaine version de l'application") {
                ForEach(["Chauffage", "Scénarios", "Chauffe-eau", "Arrosage", "Alarme"], id: \.self) {
                    Text("• \($0)").foregroundStyle(colors.textMuted)
                }
                Text("En attendant, ces fonctions restent accessibles depuis le portail web.")
                    .font(.caption).foregroundStyle(colors.textMuted)
            }
        }
    }
}

struct SettingsScreen: View {
    @Bindable var model: SessionModel
    @Environment(\.essensys) private var colors

    var body: some View {
        ScreenColumn {
            EssensysCard(title: "Connexion") {
                Text(model.session.mode == .cloud ? "Cloud — mon.essensys.fr"
                     : "Réseau local — \(URL(string: model.session.lanHost)?.host ?? model.session.lanHost)")
                    .foregroundStyle(colors.text)
                ActionButton(label: model.session.mode == .cloud ? "Passer en réseau local" : "Passer en cloud", tone: .secondary) {
                    model.setMode(model.session.mode == .cloud ? .lan : .cloud)
                }
                .accessibilityIdentifier("switch-mode")
            }
            EssensysCard(title: "Apparence") {
                Picker("Thème", selection: Binding(get: { model.session.theme }, set: { model.setTheme($0) })) {
                    Text("Système").tag(ThemePreference.system)
                    Text("Clair").tag(ThemePreference.light)
                    Text("Sombre").tag(ThemePreference.dark)
                }
                .pickerStyle(.segmented).accessibilityIdentifier("theme")
            }
            EssensysCard(title: "Mode test", description: "Les commandes sont validées par le serveur sans être exécutées par l'armoire") {
                Toggle("Activer le mode test", isOn: Binding(get: { model.session.testMode }, set: { model.setTestMode($0) }))
                    .foregroundStyle(colors.text).accessibilityIdentifier("test-mode")
            }
            EssensysCard(title: "Compte") {
                ActionButton(label: "Se déconnecter", tone: .danger) { Task { await model.logout() } }
                    .accessibilityIdentifier("logout")
                Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?")")
                    .font(.caption).foregroundStyle(colors.textMuted)
            }
        }
    }
}
