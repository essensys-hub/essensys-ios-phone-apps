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
}
