import Foundation

/// Where Continue Reading takes the reader. There are two places it could be:
/// - The bookmark: one exact verse the reader set on purpose, like a bookmark in a book.
/// - The reading position: the chapter the app saw them reading. It's tracked while scrolling,
///   so its verse is only approximate and is shown as "near verse N".
///
/// The bookmark is the more precise of the two, so it leads until the reader has since moved on
/// from it: to another chapter, or several verses away within the bookmarked chapter. Opening the
/// bookmark or scrolling a little doesn't count, so it isn't pushed aside. Once the reader moves
/// on, the reading position leads and the bookmark is offered beside it.
struct ContinueReadingTarget: Equatable {
    struct BookmarkPoint: Equatable {
        let bookName: String
        let chapterNumber: Int
        let verseNumber: Int
        let verseText: String
        let savedAt: Date
    }

    struct ReadingPoint: Equatable {
        let bookName: String
        let chapterNumber: Int
        /// The verse on screen when reading stopped; nil when only the chapter is known.
        let approximateVerse: Int?
        /// That verse's text, shown as an unnumbered preview so the passage is recognizable.
        let verseText: String
        let readAt: Date

        init(bookName: String, chapterNumber: Int, approximateVerse: Int?, verseText: String = "", readAt: Date) {
            self.bookName = bookName
            self.chapterNumber = chapterNumber
            self.approximateVerse = approximateVerse
            self.verseText = verseText
            self.readAt = readAt
        }
    }

    enum Primary: Equatable {
        case bookmark(BookmarkPoint)
        case reading(ReadingPoint)
    }

    /// How far from the bookmark, within its chapter, reading has to go to count as moving on.
    /// Small enough that reading a passage counts; large enough that scrolling around the
    /// bookmarked verse doesn't.
    static let versesToMoveOn = 5

    let primary: Primary
    /// The bookmark, when it's somewhere other than the primary place.
    let otherBookmark: BookmarkPoint?

    static func resolve(bookmark: BookmarkPoint?, reading: ReadingPoint?) -> ContinueReadingTarget? {
        switch (bookmark, reading) {
        case (nil, nil):
            return nil
        case let (bookmark?, nil):
            return ContinueReadingTarget(primary: .bookmark(bookmark), otherBookmark: nil)
        case let (nil, reading?):
            return ContinueReadingTarget(primary: .reading(reading), otherBookmark: nil)
        case let (bookmark?, reading?):
            let sameChapter = bookmark.bookName == reading.bookName && bookmark.chapterNumber == reading.chapterNumber
            let nearBookmark = sameChapter
                && abs((reading.approximateVerse ?? bookmark.verseNumber) - bookmark.verseNumber) < versesToMoveOn
            if nearBookmark || reading.readAt <= bookmark.savedAt {
                return ContinueReadingTarget(primary: .bookmark(bookmark), otherBookmark: nil)
            }
            return ContinueReadingTarget(primary: .reading(reading), otherBookmark: bookmark)
        }
    }

    /// The verse to open for the primary place: the bookmarked verse, or near where reading stopped.
    var destination: (bookName: String, chapterNumber: Int, verseNumber: Int) {
        switch primary {
        case .bookmark(let point):
            (point.bookName, point.chapterNumber, point.verseNumber)
        case .reading(let point):
            (point.bookName, point.chapterNumber, point.approximateVerse ?? 1)
        }
    }
}

extension ContinueReadingTarget.BookmarkPoint {
    init(_ bookmark: Bookmark) {
        self.init(
            bookName: bookmark.bookName,
            chapterNumber: bookmark.chapterNumber,
            verseNumber: bookmark.verseNumber,
            verseText: bookmark.verseText,
            savedAt: bookmark.createdAt
        )
    }
}

extension ContinueReadingTarget.ReadingPoint {
    /// Looks up the verse's text in the active translation, the same text the reader shows.
    @MainActor
    init(_ lastRead: BibleStatsStore.LastRead) {
        let text = BibleData.books
            .first { $0.name == lastRead.bookName }?
            .chapters.first { $0.number == lastRead.chapterNumber }?
            .verses.first { $0.number == (lastRead.verseNumber ?? 1) }?
            .text ?? ""
        self.init(
            bookName: lastRead.bookName,
            chapterNumber: lastRead.chapterNumber,
            approximateVerse: lastRead.verseNumber,
            verseText: text,
            readAt: lastRead.date
        )
    }
}

