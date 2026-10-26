//
//  MainScreens.swift
//  Navigation, accueil (scénarios rapides et tuiles) et Réglages (spec home-dashboard).
//

import SwiftUI

/// Onglets, dans l'ordre de la spec et d'Android ; les autres écrans s'ouvrent depuis l'accueil.
enum Destination: String, CaseIterable, Hashable {
    case home, lighting, shutters, heating, settings
    var label: String {
        switch self {
        case .home: "Accueil"
        case .lighting: "Éclairage"
        case .shutters: "Volets"
        case .heating: "Chauffage"
        case .settings: "Réglages"
        }
    }
    var title: String {
        switch self {
        case .home: "Essensys"
        case .lighting: "Éclairage"
        case .shutters: "Volets & stores"
        case .heating: "Chauffage"
        case .settings: "Réglages"
        }
    }
    var icon: String {
        switch self {
        case .home: "house"
        case .lighting: "lightbulb"
        case .shutters: "blinds.horizontal.closed"
        case .heating: "thermometer.medium"
        case .settings: "gearshape"
        }
    }
}

/// Écrans poussés depuis l'accueil, avec retour (spec home-dashboard « Navigation »).
enum Feature: String, CaseIterable, Hashable {
    case scenarios = "SCENARIOS", waterHeater = "WATER_HEATER", sprinkler = "SPRINKLER", securityOutlets = "SECURITY_OUTLETS", alarm = "ALARM"
    var title: String {
        switch self {
        case .scenarios: "Scénarios"
        case .waterHeater: "Chauffe-eau"
        case .sprinkler: "Arrosage"
        case .securityOutlets: "Prises de sécurité"
        case .alarm: "Alarme"
        }
    }
}

/// Scénarios rapides de l'accueil (spec home-dashboard).
private let quickScenarios = [(2, "Je sors"), (4, "Je rentre"), (5, "Je vais me coucher"), (6, "Je me lève")]

/// Accueil : scénarios rapides et une tuile par fonction, comme le tableau de bord du portail
/// (DashboardPage.tsx). L'état de l'armoire et la dernière action restent dans l'en-tête.
struct HomeScreen: View {
    let scenarios: ScenariosModel
    let enabled: Bool
    let openTab: (Destination) -> Void
    let openFeature: (Feature) -> Void
    @Environment(\.essensys) private var colors

    private struct Tile: Identifiable {
        let id: String
        let title: String
        let description: String
        let icon: String
        let open: () -> Void
    }

    private var tiles: [Tile] {
        var tiles = [
            Tile(id: "open-lighting", title: "Éclairage", description: "Lumières principales et indirectes", icon: "lightbulb") { openTab(.lighting) },
            Tile(id: "open-shutters", title: "Volets & stores", description: "Ouverture et fermeture", icon: "blinds.horizontal.closed") { openTab(.shutters) },
            Tile(id: "open-heating", title: "Chauffage", description: "Zones et planning", icon: "thermometer.medium") { openTab(.heating) },
            Tile(id: "open-SCENARIOS", title: "Scénarios", description: "Je sors, vacances, personnalisés", icon: "play.circle") { openFeature(.scenarios) },
            Tile(id: "open-WATER_HEATER", title: "Chauffe-eau", description: "Marche, heures creuses, arrêt", icon: "drop") { openFeature(.waterHeater) },
            Tile(id: "open-SPRINKLER", title: "Arrosage", description: "Programmation jardin", icon: "leaf") { openFeature(.sprinkler) },
            Tile(id: "open-SECURITY_OUTLETS", title: "Prises de sécurité", description: "Couper et rétablir", icon: "powerplug") { openFeature(.securityOutlets) },
        ]
        if FeatureFlags.alarmEnabled {
            tiles.append(Tile(id: "open-ALARM", title: "Alarme", description: "Mise en service et arrêt", icon: "shield") { openFeature(.alarm) })
        }
        return tiles
    }

    var body: some View {
        ScreenColumn {
            FeedbackBanner(feedback: scenarios.feedback)
            EssensysCard(title: "Scénarios rapides", description: enabled ? "Un appui lance le scénario" : "Armoire hors ligne : lancement impossible") {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(quickScenarios, id: \.0) { slot, label in
                        ActionButton(label: label, loading: scenarios.inFlight.contains("launch-\(slot)"), enabled: enabled) {
                            scenarios.launch(slot, label: label)
                        }
                        .accessibilityIdentifier("quick-\(slot)")
                    }
                }
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(tiles) { tile in
                    Button(action: tile.open) {
                        VStack(alignment: .leading, spacing: 6) {
                            Image(systemName: tile.icon).font(.title3).foregroundStyle(colors.primary)
                            Text(tile.title).font(.subheadline.weight(.semibold)).foregroundStyle(colors.text)
                            Text(tile.description).font(.caption).foregroundStyle(colors.textMuted).multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
                        .padding(14)
                        .background(colors.card, in: RoundedRectangle(cornerRadius: Radius.card))
                        .overlay(RoundedRectangle(cornerRadius: Radius.card).stroke(colors.border))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(tile.id)
                }
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
                if model.session.mode == .cloud {
                    if let user = model.account?.user {
                        let name = [user.firstName, user.lastName].compactMap { $0 }.joined(separator: " ")
                        Text([name.isEmpty ? nil : name, user.email].compactMap { $0 }.joined(separator: " — "))
                            .foregroundStyle(colors.text).accessibilityIdentifier("account-user")
                    }
                    if let armoire = model.account?.armoire {
                        Text("Armoire \(armoire.serial ?? "—")" + (armoire.lastSeen.map { " · dernier contact \(formatLastSeen($0))" } ?? ""))
                            .font(.caption).foregroundStyle(colors.textMuted).accessibilityIdentifier("account-armoire")
                    }
                }
                ActionButton(label: "Se déconnecter", tone: .danger) { Task { await model.logout() } }
                    .accessibilityIdentifier("logout")
                Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?")")
                    .font(.caption).foregroundStyle(colors.textMuted)
            }
        }
    }
}

/// « 2026-10-25T08:00:00Z » → « 25/10/2026 08:00 » (heure locale) ; brut si illisible.
func formatLastSeen(_ raw: String) -> String {
    guard let date = ISO8601DateFormatter().date(from: raw) else { return raw }
    let formatter = DateFormatter()
    formatter.dateFormat = "dd/MM/yyyy HH:mm"
    return formatter.string(from: date)
}
