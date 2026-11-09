import Foundation
import Testing
@testable import Bible

/// Where Continue Reading goes: the exact bookmark, or the chapter last read once the reader
/// has moved on from it.
struct ContinueReadingTargetTests {
    private let earlier = Date(timeIntervalSinceReferenceDate: 1_000)
    private let later = Date(timeIntervalSinceReferenceDate: 2_000)

    private func bookmark(_ book: String, _ chapter: Int, _ verse: Int, at date: Date) -> ContinueReadingTarget.BookmarkPoint {
        .init(bookName: book, chapterNumber: chapter, verseNumber: verse, verseText: "", savedAt: date)
    }

    private func reading(_ book: String, _ chapter: Int, near verse: Int?, at date: Date) -> ContinueReadingTarget.ReadingPoint {
        .init(bookName: book, chapterNumber: chapter, approximateVerse: verse, readAt: date)
    }

    @Test func nothingSavedHasNoTarget() {
        #expect(ContinueReadingTarget.resolve(bookmark: nil, reading: nil) == nil)
    }

    @Test func aBookmarkAloneIsTheTarget() {
        let mark = bookmark("Psalms", 23, 1, at: earlier)
        let target = ContinueReadingTarget.resolve(bookmark: mark, reading: nil)
        #expect(target?.primary == .bookmark(mark))
        #expect(target?.otherBookmark == nil)
        #expect(target?.destination.verseNumber == 1)
    }

    @Test func readingAloneOpensNearWhereReadingStopped() {
        let place = reading("John", 4, near: 12, at: earlier)
        let target = ContinueReadingTarget.resolve(bookmark: nil, reading: place)
        #expect(target?.primary == .reading(place))
        #expect(target?.destination.verseNumber == 12)
    }

    @Test func readingInTheBookmarkedChapterKeepsTheBookmarkInFront() {
        // Opening the bookmark, or scrolling a little, updates the reading position. That
        // shouldn't push aside the exact verse the reader marked.
        let mark = bookmark("John", 3, 16, at: earlier)
        let target = ContinueReadingTarget.resolve(bookmark: mark, reading: reading("John", 3, near: 20, at: later))
        #expect(target?.primary == .bookmark(mark))
        #expect(target?.otherBookmark == nil)
    }

    @Test func movingOnToAnotherChapterLeadsWithItAndKeepsTheBookmarkBeside() {
        let mark = bookmark("Psalms", 23, 1, at: earlier)
        let place = reading("John", 4, near: 12, at: later)
        let target = ContinueReadingTarget.resolve(bookmark: mark, reading: place)
        #expect(target?.primary == .reading(place))
        #expect(target?.otherBookmark == mark)
    }

    @Test func aBookmarkSetAfterReadingElsewhereLeads() {
        let mark = bookmark("Psalms", 23, 1, at: later)
        let target = ContinueReadingTarget.resolve(bookmark: mark, reading: reading("John", 4, near: 12, at: earlier))
        #expect(target?.primary == .bookmark(mark))
        #expect(target?.otherBookmark == nil)
    }

    @Test func readingWithOnlyAChapterOpensAtItsStart() {
        let target = ContinueReadingTarget.resolve(bookmark: nil, reading: reading("Ruth", 2, near: nil, at: earlier))
        #expect(target?.destination.verseNumber == 1)
    }

    @Test func recencyWordingMatchesThePlace() {
        let now = Date()
        #expect(ResumeReadingRecency.text(for: now, kind: .bookmarked, now: now).hasPrefix("Saved today at "))
        #expect(ResumeReadingRecency.text(for: now, kind: .read, now: now).hasPrefix("Read today at "))
    }
}
