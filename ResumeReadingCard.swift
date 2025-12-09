import SwiftUI

struct ResumeReadingCard: View {
    let progress: ReadingProgress?
    let onOpenReference: (ReadingProgress) -> Void

    var body: some View {
        if let progress {
            let verseText: String? = {
                if let book = BibleData.books.first(where: { $0.name == progress.bookName }),
                   let chapter = book.chapters.first(where: { $0.number == progress.chapterNumber }) {
                    return chapter.verses.first(where: { $0.number == progress.verseNumber })?.text
                }
                return nil
            }()

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
                                .foregroundStyle(.blue)
                            Text("Continue Reading")
                                .font(.headline)
                                .bold()
                        }
                        Spacer()
                    }

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
                            .foregroundStyle(.blue)
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
