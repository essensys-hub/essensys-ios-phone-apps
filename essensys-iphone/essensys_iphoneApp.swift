//
//  essensys_iphoneApp.swift
//  essensys-iphone
//
//  Point d'entrée. Refonte v2 : ios-portal-refresh-2026-10-003 (essensys-hub/essensys-feature-lifecycle#13).
//

import SwiftUI

@main
struct EssensysApp: App {
    private let container: AppContainer

    init() {
        #if DEBUG
        if UITestBackend.isEnabled {
            container = AppContainer(
                store: SessionStore(persistence: InMemoryPersistence(initial: UITestBackend.initialState())),
                guardNoArmoire: true, protocolClasses: [UITestURLProtocol.self], resolve: { _ in 1 })
            return
        }
        #endif
        let persistence = KeychainPersistence()
        // La v1 stockait le mot de passe en clair dans UserDefaults : purge au premier lancement.
        persistence.purgeLegacy()
        container = AppContainer(store: SessionStore(persistence: persistence), guardNoArmoire: false,
                                 appLog: AppLog(file: AppLog.defaultFile()), device: IPhoneDeviceProbe())
        let info = Bundle.main.infoDictionary
        container.appLog.event("app", "Démarrage \(info?["CFBundleShortVersionString"] as? String ?? "?") (\(info?["CFBundleVersion"] as? String ?? "?"))")
    }

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ZStack(alignment: .bottomLeading) {
                EssensysRoot(container: container)
                #if DEBUG
                if UITestBackend.isEnabled { UITestProbe() }
                #endif
            }
            // Journal du support écrit sur disque à la mise en arrière-plan (design D1).
            .onChange(of: scenePhase) { _, phase in if phase == .background { container.appLog.flush() } }
        }
    }
}
