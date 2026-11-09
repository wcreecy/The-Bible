import SwiftUI

struct ResumeReadingCard: View {
    /// Where Continue Reading goes, from the bookmark and the reading position. Debug previews
    /// provide an in-memory value here.
    let target: ContinueReadingTarget?
    let usesCompactLayout: Bool
    /// Opens a book, chapter and verse.
    let onOpen: (String, Int, Int) -> Void
    let onStartReading: () -> Void
    let onChoosePassage: (String, Int, Int) -> Void

    @State private var showsScripturePicker = false

    var body: some View {
        Group {
            if let target {
                HeroCard(
                    title: "",
                    subtitle: nil,
                    icon: nil,
                    tint: .blue
                ) {
                    VStack(alignment: .leading, spacing: usesCompactLayout ? 10 : 12) {
                        Button {
                            let destination = target.destination
                            onOpen(destination.bookName, destination.chapterNumber, destination.verseNumber)
                        } label: {
                            primaryContent(target.primary)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if let bookmark = target.otherBookmark {
                            Divider()
                            bookmarkRow(bookmark)
                        }
                    }
                }
            } else {
                HeroCard(
                    title: "",
                    subtitle: nil,
                    icon: nil,
                    tint: .blue
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        Button(action: onStartReading) {
                            HStack(alignment: .center, spacing: 12) {
                                Image(systemName: "book.fill")
                                    .font(.title3)
                                    .foregroundStyle(Color.accentColor)
                                Text("Start with Genesis")
                                    .font(.headline)
                                    .bold()
                                Spacer()
                                Image(systemName: "arrow.right")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .accessibilityHidden(true)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Text("Begin at Genesis 1, or choose another passage.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Button("Choose a passage") {
                            showsScripturePicker = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
        .sheet(isPresented: $showsScripturePicker) {
            NavigationStack {
                ScripturePickerView(
                    initialBook: "Genesis",
                    initialChapter: 1,
                    initialVerse: 1
                ) { bookName, chapterNumber, verseNumber in
                    onChoosePassage(bookName, chapterNumber, verseNumber)
                }
            }
        }
    }

    // MARK: - Primary place

    @ViewBuilder
    private func primaryContent(_ primary: ContinueReadingTarget.Primary) -> some View {
        // The chevron sits beside the whole block, centered like the bookmark row's, so the two
        // line up. It stays blue as the card's main action; the bookmark row's is gray.
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: usesCompactLayout ? 4 : 6) {
                HStack(spacing: 8) {
                    Image(systemName: primary.isBookmark ? "bookmark.fill" : "book.fill")
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)
                    Text("Continue Reading")
                        .font(.headline)
                        .bold()
                }

                switch primary {
                case .bookmark(let point):
                    // The bookmark is exact, so it shows its verse and text.
                    HStack(spacing: 0) {
                        Text("\(point.bookName) \(point.chapterNumber):\(point.verseNumber)")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .layoutPriority(1)

                        if !point.verseText.isEmpty {
                            Text(" “\(point.verseText)”")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }
                    Text(ResumeReadingRecency.text(for: point.savedAt, kind: .bookmarked))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                case .reading(let point):
                    // The reading position is approximate, so it names only the chapter. The verse
                    // text is an unnumbered preview, so the passage is recognizable without
                    // claiming an exact verse. Opening it still scrolls near where reading stopped.
                    HStack(spacing: 0) {
                        Text("\(point.bookName) \(point.chapterNumber)")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .layoutPriority(1)

                        if !point.verseText.isEmpty {
                            Text(" “\(point.verseText)”")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }
                    Text(ResumeReadingRecency.text(for: point.readAt, kind: .read))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
        }
    }

    /// The bookmark, offered under the reading position when the reader has moved on from it.
    private func bookmarkRow(_ bookmark: ContinueReadingTarget.BookmarkPoint) -> some View {
        Button {
            onOpen(bookmark.bookName, bookmark.chapterNumber, bookmark.verseNumber)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "bookmark.fill")
                    .foregroundStyle(Color.accentColor)
                // The reference always shows in full; the verse text fills the rest of the line.
                Text("\(bookmark.bookName) \(bookmark.chapterNumber):\(bookmark.verseNumber)")
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .layoutPriority(1)
                if !bookmark.verseText.isEmpty {
                    Text("“\(bookmark.verseText)”")
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .font(.subheadline)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open bookmark, \(bookmark.bookName) \(bookmark.chapterNumber):\(bookmark.verseNumber)")
    }
}

private extension ContinueReadingTarget.Primary {
    var isBookmark: Bool {
        if case .bookmark = self { return true }
        return false
    }
}

enum ResumeReadingRecency {
    enum Kind {
        /// When the bookmark was set.
        case bookmarked
        /// When the reader was last in the chapter.
        case read
    }

    static func text(for date: Date, kind: Kind = .bookmarked, now: Date = .now, calendar: Calendar = .current) -> String {
        let time = date.formatted(date: .omitted, time: .shortened)
        let day = date.formatted(date: .abbreviated, time: .omitted)
        let isToday = calendar.isDate(date, inSameDayAs: now)
        let isYesterday = calendar.date(byAdding: .day, value: -1, to: now)
            .map { calendar.isDate(date, inSameDayAs: $0) } ?? false

        switch kind {
        case .bookmarked:
            if isToday { return String(localized: "Saved today at \(time)") }
            if isYesterday { return String(localized: "Saved yesterday") }
            return String(localized: "Saved \(day)")
        case .read:
            if isToday { return String(localized: "Read today at \(time)") }
            if isYesterday { return String(localized: "Read yesterday") }
            return String(localized: "Read \(day)")
        }
    }
}

#Preview("Bookmark") {
    ResumeReadingCard(
        target: .resolve(
            bookmark: .init(
                bookName: "Matthew", chapterNumber: 6, verseNumber: 9,
                verseText: "After this manner therefore pray ye: Our Father which art in heaven, Hallowed be thy name.",
                savedAt: .now
            ),
            reading: nil
        ),
        usesCompactLayout: true,
        onOpen: { _, _, _ in },
        onStartReading: {},
        onChoosePassage: { _, _, _ in }
    )
    .padding()
}

#Preview("Read on past the bookmark") {
    ResumeReadingCard(
        target: .resolve(
            bookmark: .init(
                bookName: "Psalms", chapterNumber: 23, verseNumber: 1,
                verseText: "The LORD is my shepherd; I shall not want.",
                savedAt: Calendar.current.date(byAdding: .day, value: -21, to: .now) ?? .now
            ),
            reading: .init(
                bookName: "John", chapterNumber: 4, approximateVerse: 13,
                verseText: "Jesus answered and said unto her, Whosoever drinketh of this water shall thirst again:",
                readAt: .now
            )
        ),
        usesCompactLayout: true,
        onOpen: { _, _, _ in },
        onStartReading: {},
        onChoosePassage: { _, _, _ in }
    )
    .padding()
}

#Preview("Nothing yet") {
    ResumeReadingCard(
        target: nil,
        usesCompactLayout: true,
        onOpen: { _, _, _ in },
        onStartReading: {},
        onChoosePassage: { _, _, _ in }
    )
    .padding()
}
