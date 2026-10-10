//
//  Theme.swift
//  Charte du portail (tokens de essensys-user-portal-frontend/src/index.css), identique à Theme.kt.
//  Spec portal-theme : aucune couleur codée en dur hors de ce fichier.
//

import SwiftUI

struct EssensysColors: Equatable, Sendable {
    let primary, primaryDark, secondary, danger, success, warning: Color
    let background, card, cardHeader, border, text, textMuted: Color

    static let light = EssensysColors(
        primary: Color(hex: 0x2563EB), primaryDark: Color(hex: 0x1D4ED8), secondary: Color(hex: 0x64748B),
        danger: Color(hex: 0xDC2626), success: Color(hex: 0x16A34A), warning: Color(hex: 0xF59E0B),
        background: Color(hex: 0xF8F8F8), card: Color(hex: 0xFFFFFF), cardHeader: Color(hex: 0xF9FAFB),
        border: Color(hex: 0xE2E8F0), text: Color(hex: 0x111827), textMuted: Color(hex: 0x6B7280))

    static let dark = EssensysColors(
        primary: Color(hex: 0x3B82F6), primaryDark: Color(hex: 0x60A5FA), secondary: Color(hex: 0x94A3B8),
        danger: Color(hex: 0xDC2626), success: Color(hex: 0x16A34A), warning: Color(hex: 0xF59E0B),
        background: Color(hex: 0x0F172A), card: Color(hex: 0x1E293B), cardHeader: Color(hex: 0x334155),
        border: Color(hex: 0x475569), text: Color(hex: 0xF1F5F9), textMuted: Color(hex: 0x94A3B8))
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255, opacity: 1)
    }
}

/// Formes du portail : boutons `rounded-lg` (8 pt), cartes `rounded-xl` (12 pt).
enum Radius {
    static let button: CGFloat = 8
    static let card: CGFloat = 12
}

private struct EssensysColorsKey: EnvironmentKey {
    static let defaultValue = EssensysColors.light
}

extension EnvironmentValues {
    var essensys: EssensysColors {
        get { self[EssensysColorsKey.self] }
        set { self[EssensysColorsKey.self] = newValue }
    }
}

extension ThemePreference {
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// Applique la charte selon la préférence et l'apparence système.
struct EssensysThemed: ViewModifier {
    let preference: ThemePreference
    @Environment(\.colorScheme) private var systemScheme

    func body(content: Content) -> some View {
        let dark = (preference.colorScheme ?? systemScheme) == .dark
        content
            .environment(\.essensys, dark ? .dark : .light)
            .preferredColorScheme(preference.colorScheme)
            .tint(dark ? EssensysColors.dark.primary : EssensysColors.light.primary)
    }
}
