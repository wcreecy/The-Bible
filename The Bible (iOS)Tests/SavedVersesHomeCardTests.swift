import Foundation
import Testing
@testable import Bible

@MainActor
struct SavedVersesHomeCardTests {
    // A fixed calendar keeps day boundaries deterministic wherever the tests run.
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York") ?? calendar.timeZone
        return calendar
    }()

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
            verseNumber: Int(reference.split(separator: ":").last ?? "") ?? 16,
            highlightColor: nil
        )
    }

    @Test
    func emptyCollectionHasNoDailyPreview() {
        #expect(SavedVerseHomePreview.dailyPreview(from: [], on: date(10), calendar: calendar) == nil)
        #expect(SavedVerseHomePreview.dailyIndex(itemCount: 0, on: date(10), calendar: calendar) == nil)
    }

    @Test
    func singleSavedVerseIsShown() {
        let onlyVerse = preview("John 3:16", day: 1)

        #expect(SavedVerseHomePreview.dailyPreview(from: [onlyVerse], on: date(10), calendar: calendar) == onlyVerse)
    }

    @Test
    func newestSavedVerseIsExcludedWhenOlderVersesExist() {
        let oldest = preview("John 3:16", day: 1)
        let newest = preview("John 3:17", day: 2)

        let selected = SavedVerseHomePreview.dailyPreview(
            from: [oldest, newest],
            on: date(10),
            calendar: calendar
        )

        #expect(selected == oldest)
    }

    @Test
    func rotationIsStableWithinADayAndAdvancesOnTheNextDay() {
        let previews = [
            preview("John 3:16", day: 1),
            preview("John 3:17", day: 2),
            preview("John 3:18", day: 3),
            preview("John 3:19", day: 4)
        ]

        let today = date(10)
        let lateToday = today.addingTimeInterval(23 * 60 * 60)
        let morning = SavedVerseHomePreview.dailyPreview(from: previews, on: today, calendar: calendar)
        let evening = SavedVerseHomePreview.dailyPreview(from: previews, on: lateToday, calendar: calendar)
        let tomorrow = SavedVerseHomePreview.dailyPreview(from: previews, on: date(11), calendar: calendar)

        #expect(morning == evening)
        #expect(morning != tomorrow)
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

        let selectedInOriginalOrder = SavedVerseHomePreview.dailyPreview(from: previews, on: date(10), calendar: calendar)
        let selectedInReverseOrder = SavedVerseHomePreview.dailyPreview(from: Array(previews.reversed()), on: date(10), calendar: calendar)

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

        let defaultPreview = SavedVerseHomePreview.dailyPreview(from: previews, on: date(10), calendar: calendar)
        let refreshedPreview = SavedVerseHomePreview.dailyPreview(
            from: previews,
            on: date(10),
            calendar: calendar,
            rotationOffset: 1
        )

        #expect(defaultPreview != refreshedPreview)
    }

    @Test
    func newestHighlightIsExcludedWhenNewerThanEveryFavorite() {
        let favorite = preview("John 3:16", day: 1)
        let newestHighlight = preview("John 3:17", day: 2, kind: .highlight)

        for day in 10...13 {
            let selected = SavedVerseHomePreview.dailyPreview(
                from: [favorite, newestHighlight],
                on: date(day),
                calendar: calendar
            )
            #expect(selected == favorite)
        }
    }

    @Test
    func todaysPinnedVerseSurvivesNewSaves() throws {
        let previews = [
            preview("John 3:16", day: 1),
            preview("John 3:17", day: 2),
            preview("John 3:18", day: 3)
        ]
        let today = date(10)
        let picked = try #require(SavedVerseHomePreview.dailyPreview(from: previews, on: today, calendar: calendar))
        let pin = SavedVerseHomePreview.DailyPin(
            id: picked.pinID,
            day: SavedVerseHomePreview.dayIndex(for: today, calendar: calendar)
        )

        // Saving more verses changes the rotation's count, but not today's verse.
        let morePreviews = previews + [preview("John 3:19", day: 4), preview("John 3:20", day: 5)]
        for count in previews.count...morePreviews.count {
            let selected = SavedVerseHomePreview.dailyPreview(
                from: Array(morePreviews.prefix(count)),
                on: today,
                calendar: calendar,
                pinned: pin
            )
            #expect(selected == picked)
        }
    }

    @Test
    func pinIsIgnoredOnAnotherDayOrAfterItsVerseIsRemoved() throws {
        let previews = [
            preview("John 3:16", day: 1),
            preview("John 3:17", day: 2),
            preview("John 3:18", day: 3),
            preview("John 3:19", day: 4)
        ]
        let today = date(10)
        let todayIndex = SavedVerseHomePreview.dayIndex(for: today, calendar: calendar)
        let unpinned = SavedVerseHomePreview.dailyPreview(from: previews, on: today, calendar: calendar)
        let otherVerse = try #require(previews.first { $0 != unpinned })

        let yesterdaysPin = SavedVerseHomePreview.DailyPin(id: otherVerse.pinID, day: todayIndex - 1)
        #expect(SavedVerseHomePreview.dailyPreview(from: previews, on: today, calendar: calendar, pinned: yesterdaysPin) == unpinned)

        let removedPin = SavedVerseHomePreview.DailyPin(id: "favorite|John|3|99", day: todayIndex)
        #expect(SavedVerseHomePreview.dailyPreview(from: previews, on: today, calendar: calendar, pinned: removedPin) == unpinned)
    }

    @Test
    func favoriteAndHighlightOfTheSameVerseHaveDifferentPins() {
        let favorite = preview("John 3:16", day: 1)
        let highlight = preview("John 3:16", day: 1, kind: .highlight)

        #expect(favorite.pinID != highlight.pinID)
    }

    @Test
    func subtitleUsesSingularAndPluralForms() {
        #expect(SavedVersesHomeCardSubtitle.text(favoriteCount: 1, highlightCount: 1) == "1 favorite · 1 highlight")
        #expect(SavedVersesHomeCardSubtitle.text(favoriteCount: 2, highlightCount: 3) == "2 favorites · 3 highlights")
    }

    @Test
    func subtitleOmitsZeroCounts() {
        #expect(SavedVersesHomeCardSubtitle.text(favoriteCount: 3, highlightCount: 0) == "3 favorites")
        #expect(SavedVersesHomeCardSubtitle.text(favoriteCount: 0, highlightCount: 1) == "1 highlight")
        #expect(SavedVersesHomeCardSubtitle.text(favoriteCount: 0, highlightCount: 0) == nil)
    }
}
