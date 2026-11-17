import Foundation

struct ReadingInsights: Equatable {
    var currentStreak: Int = 0
    var bestStreak: Int = 0
    var goalDaysMet: Int = 0
    var evaluatedGoalDays: Int = 0
    var consistentTimeLabel: String = "Not enough data"

    /// The change from `previous` to `recent` as a whole percent: 100 when there was nothing
    /// before, and nil when there's nothing in either.
    static func comparisonPercent(recent: Int, previous: Int) -> Int? {
        let recent = max(0, recent)
        let previous = max(0, previous)
        guard previous > 0 else { return recent > 0 ? 100 : nil }
        return Int(((Double(recent - previous) / Double(previous)) * 100).rounded())
    }
}

@MainActor
enum ReadingInsightsCalculator {
    static func calculate(now: Date = Date(), calendar: Calendar = .autoupdatingCurrent) -> ReadingInsights {
        calculate(
            dailyTotals: BibleStatsStore.shared.loadDailyTotals(),
            sessions: ReadingSessionsStore.shared.allSessions().filter(ReadingSessionsStore.isValid),
            now: now,
            calendar: calendar
        )
    }

    static func calculate(
        dailyTotals: [String: Int],
        sessions: [ReadingSessionsStore.Session],
        now: Date = Date(),
        calendar: Calendar = .autoupdatingCurrent
    ) -> ReadingInsights {
        var cal = calendar
        cal.timeZone = TimeZone.autoupdatingCurrent
        let today = cal.startOfDay(for: now)

        var goalDaysMet = 0
        var evaluatedGoalDays = 0
        for offset in 0..<30 {
            guard let date = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
            evaluatedGoalDays += 1
            if StreakTracker.isGoalMet(on: date, dailyTotals: dailyTotals) { goalDaysMet += 1 }
        }

        var secondsByHour = Array(repeating: 0, count: 24)
        for session in sessions {
            secondsByHour[cal.component(.hour, from: session.start)] += ReadingSessionsStore.duration(of: session)
        }

        let consistentTimeLabel: String
        if let bestHour = secondsByHour.indices.max(by: { secondsByHour[$0] < secondsByHour[$1] }),
           secondsByHour[bestHour] > 0,
           let date = cal.date(from: DateComponents(hour: bestHour)) {
            consistentTimeLabel = date.formatted(.dateTime.hour())
        } else {
            consistentTimeLabel = "Not enough data"
        }

        return ReadingInsights(
            currentStreak: StreakTracker.currentStreak(dailyTotals: dailyTotals, now: now, calendar: cal),
            bestStreak: StreakTracker.bestStreak(dailyTotals: dailyTotals, now: now, calendar: cal),
            goalDaysMet: goalDaysMet,
            evaluatedGoalDays: evaluatedGoalDays,
            consistentTimeLabel: consistentTimeLabel
        )
    }
}
