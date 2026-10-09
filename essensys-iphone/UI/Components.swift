//
//  Components.swift
//  Composants du portail (ControlCard, ActionButton, badges) — spec portal-theme « Composants alignés ».
//

import SwiftUI

struct EssensysCard<Content: View>: View {
    let title: String
    var description: String?
    @ViewBuilder let content: Content
    @Environment(\.essensys) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline).foregroundStyle(colors.text)
                if let description { Text(description).font(.caption).foregroundStyle(colors.textMuted) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(colors.cardHeader)
            VStack(alignment: .leading, spacing: 10) { content }
                .padding(16)
        }
        .background(colors.card)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        .overlay(RoundedRectangle(cornerRadius: Radius.card).stroke(colors.border, lineWidth: 1))
    }
}

enum Tone { case primary, secondary, danger }

struct ActionButton: View {
    let label: String
    var tone: Tone = .primary
    var loading = false
    var enabled = true
    var compact = false
    let action: () -> Void
    @Environment(\.essensys) private var colors

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if loading { ProgressView().controlSize(.small).tint(tone == .secondary ? colors.primary : .white) }
                Text(label).lineLimit(1).font(compact ? .subheadline.weight(.medium) : .body.weight(.medium))
            }
            .padding(.horizontal, compact ? 12 : 16).padding(.vertical, compact ? 8 : 11)
            .frame(maxWidth: compact ? nil : .infinity)
            .foregroundStyle(tone == .secondary ? colors.text : .white)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: Radius.button))
            .overlay(RoundedRectangle(cornerRadius: Radius.button).stroke(tone == .secondary ? colors.border : .clear, lineWidth: 1))
            .opacity(enabled && !loading ? 1 : 0.5)
        }
        .buttonStyle(.plain)
        .disabled(!enabled || loading)
    }

    private var background: Color {
        switch tone {
        case .primary: colors.primary
        case .secondary: colors.card
        case .danger: colors.danger
        }
    }
}

struct StatusPill: View {
    let text: String
    let color: Color
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text).font(.caption.weight(.medium)).foregroundStyle(color)
        }
        .padding(.horizontal, 10).padding(.vertical, 4)
        .background(color.opacity(0.12), in: Capsule())
    }
}

struct Feedback: Equatable {
    enum Kind { case success, error, info }
    let text: String
    let kind: Kind
}

struct FeedbackBanner: View {
    let feedback: Feedback?
    @Environment(\.essensys) private var colors

    var body: some View {
        if let feedback {
            let color: Color = switch feedback.kind {
            case .success: colors.success
            case .error: colors.danger
            case .info: colors.primary
            }
            Text(feedback.text)
                .font(.subheadline).foregroundStyle(color)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: Radius.button))
                .overlay(RoundedRectangle(cornerRadius: Radius.button).stroke(color.opacity(0.4), lineWidth: 1))
                .accessibilityIdentifier("feedback")
        }
    }
}

/// Colonne défilante centrée, de l'iPhone SE au Pro Max (spec portal-theme « Petit écran »).
struct ScreenColumn<Content: View>: View {
    @ViewBuilder let content: Content
    @Environment(\.essensys) private var colors
    var body: some View {
        ScrollView {
            VStack(spacing: 16) { content }
                .frame(maxWidth: 720)
                .padding(16)
                .frame(maxWidth: .infinity)
        }
        .background(colors.background)
    }
}
