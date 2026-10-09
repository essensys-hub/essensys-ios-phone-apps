//
//  essensys_iphoneTests.swift
//  essensys-iphoneTests
//

import Testing
@testable import essensys_iphone

/// Vérifie que la cible de tests unitaires se charge (tâche 1.2) ; les tests métier suivent par fichier.
struct SmokeTests {
    @Test func test_target_loads() {
        #expect(Bool(true))
    }
}
