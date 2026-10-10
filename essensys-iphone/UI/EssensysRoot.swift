//
//  EssensysRoot.swift
//  Racine : thème, puis aiguillage connexion → mot de passe → liaison → commandes (jumeau d'AppRoot.kt).
//

import SwiftUI

struct EssensysRoot: View {
    @State private var session: SessionModel
    @State private var control: ControlModel

    init(container: AppContainer) {
        _session = State(initialValue: SessionModel(container: container))
        _control = State(initialValue: ControlModel(control: container.control))
    }

    var body: some View {
        content.modifier(EssensysThemed(preference: session.session.theme))
    }

    @ViewBuilder private var content: some View {
        if !session.session.isAuthenticated {
            LoginScreen(model: session)
        } else if session.session.passwordChangeRequired {
            PasswordChangeScreen(model: session)
        } else {
            Group {
                switch session.link {
                case nil: ScreenColumn { ProgressView("Chargement…") }
                case .linked: MainTabs(session: session, control: control)
                case let state?: LinkScreen(model: session, state: state)
                }
            }
            .task(id: "\(session.session.mode)-\(session.session.isAuthenticated)") { await session.refreshLink() }
        }
    }
}

private struct MainTabs: View {
    let session: SessionModel
    let control: ControlModel
    @State private var destination: Destination = .home
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.essensys) private var colors

    var body: some View {
        let enabled = session.session.mode == .lan || session.gatewayOnline == true
        VStack(spacing: 0) {
            header
            TabView(selection: $destination) {
                HomeScreen { destination = $0 }.tag(Destination.home)
                    .tabItem { Label(Destination.home.label, systemImage: Destination.home.icon) }
                LightingScreen(model: control, enabled: enabled).tag(Destination.lighting)
                    .tabItem { Label(Destination.lighting.label, systemImage: Destination.lighting.icon) }
                ShuttersScreen(model: control, enabled: enabled).tag(Destination.shutters)
                    .tabItem { Label(Destination.shutters.label, systemImage: Destination.shutters.icon) }
                SettingsScreen(model: session).tag(Destination.settings)
                    .tabItem { Label(Destination.settings.label, systemImage: Destination.settings.icon) }
            }
        }
        .background(colors.background)
        // Rafraîchissements uniquement au premier plan (design D6) : la tâche est annulée sinon.
        .task(id: scenePhase == .active ? "active-\(session.session.mode)" : "inactive") {
            if scenePhase == .active { await session.pollWhileVisible() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(destination.title).font(.title2.weight(.semibold)).foregroundStyle(colors.text)
                Spacer()
                if session.session.mode == .lan {
                    StatusPill(text: "Réseau local", color: colors.primary).accessibilityIdentifier("status-lan")
                } else if session.gatewayOnline == true {
                    StatusPill(text: "Armoire en ligne", color: colors.success).accessibilityIdentifier("status-online")
                } else if session.gatewayOnline == false {
                    StatusPill(text: "Armoire hors ligne", color: colors.danger).accessibilityIdentifier("status-offline")
                } else {
                    StatusPill(text: "Cloud", color: colors.secondary)
                }
            }
            if session.session.testMode {
                Text("Mode test actif — les commandes ne sont pas exécutées")
                    .font(.caption).foregroundStyle(colors.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(6).background(colors.warning.opacity(0.15))
                    .accessibilityIdentifier("test-banner")
            }
            if let info = infoLine {
                Text(info).font(.caption).foregroundStyle(colors.textMuted).accessibilityIdentifier("session-info")
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(colors.card)
    }

    private var infoLine: String? {
        if session.session.mode == .lan { return "Réseau local — connexion directe à l'armoire" }
        if session.gatewayOnline == false { return "Armoire hors ligne : les commandes sont désactivées" }
        if let action = session.lastAction {
            return "Dernière action : \(action.actionInfo ?? "—")\(action.isDone == false ? " (en cours)" : "")"
        }
        return nil
    }
}
