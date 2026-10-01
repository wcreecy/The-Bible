import Foundation

struct ReadingHeatMapDay: Identifiable, Equatable {
    let date: Date
    let seconds: Int

    var id: Date { date }
}

struct ReadingInsights: Equatable {
    var heatMapDays: [ReadingHeatMapDay] = []
    var currentStreak: Int = 0
    var bestStreak: Int = 0
    var recentSeconds: Int = 0
    var previousSeconds: Int = 0
    var goalDaysMet: Int = 0
    var evaluatedGoalDays: Int = 0
    var consistentTimeLabel: String = "Not enough data"

    var comparisonPercent: Int? {
        guard previousSeconds > 0 else { return recentSeconds > 0 ? 100 : nil }
        return Int(((Double(recentSeconds - previousSeconds) / Double(previousSeconds)) * 100).rounded())
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

        func seconds(daysAgo range: Range<Int>) -> Int {
            range.reduce(0) { total, offset in
                guard let date = cal.date(byAdding: .day, value: -offset, to: today) else { return total }
                return total + max(0, dailyTotals[BibleStatsStore.isoDateString(date, calendar: cal), default: 0])
            }
        }

        let heatMapDays = stride(from: 90, through: 0, by: -1).compactMap { offset -> ReadingHeatMapDay? in
            guard let date = cal.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let key = BibleStatsStore.isoDateString(date, calendar: cal)
            return ReadingHeatMapDay(date: date, seconds: max(0, dailyTotals[key, default: 0]))
        }

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
            heatMapDays: heatMapDays,
            currentStreak: StreakTracker.currentStreak(dailyTotals: dailyTotals, now: now, calendar: cal),
            bestStreak: StreakTracker.bestStreak(dailyTotals: dailyTotals, now: now, calendar: cal),
            recentSeconds: seconds(daysAgo: 0..<7),
            previousSeconds: seconds(daysAgo: 7..<14),
            goalDaysMet: goalDaysMet,
            evaluatedGoalDays: evaluatedGoalDays,
            consistentTimeLabel: consistentTimeLabel
        )
    }
}
