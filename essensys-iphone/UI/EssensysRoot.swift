//
//  EssensysRoot.swift
//  Racine : thème, puis aiguillage connexion → mot de passe → liaison → commandes (jumeau d'AppRoot.kt).
//

import SwiftUI

struct EssensysRoot: View {
    @State private var session: SessionModel
    @State private var control: ControlModel
    @State private var heating: HeatingModel
    @State private var scenarios: ScenariosModel
    @State private var comfort: ComfortModel

    init(container: AppContainer) {
        _session = State(initialValue: SessionModel(container: container))
        _control = State(initialValue: ControlModel(control: container.control))
        _heating = State(initialValue: HeatingModel(heating: container.heating))
        _scenarios = State(initialValue: ScenariosModel(scenarios: container.scenarios))
        _comfort = State(initialValue: ComfortModel(comfort: container.comfort))
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
                case .linked: MainTabs(session: session, control: control, heating: heating, scenarios: scenarios, comfort: comfort)
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
    let heating: HeatingModel
    let scenarios: ScenariosModel
    let comfort: ComfortModel
    @State private var destination: Destination = .home
    @State private var homePath: [Feature] = []
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.essensys) private var colors

    var body: some View {
        let enabled = session.session.mode == .lan || session.gatewayOnline == true
        let lan = session.session.mode == .lan
        VStack(spacing: 0) {
            header
            TabView(selection: Binding(get: { destination }, set: { destination = $0; homePath = [] })) {
                NavigationStack(path: $homePath) {
                    HomeScreen(scenarios: scenarios, enabled: enabled, openTab: { destination = $0 }, openFeature: { homePath.append($0) })
                        .toolbar(.hidden, for: .navigationBar)
                        .navigationDestination(for: Feature.self) { feature in
                            Group {
                                switch feature {
                                case .scenarios: ScenariosScreen(model: scenarios, enabled: enabled)
                                case .waterHeater: WaterHeaterScreen(model: comfort, enabled: enabled)
                                case .sprinkler: SprinklerScreen(model: comfort, enabled: enabled)
                                case .securityOutlets: SecurityOutletsScreen(model: comfort, enabled: enabled)
                                case .alarm: AlarmScreen(model: comfort, enabled: enabled, lanMode: lan)
                                }
                            }
                            .navigationTitle(feature.title)
                            .navigationBarTitleDisplayMode(.inline)
                        }
                }
                .tag(Destination.home)
                .tabItem { Label(Destination.home.label, systemImage: Destination.home.icon) }
                LightingScreen(model: control, enabled: enabled).tag(Destination.lighting)
                    .tabItem { Label(Destination.lighting.label, systemImage: Destination.lighting.icon) }
                ShuttersScreen(model: control, enabled: enabled).tag(Destination.shutters)
                    .tabItem { Label(Destination.shutters.label, systemImage: Destination.shutters.icon) }
                HeatingScreen(model: heating, enabled: enabled, lanMode: lan).tag(Destination.heating)
                    .tabItem { Label(Destination.heating.label, systemImage: Destination.heating.icon) }
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
            // Visible sur toutes les captures envoyées au support (#27).
            Text("Version \(appVersion)").font(.caption2).foregroundStyle(colors.textMuted).accessibilityIdentifier("app-version")
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(colors.card)
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
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
