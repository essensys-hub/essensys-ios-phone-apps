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
    let heating: HeatingRepository
    let scenarios: ScenarioRepository
    let comfort: ComfortRepository

    /// - Parameters syncPoll, syncTimeout : périodes de synchronisation du chauffage (courtes en test).
    init(store: SessionStore, guardNoArmoire: Bool, protocolClasses: [AnyClass]? = nil,
         syncPoll: Duration = .seconds(3), syncTimeout: Duration = .seconds(90)) {
        self.store = store
        api = APIClient(store: store, guardNoArmoire: guardNoArmoire, protocolClasses: protocolClasses)
        auth = AuthRepository(api: api, store: store)
        control = ControlRepository(api: api, store: store, auth: auth)
        portal = PortalRepository(api: api, auth: auth)
        heating = HeatingRepository(api: api, store: store, auth: auth, control: control, syncPoll: syncPoll, syncTimeout: syncTimeout)
        scenarios = ScenarioRepository(api: api, store: store, auth: auth)
        comfort = ComfortRepository(api: api, store: store, auth: auth, control: control)
    }
}
