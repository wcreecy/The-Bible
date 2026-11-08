import Foundation
import Testing
@testable import Bible

@MainActor
struct ResumeReadingRecencyTests {
    @Test
    func namesTodayWithTimeAndYesterday() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!

        #expect(ResumeReadingRecency.text(for: now, now: now, calendar: calendar).hasPrefix("Saved today at "))
        #expect(ResumeReadingRecency.text(for: yesterday, now: now, calendar: calendar) == "Saved yesterday")
    }
}
