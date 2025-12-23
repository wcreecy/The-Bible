import SwiftUI
import Charts

// MARK: - Shared tiny components

struct MetricChip: View {
    let title: String
    let value: String
    let tint: Color

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

struct LabeledValue: View {
    let text: String
    let isBest: Bool
    let isWorst: Bool

    var body: some View {
        HStack(spacing: 4) {
            if isBest {
                Image(systemName: "arrow.up.right")
                    .foregroundStyle(.green)
            } else if isWorst {
                Image(systemName: "arrow.down.right")
                    .foregroundStyle(.red)
            }
            Text(text)
                .font(.footnote)
                .monospacedDigit()
                .foregroundStyle(isBest ? .green : (isWorst ? .red : .primary))
        }
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
                .font(.headline)
                .symbolRenderingMode(.hierarchical)
                .padding(8)
        }
        .buttonStyle(.plain)
        .background(.ultraThinMaterial, in: Circle())
        .overlay(
            Circle().stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 1)
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
