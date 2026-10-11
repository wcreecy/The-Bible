import SwiftUI

/// End-of-round summary: how it went, plus the full verse the puzzle came from.
struct WordSearchSummaryCard: View {
    let result: WordSearchViewModel.RoundResult
    let foundCount: Int
    let totalCount: Int
    let elapsed: String
    let hintsUsed: Int
    /// Nil outside Blind mode; otherwise whether the word list was shown.
    let usedWordList: Bool?
    let verseRef: String
    let verseText: String
    let onReadInContext: () -> Void

    private var title: LocalizedStringResource {
        switch result {
        case .won: totalCount == 1 ? "You found the word!" : "You found all \(totalCount) words!"
        case .timeUp: "Time’s up!"
        case .revealed: "Words revealed"
        }
    }

    private var tint: Color {
        switch result {
        case .won: .green
        case .timeUp: .red
        case .revealed: .secondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(tint)

            HStack(spacing: 10) {
                stat("Time", value: elapsed, systemImage: "clock")
                stat("Found", value: "\(foundCount)/\(totalCount)", systemImage: "checkmark.circle")
                stat("Hints", value: "\(hintsUsed)", systemImage: "lightbulb")
                if let usedWordList {
                    stat("Word List", value: usedWordList ? "Used" : "Hidden", systemImage: "eye.slash")
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text(verseRef)
                    .font(.headline)
                Text("“\(verseText)”")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button("Read in Context", systemImage: "book", action: onReadInContext)
                .buttonStyle(ModernPillButtonStyle(tint: .accentColor))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }

    private func stat(_ label: LocalizedStringResource, value: String, systemImage: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.monospacedDigit())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}
