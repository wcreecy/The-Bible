import SwiftUI

struct ResumeReadingCard: View {
    /// Where reading stopped (see `ReadingPositionStore`).
    let position: BibleStatsStore.LastRead?
    let verseText: String?
    let usesCompactLayout: Bool
    let onOpenReference: (BibleStatsStore.LastRead) -> Void
    let onStartReading: () -> Void

    var body: some View {
        if let position {
            Button(action: { onOpenReference(position) }) {
                HeroCard(
                    title: "",
                    subtitle: nil,
                    icon: nil,
                    tint: .blue
                ) {
                    HStack(alignment: .center, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
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
                            Text("\(position.bookName) \(position.chapterNumber):\(position.verseNumber ?? 1)")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .layoutPriority(1)

                            if let verseText, !verseText.isEmpty {
                                Text("“\(verseText)”")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(position.bookName) \(position.chapterNumber):\(position.verseNumber ?? 1)")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.primary)

                            if let verseText, !verseText.isEmpty {
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
