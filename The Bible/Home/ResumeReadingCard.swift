import SwiftUI

struct ResumeReadingCard: View {
    /// The verse the reader bookmarked to come back to.
    let bookmark: Bookmark?
    let usesCompactLayout: Bool
    let onOpenReference: (Bookmark) -> Void
    let onStartReading: () -> Void

    var body: some View {
        if let bookmark {
            let verseText = bookmark.verseText
            Button(action: { onOpenReference(bookmark) }) {
                HeroCard(
                    title: "",
                    subtitle: nil,
                    icon: nil,
                    tint: .blue
                ) {
                    HStack(alignment: .center, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "bookmark.fill")
                                .font(.title3)
                                .foregroundStyle(Color.accentColor)
                            Text("Continue Reading")
                                .font(.headline)
                                .bold()
                        }
                        Spacer()
                    }

                    if usesCompactLayout {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("\(bookmark.bookName) \(bookmark.chapterNumber):\(bookmark.verseNumber)")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .layoutPriority(1)

                            if !verseText.isEmpty {
                                Text("“\(verseText)”")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(bookmark.bookName) \(bookmark.chapterNumber):\(bookmark.verseNumber)")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.primary)

                            if !verseText.isEmpty {
                                Text("“\(verseText)”")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                    .truncationMode(.tail)
                            }
                        }
                    }
                }
            }
            .buttonStyle(.plain)
        } else {
            Button(action: onStartReading) {
                HeroCard(
                    title: "",
                    subtitle: nil,
                    icon: nil,
                    tint: .blue
                ) {
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: "book.fill")
                            .font(.title3)
                            .foregroundStyle(Color.accentColor)
                        Text("Start Reading")
                            .font(.headline)
                            .bold()
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }

                    Text("Begin with Genesis 1")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens Genesis chapter 1 in the Bible reader")
        }
    }
}
