import SwiftUI

struct WordSearchHeaderBox: View {
    let verseRef: String
    let verseText: String
    /// Blind rounds show only the reference, since the verse would give away the words.
    let hidesVerseText: Bool
    let isFavorited: Bool
    let onToggleFavorite: () -> Void
    let timerTint: Color?

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                if !verseRef.isEmpty {
                    HStack(spacing: 8) {
                        Text(verseRef).font(.headline).lineLimit(1)
                        Spacer()
                        Button(action: { onToggleFavorite() }) {
                            Image(systemName: isFavorited ? "heart.fill" : "heart").foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(isFavorited ? "Remove Favorite" : "Add to Favorites")
                    }
                }
                if hidesVerseText {
                    Label("The verse appears when you finish.", systemImage: "eye.slash")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else if !verseText.isEmpty {
                    Text("“\(verseText)”")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    timerTint ?? Color.primary.opacity(0.12),
                    lineWidth: timerTint == nil ? 1 : 2
                )
        )
    }
}
