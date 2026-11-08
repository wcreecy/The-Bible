import Foundation
import Testing
@testable import Bible

@MainActor
struct ResumeReadingRecencyTests {
    @Test
    func namesTodayAndYesterday() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!

        #expect(ResumeReadingRecency.text(for: now, now: now, calendar: calendar) == "Saved today")
        #expect(ResumeReadingRecency.text(for: yesterday, now: now, calendar: calendar) == "Saved yesterday")
    }

    @Test
    func recognizesAnOldSavedPassage() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let oldDate = calendar.date(byAdding: .day, value: -15, to: now)!

        #expect(ResumeReadingRecency.isOld(oldDate, now: now, calendar: calendar))
        #expect(!ResumeReadingRecency.isOld(now, now: now, calendar: calendar))
    }
}
