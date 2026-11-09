import Foundation

/// Where Continue Reading takes the reader. There are two places it could be:
/// - The bookmark: one exact verse the reader set on purpose, like a bookmark in a book.
/// - The reading position: the chapter the app saw them reading. It's tracked while scrolling,
///   so its verse is only approximate and is shown as "near verse N".
///
/// The bookmark is the more precise of the two, so it leads unless the reader has since read
/// a different chapter. Reading within the bookmarked chapter keeps the bookmark in front, since
/// opening it or scrolling a little shouldn't push it aside. Once the reader moves on, the
/// reading position leads and the bookmark is offered beside it.
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
        let readAt: Date
    }

    enum Primary: Equatable {
        case bookmark(BookmarkPoint)
        case reading(ReadingPoint)
    }

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
            if sameChapter || reading.readAt <= bookmark.savedAt {
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
    init(_ lastRead: BibleStatsStore.LastRead) {
        self.init(
            bookName: lastRead.bookName,
            chapterNumber: lastRead.chapterNumber,
            approximateVerse: lastRead.verseNumber,
            readAt: lastRead.date
        )
    }
}
