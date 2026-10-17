import Foundation
import Testing
@testable import Bible

@MainActor
struct SavedVersesHomeCardTests {
    private let calendar = SavedVerseHomePreview.synchronizedRotationCalendar

    private func date(_ day: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day)) ?? .distantPast
    }

    private func preview(
        _ reference: String,
        day: Int,
        kind: SavedVerseHomePreview.Kind = .favorite
    ) -> SavedVerseHomePreview {
        SavedVerseHomePreview(
            reference: reference,
            text: "Verse text",
            kind: kind,
            date: date(day),
            bookName: "John",
            chapterNumber: 3,
            verseNumber: 16,
            highlightColor: nil
        )
    }

    @Test
    func emptyCollectionHasNoDailyPreview() {
        #expect(SavedVerseHomePreview.dailyPreview(from: [], on: date(10)) == nil)
        #expect(SavedVerseHomePreview.dailyIndex(itemCount: 0, on: date(10)) == nil)
    }

    @Test
    func singleSavedVerseIsShown() {
        let onlyVerse = preview("John 3:16", day: 1)

        #expect(SavedVerseHomePreview.dailyPreview(from: [onlyVerse], on: date(10)) == onlyVerse)
    }

    @Test
    func newestSavedVerseIsExcludedWhenOlderVersesExist() {
        let oldest = preview("John 3:16", day: 1)
        let newest = preview("John 3:17", day: 2)

        let selected = SavedVerseHomePreview.dailyPreview(
            from: [oldest, newest],
            on: date(10)
        )

        #expect(selected == oldest)
    }

    @Test
    func rotationIsStableForSyncedDevicesAndAdvancesOnTheNextUTCDay() {
        let previews = [
            preview("John 3:16", day: 1),
            preview("John 3:17", day: 2),
            preview("John 3:18", day: 3),
            preview("John 3:19", day: 4)
        ]

        let today = date(10)
        let firstDevice = SavedVerseHomePreview.dailyPreview(from: previews, on: today)
        let secondDevice = SavedVerseHomePreview.dailyPreview(from: previews, on: today)
        let tomorrow = SavedVerseHomePreview.dailyPreview(from: previews, on: date(11))

        #expect(calendar.timeZone.secondsFromGMT() == 0)
        #expect(firstDevice == secondDevice)
        #expect(firstDevice != tomorrow)
    }

    @Test
    func matchingTimestampsStillProduceAStableSelection() {
        let sameDate = date(1)
        let previews = [
            SavedVerseHomePreview(
                reference: "John 3:18",
                text: "Verse text",
                kind: .highlight,
                date: sameDate,
                bookName: "John",
                chapterNumber: 3,
                verseNumber: 18,
                highlightColor: nil
            ),
            SavedVerseHomePreview(
                reference: "John 3:16",
                text: "Verse text",
                kind: .favorite,
                date: sameDate,
                bookName: "John",
                chapterNumber: 3,
                verseNumber: 16,
                highlightColor: nil
            ),
            SavedVerseHomePreview(
                reference: "John 3:17",
                text: "Verse text",
                kind: .favorite,
                date: sameDate,
                bookName: "John",
                chapterNumber: 3,
                verseNumber: 17,
                highlightColor: nil
            )
        ]

        let selectedInOriginalOrder = SavedVerseHomePreview.dailyPreview(from: previews, on: date(10))
        let selectedInReverseOrder = SavedVerseHomePreview.dailyPreview(from: Array(previews.reversed()), on: date(10))

        #expect(selectedInOriginalOrder == selectedInReverseOrder)
    }

    @Test
    func rotationOffsetAdvancesToAnotherEligibleVerse() {
        let previews = [
            preview("John 3:16", day: 1),
            preview("John 3:17", day: 2),
            preview("John 3:18", day: 3),
            preview("John 3:19", day: 4)
        ]

        let defaultPreview = SavedVerseHomePreview.dailyPreview(from: previews, on: date(10))
        let refreshedPreview = SavedVerseHomePreview.dailyPreview(
            from: previews,
            on: date(10),
            rotationOffset: 1
        )

        #expect(defaultPreview != refreshedPreview)
    }

    @Test
    func subtitleUsesSingularAndPluralForms() {
        #expect(SavedVersesHomeCardSubtitle.text(favoriteCount: 1, highlightCount: 1) == "1 favorite · 1 highlight")
        #expect(SavedVersesHomeCardSubtitle.text(favoriteCount: 2, highlightCount: 0) == "2 favorites · 0 highlights")
    }
}
