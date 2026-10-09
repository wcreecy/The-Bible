import SwiftUI

struct WrapWordsView: View {
    let words: [String]
    let found: Set<String>
    let revealed: Set<String>

    var body: some View {
        let columns = [GridItem(.adaptive(minimum: 80), spacing: 8)]
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(words, id: \.self) { w in
                WordChip(word: w, state: state(for: w))
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

    var body: some View {
        Text(word)
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule(style: .continuous).fill(fillColor))
            .overlay(Capsule(style: .continuous).stroke(strokeColor, lineWidth: 1))
            .foregroundStyle(.primary)
    }

    private var fillColor: Color {
        switch state {
        case .found: return Color.green.opacity(0.20)
        case .revealed: return Color.red.opacity(0.20)
        case .pending: return Color.accentColor.opacity(0.12)
        }
    }

    private var strokeColor: Color {
        switch state {
        case .found: return Color.green.opacity(0.60)
        case .revealed: return Color.red.opacity(0.60)
        case .pending: return Color.accentColor.opacity(0.35)
        }
    }
}
