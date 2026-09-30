import SwiftUI

struct WordSearchHeaderBox: View {
    let verseRef: String
    let verseText: String
    let isFavorited: Bool
    let onToggleFavorite: () -> Void
    let timerTint: Color?

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Word Search").font(.headline)
                    Spacer()
                }
                if !verseRef.isEmpty {
                    HStack(spacing: 8) {
                        Text(verseRef).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                        Spacer()
                        Button(action: { onToggleFavorite() }) {
                            Image(systemName: isFavorited ? "heart.fill" : "heart").foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(isFavorited ? "Remove Favorite" : "Add to Favorites")
                    }
                }
                if !verseText.isEmpty {
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
