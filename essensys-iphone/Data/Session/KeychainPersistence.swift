//
//  KeychainPersistence.swift
//  Secrets dans le Keychain (kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly), préférences non
//  sensibles dans UserDefaults (design D5). Purge de la configuration v1 en clair.
//

import Foundation
import Security

struct KeychainPersistence: SessionPersistence {
    /// Configuration v1 (mot de passe WAN compris) stockée en clair dans UserDefaults.
    static let legacyConfigKey = "essensys_connection_config"

    var service = "fr.essensys.iphone.session"
    /// Suite UserDefaults (nil = standard). UserDefaults n'est pas Sendable : on stocke le nom.
    var suiteName: String?
    private var defaults: UserDefaults { suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard }

    private enum Key: String {
        case token, lanCookie = "lan_cookie", pinnedCert = "pinned_lan_cert"
    }
    private enum Pref: String {
        case mode = "essensys.mode", lanHost = "essensys.lan_host", theme = "essensys.theme"
        case testMode = "essensys.test_mode", passwordChange = "essensys.password_change_required"
    }

    /// Supprime la configuration v1 ; retourne vrai si des identifiants en clair existaient.
    @discardableResult
    func purgeLegacy() -> Bool {
        let existed = defaults.object(forKey: Self.legacyConfigKey) != nil
        defaults.removeObject(forKey: Self.legacyConfigKey)
        return existed
    }

    func load() -> SessionState {
        var state = SessionState()
        state.mode = defaults.string(forKey: Pref.mode.rawValue).flatMap(ConnectionMode.init(rawValue:)) ?? .cloud
        state.lanHost = defaults.string(forKey: Pref.lanHost.rawValue) ?? Hosts.lanDefault
        state.theme = defaults.string(forKey: Pref.theme.rawValue).flatMap(ThemePreference.init(rawValue:)) ?? .system
        state.testMode = defaults.bool(forKey: Pref.testMode.rawValue)
        state.passwordChangeRequired = defaults.bool(forKey: Pref.passwordChange.rawValue)
        state.token = read(.token).flatMap { String(data: $0, encoding: .utf8) }
        state.lanCookie = read(.lanCookie).flatMap { String(data: $0, encoding: .utf8) }
        state.pinnedLanCertificate = read(.pinnedCert)
        return state
    }

    func save(_ state: SessionState) {
        defaults.set(state.mode.rawValue, forKey: Pref.mode.rawValue)
        defaults.set(state.lanHost, forKey: Pref.lanHost.rawValue)
        defaults.set(state.theme.rawValue, forKey: Pref.theme.rawValue)
        defaults.set(state.testMode, forKey: Pref.testMode.rawValue)
        defaults.set(state.passwordChangeRequired, forKey: Pref.passwordChange.rawValue)
        write(.token, state.token.map { Data($0.utf8) })
        write(.lanCookie, state.lanCookie.map { Data($0.utf8) })
        write(.pinnedCert, state.pinnedLanCertificate)
    }

    private func query(_ key: Key) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: key.rawValue]
    }

    private func read(_ key: Key) -> Data? {
        var q = query(key)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        return SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess ? out as? Data : nil
    }

    private func write(_ key: Key, _ value: Data?) {
        SecItemDelete(query(key) as CFDictionary)
        guard let value else { return }
        var q = query(key)
        q[kSecValueData as String] = value
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(q as CFDictionary, nil)
    }
}
