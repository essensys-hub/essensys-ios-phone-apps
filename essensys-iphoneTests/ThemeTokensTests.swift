import SwiftUI
import Testing
import UIKit
@testable import essensys_iphone

/// Les tokens doivent rester identiques au portail (src/index.css) et à Theme.kt (Android).
struct ThemeTokensTests {
    private func hex(_ color: Color) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(round(r * 255)), Int(round(g * 255)), Int(round(b * 255)))
    }

    @Test func light_tokens_match_portal() {
        #expect(hex(EssensysColors.light.primary) == "#2563EB")
        #expect(hex(EssensysColors.light.background) == "#F8F8F8")
        #expect(hex(EssensysColors.light.border) == "#E2E8F0")
        #expect(hex(EssensysColors.light.text) == "#111827")
    }

    @Test func dark_tokens_match_portal() {
        #expect(hex(EssensysColors.dark.background) == "#0F172A")
        #expect(hex(EssensysColors.dark.card) == "#1E293B")
        #expect(hex(EssensysColors.dark.primary) == "#3B82F6")
    }

    @Test func theme_preference_maps_to_color_scheme() {
        #expect(ThemePreference.system.colorScheme == nil)
        #expect(ThemePreference.light.colorScheme == .light)
        #expect(ThemePreference.dark.colorScheme == .dark)
    }
}
