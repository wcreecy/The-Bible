import Foundation

/// The release-bundled recipe for the shared Daily WORD sequence.
///
/// Word strings are the stable IDs: the curated catalog guarantees that every answer is unique.
/// A seed creates one complete shuffled ordering, so every device uses the same answer for a
/// given UTC calendar day without needing a server.
struct WordleDailyScheduleConfiguration: Codable, Equatable {
    let version: Int
    let startDate: String
    let updatedAt: String
    let seed: UInt64
    let wordIDs: [String]?
    let previousSchedule: PreviousSchedule?

    /// A complete snapshot of the immediately preceding release's order. Keeping the IDs—not
    /// just its seed—means a newly added word cannot change the old schedule before cutover.
    struct PreviousSchedule: Codable, Equatable {
        let startDate: String
        let seed: UInt64
        let wordIDs: [String]
    }
}

enum WordleDailySchedule {
    static let resourceName = "WORDDailySchedule"

    private static let defaultConfiguration = WordleDailyScheduleConfiguration(
        version: 1,
        startDate: "2026-11-05",
        updatedAt: "2026-11-05",
        seed: 6_449_832_107_541_921_337,
        wordIDs: nil,
        previousSchedule: nil
    )

    private static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = utcCalendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = utcCalendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static var configuration: WordleDailyScheduleConfiguration {
        #if DEBUG
        if let override = debugConfigurationOverride {
            return override
        }
        #endif

        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let configuration = try? JSONDecoder().decode(WordleDailyScheduleConfiguration.self, from: data) else {
            return defaultConfiguration
        }
        return configuration
    }

    static var lastUpdatedDate: Date? {
        dateFormatter.date(from: configuration.updatedAt)
    }

    /// The shared answer for a date key in UTC. Before a future start date, the prior release's
    /// saved order stays active so an early App Store release does not reveal the new schedule.
    static func word(for dayKey: String, pool: [String], configuration: WordleDailyScheduleConfiguration = configuration) -> String? {
        guard let date = dateFormatter.date(from: dayKey) else {
            return nil
        }

        if let startDate = dateFormatter.date(from: configuration.startDate),
           date < startDate,
           let previousSchedule = configuration.previousSchedule {
            return word(
                for: date,
                pool: pool,
                startDate: previousSchedule.startDate,
                seed: previousSchedule.seed,
                savedWordIDs: previousSchedule.wordIDs
            )
        }

        return word(
            for: date,
            pool: pool,
            startDate: configuration.startDate,
            seed: configuration.seed,
            savedWordIDs: configuration.wordIDs
        )
    }

    static func makeConfiguration(startingOn date: Date = Date()) -> WordleDailyScheduleConfiguration {
        let startDate = dayKey(for: date)
        let previous = configuration
        let seed = UInt64.random(in: 1...UInt64(Int64.max))
        let pool = WordleGameViewModel.answerBank.words
        return WordleDailyScheduleConfiguration(
            version: 1,
            startDate: startDate,
            updatedAt: dayKey(for: Date()),
            seed: seed,
            wordIDs: shuffledWordIDs(pool: pool, seed: seed),
            previousSchedule: .init(
                startDate: previous.startDate,
                seed: previous.seed,
                wordIDs: orderedWordIDs(
                    pool: pool,
                    seed: previous.seed,
                    savedWordIDs: previous.wordIDs
                )
            )
        )
    }

    static func encodedConfiguration(_ configuration: WordleDailyScheduleConfiguration) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(configuration)
    }

    private static func positiveModulo(_ value: Int, _ divisor: Int) -> Int {
        let remainder = value % divisor
        return remainder >= 0 ? remainder : remainder + divisor
    }

    private static func word(
        for date: Date,
        pool: [String],
        startDate: String,
        seed: UInt64,
        savedWordIDs: [String]?
    ) -> String? {
        guard let firstDate = dateFormatter.date(from: startDate) else { return nil }
        let poolIDs = Set(pool.map { $0.uppercased() })
        let wordIDs = orderedWordIDs(pool: pool, seed: seed, savedWordIDs: savedWordIDs)
            .filter { poolIDs.contains($0) }
        guard !wordIDs.isEmpty else { return nil }

        let offset = utcCalendar.dateComponents([.day], from: firstDate, to: date).day ?? 0
        return wordIDs[positiveModulo(offset, wordIDs.count)]
    }

    private static func orderedWordIDs(pool: [String], seed: UInt64, savedWordIDs: [String]?) -> [String] {
        if let savedWordIDs, !savedWordIDs.isEmpty {
            return savedWordIDs
        }
        return shuffledWordIDs(pool: pool, seed: seed)
    }

    private static func shuffledWordIDs(pool: [String], seed: UInt64) -> [String] {
        var generator = SeededGenerator(seed: seed)
        return Array(Set(pool.map { $0.uppercased() })).sorted().shuffled(using: &generator)
    }

    /// The picker represents a local calendar day, while schedule lookups use an unambiguous UTC
    /// date key. Carrying date components across avoids shifting the selected day by time zone.
    private static func dayKey(for date: Date) -> String {
        let components = Calendar.autoupdatingCurrent.dateComponents([.year, .month, .day], from: date)
        guard let normalizedDate = utcCalendar.date(from: components) else {
            return dateFormatter.string(from: date)
        }
        return dateFormatter.string(from: normalizedDate)
    }

    private struct SeededGenerator: RandomNumberGenerator {
        private var state: UInt64

        init(seed: UInt64) {
            state = seed
        }

        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var value = state
            value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
            value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
            return value ^ (value >> 31)
        }
    }

    #if DEBUG
    private static let debugOverrideKey = "debugWORDDailyScheduleOverride"

    private static var debugConfigurationOverride: WordleDailyScheduleConfiguration? {
        guard let data = UserDefaults.standard.data(forKey: debugOverrideKey) else { return nil }
        return try? JSONDecoder().decode(WordleDailyScheduleConfiguration.self, from: data)
    }

    static func setDebugConfigurationOverride(_ configuration: WordleDailyScheduleConfiguration) {
        guard let data = try? JSONEncoder().encode(configuration) else { return }
        UserDefaults.standard.set(data, forKey: debugOverrideKey)
    }
    #endif
}
