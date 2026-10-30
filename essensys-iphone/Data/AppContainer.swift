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
    let appLog: AppLog
    let supportDiagnostics: SupportDiagnostics
    let supportBundle: SupportBundle

    /// - Parameters syncPoll, syncTimeout : périodes de synchronisation du chauffage (courtes en test).
    /// - Parameters appLog, device, supportDirectory : bouton Support (app-support-bundle-2026-10-013) ;
    ///   journal en mémoire et appareil fixe par défaut (tests).
    init(store: SessionStore, guardNoArmoire: Bool, protocolClasses: [AnyClass]? = nil,
         syncPoll: Duration = .seconds(3), syncTimeout: Duration = .seconds(90),
         appLog: AppLog = AppLog(), device: DeviceProbe = StaticDeviceProbe(),
         supportDirectory: URL = SupportBundle.defaultDirectory(),
         resolve: @escaping @Sendable (String) -> Int? = SupportDiagnostics.getaddrinfoCount) {
        self.store = store
        self.appLog = appLog
        api = APIClient(store: store, guardNoArmoire: guardNoArmoire, protocolClasses: protocolClasses, log: appLog)
        auth = AuthRepository(api: api, store: store)
        control = ControlRepository(api: api, store: store, auth: auth)
        portal = PortalRepository(api: api, auth: auth)
        heating = HeatingRepository(api: api, store: store, auth: auth, control: control, syncPoll: syncPoll, syncTimeout: syncTimeout)
        scenarios = ScenarioRepository(api: api, store: store, auth: auth)
        comfort = ComfortRepository(api: api, store: store, auth: auth, control: control)
        supportDiagnostics = SupportDiagnostics(store: store, device: device, protocolClasses: protocolClasses, resolve: resolve)
        supportBundle = SupportBundle(directory: supportDirectory, store: store, log: appLog)
    }
}
