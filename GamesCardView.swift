import SwiftUI

// MARK: - Shared tiny components

struct MetricChip: View {
    let title: String
    let value: String
    let tint: Color
    var fillsWidth: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.footnote.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: fillsWidth ? .infinity : nil, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(tint.opacity(0.25), lineWidth: 1)
        )
    }
}

// MARK: - Floating, icon-only play button used by the Overview card
struct GamesOverviewPlayButton: View {
    var openAction: (() -> Void)? = nil
    var selectedGame: String? = nil

    var body: some View {
        Button {
            openAction?()
        } label: {
            Image(systemName: "play.fill")
                .symbolRenderingMode(.hierarchical)
        }
        .buttonStyle(ModernCircleButtonStyle(tint: .accentColor, isProminent: true))
        .accessibilityLabel(
            Text(
                {
                    let name = selectedGame ?? "All Games"
                    return name == "All Games" ? "Open Games" : "Play \(name)"
                }()
            )
        )
        .accessibilityHint(selectedGame == "All Games" ? "Opens the Games list" : "Opens the selected game")
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            // GamesOverviewCardView now lives in GamesOverviewCardView.swift
            GamesOverviewCardView()
            PlayerStatSheetCardView()
        }
        .padding()
    }
}
