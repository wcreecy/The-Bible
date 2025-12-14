import SwiftUI

struct WrapWordsView: View {
    let words: [String]
    let found: Set<String>
    let revealed: Set<String>

    var body: some View {
        let columns = [GridItem(.adaptive(minimum: 80), spacing: 8)]
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(words, id: \.self) { w in
                let isFound = found.contains(w)
                let isRevealed = !isFound && revealed.contains(w)
                Text(w)
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(isFound ? Color.green.opacity(0.20) : (isRevealed ? Color.red.opacity(0.20) : Color.accentColor.opacity(0.12)))
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(isFound ? Color.green.opacity(0.60) : (isRevealed ? Color.red.opacity(0.60) : Color.accentColor.opacity(0.35)), lineWidth: 1)
                    )
                    .foregroundStyle(.primary)
            }
        }
    }
}
