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
                guardNoArmoire: true, protocolClasses: [UITestURLProtocol.self])
            return
        }
        #endif
        let persistence = KeychainPersistence()
        // La v1 stockait le mot de passe en clair dans UserDefaults : purge au premier lancement.
        persistence.purgeLegacy()
        container = AppContainer(store: SessionStore(persistence: persistence), guardNoArmoire: false)
    }

    var body: some Scene {
        WindowGroup {
            ZStack(alignment: .bottomLeading) {
                EssensysRoot(container: container)
                #if DEBUG
                if UITestBackend.isEnabled { UITestProbe() }
                #endif
            }
        }
    }
}
