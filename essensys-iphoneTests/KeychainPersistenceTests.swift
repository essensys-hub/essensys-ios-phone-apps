import Foundation
import Testing
@testable import essensys_iphone

/// Stockage sécurisé et purge de la v1 (spec mobile-auth « Stockage sécurisé »).
@Suite(.serialized) struct KeychainPersistenceTests {
    private let suite = "essensys.tests.\(UUID().uuidString)"

    @Test func legacy_cleartext_credentials_are_purged() throws {
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.set(Data(#"{"mode":"wan","wanUsername":"u","wanPassword":"\#(UUID().uuidString)"}"#.utf8),
                     forKey: KeychainPersistence.legacyConfigKey)
        let persistence = KeychainPersistence(service: "essensys.tests.\(UUID().uuidString)", suiteName: suite)
        #expect(persistence.purgeLegacy())
        #expect(defaults.object(forKey: KeychainPersistence.legacyConfigKey) == nil)
        #expect(!persistence.purgeLegacy())
    }

    @Test func token_survives_reopen_and_is_cleared() {
        let persistence = KeychainPersistence(service: "essensys.tests.\(UUID().uuidString)", suiteName: suite)
        let store = SessionStore(persistence: persistence)
        store.update { $0.token = "jwt-secret-value"; $0.theme = .dark }
        let reopened = SessionStore(persistence: persistence)
        #expect(reopened.state.token == "jwt-secret-value")
        #expect(reopened.state.theme == .dark)
        // Le jeton n'est pas dans UserDefaults.
        let dump = UserDefaults(suiteName: suite)!.dictionaryRepresentation().description
        #expect(!dump.contains("jwt-secret-value"))
        reopened.clearSession()
        #expect(SessionStore(persistence: persistence).state.token == nil)
    }

    // MARK: Session mémorisée (session-30-jours-2026-11-001, tâche 1.1)

    @Test func remember_session_survives_reopen_is_not_in_defaults_and_is_cleared() throws {
        let persistence = KeychainPersistence(service: "essensys.tests.\(UUID().uuidString)", suiteName: suite)
        let store = SessionStore(persistence: persistence)
        let until = Date(timeIntervalSince1970: 1_800_000_000)
        store.update { $0.token = "jwt-access-value"; $0.rememberToken = "remember-secret-value"; $0.rememberExpiresAt = until }
        let reopened = SessionStore(persistence: persistence)
        #expect(reopened.state.rememberToken == "remember-secret-value")
        #expect(reopened.state.rememberExpiresAt == until)
        // Le secret est dans le Keychain, pas dans UserDefaults : seule la date l'est.
        let dump = UserDefaults(suiteName: suite)!.dictionaryRepresentation().description
        #expect(!dump.contains("remember-secret-value"))
        reopened.clearSession()
        let cleared = SessionStore(persistence: persistence).state
        #expect(cleared.rememberToken == nil)
        #expect(cleared.rememberExpiresAt == nil)
    }

    @Test func orphan_remember_session_is_purged_after_a_reinstall() throws {
        let service = "essensys.tests.\(UUID().uuidString)"
        let before = KeychainPersistence(service: service, suiteName: "essensys.tests.before.\(UUID().uuidString)")
        var state = SessionState()
        state.token = "jwt-access-value"; state.rememberToken = "remember-secret-value"
        state.rememberExpiresAt = Date(timeIntervalSince1970: 1_800_000_000)
        before.save(state)

        // Réinstallation : UserDefaults repart de zéro, le Keychain a gardé la session mémorisée.
        let reinstalled = KeychainPersistence(service: service, suiteName: "essensys.tests.after.\(UUID().uuidString)")
        let first = reinstalled.load()
        #expect(first.rememberToken == nil)
        #expect(first.rememberExpiresAt == nil)
        // Comme avant, le jeton d'accès n'est pas touché.
        #expect(first.token == "jwt-access-value")

        // Le secret a bien quitté le Keychain : même avec le marqueur déjà posé, il n'est plus là.
        let marked = "essensys.tests.marked.\(UUID().uuidString)"
        UserDefaults(suiteName: marked)!.set(true, forKey: "essensys.keychain_marker")
        #expect(KeychainPersistence(service: service, suiteName: marked).load().rememberToken == nil)
    }

    @Test func remember_session_is_kept_on_a_normal_relaunch() {
        let persistence = KeychainPersistence(service: "essensys.tests.\(UUID().uuidString)", suiteName: suite)
        let store = SessionStore(persistence: persistence)
        store.update { $0.token = "jwt"; $0.rememberToken = "remember-secret-value"; $0.rememberExpiresAt = Date(timeIntervalSince1970: 1_800_000_000) }
        for _ in 0..<2 { #expect(SessionStore(persistence: persistence).state.rememberToken == "remember-secret-value") }
    }

    @Test func lan_remember_expiry_survives_reopen_and_ends_with_the_session() {
        let persistence = KeychainPersistence(service: "essensys.tests.\(UUID().uuidString)", suiteName: suite)
        let until = Date(timeIntervalSince1970: 1_800_000_000)
        SessionStore(persistence: persistence).update { $0.mode = .lan; $0.lanCookie = "lan-cookie-value"; $0.rememberExpiresAt = until }
        let reopened = SessionStore(persistence: persistence)
        #expect(reopened.state.mode == .lan)
        #expect(reopened.state.lanCookie == "lan-cookie-value")
        #expect(reopened.state.rememberExpiresAt == until)
        #expect(reopened.state.rememberToken == nil)
        reopened.clearSession()
        let cleared = SessionStore(persistence: persistence).state
        #expect(cleared.lanCookie == nil)
        #expect(cleared.rememberExpiresAt == nil)
    }
}

