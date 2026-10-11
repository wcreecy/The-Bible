import SwiftUI

/// Colors for found Word Search words. Each word gets its own color, used for both its
/// grid cells and its chip in the word list. Blue and red are left out because they mark
/// the current selection and revealed words.
enum WordSearchPalette {
    static let colors: [Color] = [.green, .orange, .purple, .pink, .teal, .yellow, .indigo, .mint, .brown, .cyan]

    static func color(for index: Int?) -> Color {
        guard let index else { return .green }
        return colors[index % colors.count]
    }
}

struct WrapWordsView: View {
    let words: [String]
    let found: Set<String>
    let revealed: Set<String>
    let colorForWord: (String) -> Color

    var body: some View {
        let columns = [GridItem(.adaptive(minimum: 80), spacing: 8)]
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(words, id: \.self) { w in
                WordChip(word: w, state: state(for: w), foundColor: colorForWord(w))
            }
        }
    }

    private func state(for word: String) -> WordChip.State {
        if found.contains(word) { return .found }
        if revealed.contains(word) { return .revealed }
        return .pending
    }
}

/// A capsule-styled word label colored by whether the word was found, revealed, or is still pending.
/// Colors are resolved in explicitly typed helpers to keep SwiftUI type-checking fast.
struct WordChip: View {
    enum State {
        case found, revealed, pending
    }

    let word: String
    let state: State
    /// The word's own color, used once it's found.
    var foundColor: Color = .green

    var body: some View {
        Text(word)
            .font(.footnote.weight(.semibold))
            .strikethrough(state == .found)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule(style: .continuous).fill(fillColor))
            .overlay(Capsule(style: .continuous).stroke(strokeColor, lineWidth: 1))
            .foregroundStyle(.primary)
            .accessibilityValue(accessibilityState)
    }

    private var fillColor: Color {
        switch state {
        case .found: return foundColor.opacity(0.30)
        case .revealed: return Color.red.opacity(0.20)
        case .pending: return Color.accentColor.opacity(0.12)
        }
    }

    private var strokeColor: Color {
        switch state {
        case .found: return foundColor.opacity(0.70)
        case .revealed: return Color.red.opacity(0.60)
        case .pending: return Color.accentColor.opacity(0.35)
        }
    }

    private var accessibilityState: String {
        switch state {
        case .found: return "Found"
        case .revealed: return "Revealed"
        case .pending: return "Not found yet"
        }
    }
}