// MARK: - Widget

/// Works out Continue Reading for the widget, by the same rule as the Home card, and writes the
/// result to the app group. The widget only draws what's written, so the two always agree.
/// Runs whenever the bookmark or the reading position changes.
@MainActor
enum ContinueReadingWidgetMirror {
    static let bookmarkSavedAtKey = "bookmarkSavedAt"

    /// What the widget reads. `kind` is "bookmark" or "reading"; the `bookmark…` keys are the
    /// bookmark row shown beside a reading position.
    enum Key {
        static let kind = "continueReadingKind"
        static let book = "continueReadingBook"
        static let chapter = "continueReadingChapter"
        static let verse = "continueReadingVerse"
        static let text = "continueReadingText"
        static let translation = "continueReadingTranslation"
        static let bookmarkReference = "continueReadingBookmarkReference"
        static let bookmarkText = "continueReadingBookmarkText"
        static let all = [kind, book, chapter, verse, text, translation, bookmarkReference, bookmarkText]
    }

    private static let shared = UserDefaults(suiteName: "group.bible.app")

    static func update() {
        guard let shared else { return }

        let target = ContinueReadingTarget.resolve(
            bookmark: storedBookmark(in: shared),
            reading: ReadingPositionStore.shared.current.map(ContinueReadingTarget.ReadingPoint.init)
        )

        guard let target else {
            Key.all.forEach { shared.removeObject(forKey: $0) }
            DebouncedWidgetReloader.shared.reload(kind: "LastReadWidget")
            return
        }

        switch target.primary {
        case .bookmark(let point):
            shared.set("bookmark", forKey: Key.kind)
            shared.set(point.bookName, forKey: Key.book)
            shared.set(point.chapterNumber, forKey: Key.chapter)
            shared.set(point.verseNumber, forKey: Key.verse)
            shared.set(point.verseText, forKey: Key.text)
            // The bookmark keeps the translation it was saved in.
            shared.set(shared.string(forKey: AppStorageKey.bookmarkTranslation) ?? "kjv", forKey: Key.translation)
        case .reading(let point):
            shared.set("reading", forKey: Key.kind)
            shared.set(point.bookName, forKey: Key.book)
            shared.set(point.chapterNumber, forKey: Key.chapter)
            shared.set(point.approximateVerse ?? 1, forKey: Key.verse)
            // The reading position's verse text, copied by `ReadingPositionStore` in the active translation.
            shared.set(shared.string(forKey: AppStorageKey.lastReadText) ?? "", forKey: Key.text)
            shared.set(shared.string(forKey: "bibleTranslation") ?? "kjv", forKey: Key.translation)
        }

        if let bookmark = target.otherBookmark {
            shared.set("\(bookmark.bookName) \(bookmark.chapterNumber):\(bookmark.verseNumber)", forKey: Key.bookmarkReference)
            shared.set(bookmark.verseText, forKey: Key.bookmarkText)
        } else {
            shared.removeObject(forKey: Key.bookmarkReference)
            shared.removeObject(forKey: Key.bookmarkText)
        }
        DebouncedWidgetReloader.shared.reload(kind: "LastReadWidget")
    }

    private static func storedBookmark(in shared: UserDefaults) -> ContinueReadingTarget.BookmarkPoint? {
        guard let book = shared.string(forKey: AppStorageKey.bookmarkBook), !book.isEmpty else { return nil }
        let chapter = shared.integer(forKey: AppStorageKey.bookmarkChapter)
        let verse = shared.integer(forKey: AppStorageKey.bookmarkVerse)
        guard chapter > 0, verse > 0 else { return nil }
        return ContinueReadingTarget.BookmarkPoint(
            bookName: book,
            chapterNumber: chapter,
            verseNumber: verse,
            verseText: shared.string(forKey: AppStorageKey.bookmarkText) ?? "",
            // A copy from before dates were kept counts as old, so newer reading leads.
            savedAt: shared.object(forKey: bookmarkSavedAtKey) as? Date ?? .distantPast
        )
    }
}
