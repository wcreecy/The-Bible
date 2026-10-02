import SwiftUI

struct ResumeReadingCard: View {
    let progress: ReadingProgress?
    let verseText: String?
    let usesCompactLayout: Bool
    let onOpenReference: (ReadingProgress) -> Void

    var body: some View {
        if let progress {
            Button(action: { onOpenReference(progress) }) {
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
                            Text("\(progress.bookName) \(progress.chapterNumber):\(progress.verseNumber)")
                                .font(.system(size: 17, weight: .semibold))
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
                            Text("\(progress.bookName) \(progress.chapterNumber):\(progress.verseNumber)")
                                .font(.system(size: 17, weight: .semibold))
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
                VStack(alignment: .leading, spacing: 6) {
                    Text("Start reading from the Bible tab")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
