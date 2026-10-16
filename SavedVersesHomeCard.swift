import SwiftUI

struct SavedVerseHomePreview: Equatable {
    enum Kind: Equatable {
        case favorite
        case highlight

        var title: LocalizedStringResource {
            switch self {
            case .favorite: "Recently favorited"
            case .highlight: "Recently highlighted"
            }
        }
    }

    let reference: String
    let text: String
    let kind: Kind
    let date: Date
    let bookName: String
    let chapterNumber: Int
    let verseNumber: Int
}

struct SavedVersesHomeCard: View {
    let preview: SavedVerseHomePreview?
    let onOpenSavedVerses: () -> Void
    let onOpenVerse: (SavedVerseHomePreview) -> Void

    var body: some View {
        HeroCard(
            title: "Saved Verses",
            subtitle: "Return to the passages that matter to you",
            icon: "heart.text.clipboard",
            tint: .pink,
            trailingAccessory: {
                Button("View All", action: onOpenSavedVerses)
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.bordered)
            }
        ) {
            SavedVersesHomeCardContent(
                preview: preview,
                onOpenSavedVerses: onOpenSavedVerses,
                onOpenVerse: onOpenVerse
            )
        }
        .accessibilityElement(children: .contain)
    }
}

private struct SavedVersesHomeCardContent: View {
    let preview: SavedVerseHomePreview?
    let onOpenSavedVerses: () -> Void
    let onOpenVerse: (SavedVerseHomePreview) -> Void

    var body: some View {
        if let preview {
            Button {
                onOpenVerse(preview)
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(preview.kind.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(preview.reference)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text("“\(preview.text)”")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens this verse in the Bible")
        } else {
            Button(action: onOpenSavedVerses) {
                Label(
                    "Save verses and highlights to revisit them here.",
                    systemImage: "heart"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens Saved Verses")
        }
    }
}
