//
//  AppContainer.swift
//  Injection manuelle (design D2, comme AppContainer.kt). Les tests et le mode UI-test fournissent
//  un store en mémoire et un backend simulé (URLProtocol).
//

import Foundation

final class AppContainer: Sendable {
    let store: SessionStore
    let api: APIClient
    let auth: AuthRepository
    let control: ControlRepository
    let portal: PortalRepository

    init(store: SessionStore, guardNoArmoire: Bool, protocolClasses: [AnyClass]? = nil) {
        self.store = store
        api = APIClient(store: store, guardNoArmoire: guardNoArmoire, protocolClasses: protocolClasses)
        auth = AuthRepository(api: api, store: store)
        control = ControlRepository(api: api, store: store, auth: auth)
        portal = PortalRepository(api: api, auth: auth)
    }
}
