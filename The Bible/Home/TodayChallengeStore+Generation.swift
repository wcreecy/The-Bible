import Foundation
import OSLog

private let todayChallengesLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "The Bible",
    category: "TodayChallenges"
)

/// What recent days' tasks were, so the same thing doesn't come back within `windowDays`.
struct TodayChallengeHistory: Codable {
    static let windowDays = 31

    /// Day key (yyyy-MM-dd) to the `HistoryKey`s of what was shown that day.
    var days: [String: [String]] = [:]

    /// The most recent day each key was shown, leaving out `excludedDay`.
    func lastShown(excluding excludedDay: String) -> [String: String] {
        var result: [String: String] = [:]
        for (day, keys) in days where day != excludedDay {
            for key in keys where day > result[key, default: ""] {
                result[key] = day
            }
        }
        return result
    }

    func merged(with other: Self) -> Self {
        var copy = self
        copy.days.merge(other.days) { mine, theirs in Array(Set(mine).union(theirs)).sorted() }
        return copy
    }

    /// Drops days older than `oldestDay`. Day keys sort in date order.
    mutating func prune(keepingFrom oldestDay: String) {
        days = days.filter { $0.key >= oldestDay }
    }
}

/// How each kind of shown item is recorded in `TodayChallengeHistory`.
enum HistoryKey {
    static let reflectionPrefix = "reflection:"

    /// Shared by reading and study, so a chapter isn't assigned again either way.
    static func chapter(_ bookName: String, _ chapter: Int) -> String { "chapter:\(bookName)-\(chapter)" }
    static func prayer(_ minutes: Int) -> String { "prayer:\(minutes)" }
    static func reflection(_ templateTitle: String) -> String { reflectionPrefix + templateTitle }
}

/// Chooses options so nothing repeats within the history window when the pool allows it.
struct FreshPicker {
    let lastShown: [String: String]
    private(set) var usedToday: [String] = []

    /// A random option not shown in the window. If every option was shown (games and
    /// prayer lengths have fewer than 30), one of those shown longest ago instead.
    mutating func pick<T>(from options: [T], key: (T) -> String) -> T? {
        let notUsedToday = options.filter { !usedToday.contains(key($0)) }
        let pool = notUsedToday.isEmpty ? options : notUsedToday

        let choice: T?
        if let fresh = pool.filter({ lastShown[key($0)] == nil }).randomElement() {
            choice = fresh
        } else {
            let oldest = pool.compactMap { lastShown[key($0)] }.min()
            choice = pool.filter { lastShown[key($0)] == oldest }.randomElement()
        }

        if let choice { usedToday.append(key(choice)) }
        return choice
    }

    mutating func record(_ key: String) {
        usedToday.append(key)
    }
}

extension TodayChallengeStore {
    /// The tasks tracked inside the app, which fill the slots after reading (and reflection).
    private enum InAppTask: CaseIterable {
        case study, prayer, game
    }

    /// Builds today's three tasks: one reading every day, a reflection once a week, and
    /// the rest drawn from study, prayer, and games, with each kind at most once a day.
    /// Nothing shown in the last 30 days comes back when there's anything fresh to pick.
    func makeChallenges() -> [TodayChallenge] {
        let now = Date()
        let todayKey = dayKey(for: now)
        var history = loadHistory()
        var picker = FreshPicker(lastShown: history.lastShown(excluding: todayKey))

        var challenges = [makeReadingChallenge(using: &picker)]
        // If the app was not opened on either scheduled date, show one overdue optional
        // prompt today and leave the other for a later day instead of pairing them.
        if let title = monthlySystemTaskTitlesDue(in: history, on: now).randomElement() {
            let monthlyTask = makeMonthlySystemTask(title: title, using: &picker)
            challenges.append(monthlyTask)
            todayChallengesLogger.notice("Scheduled monthly Today prompt; kind=\(monthlyTask.kind.rawValue, privacy: .public).")
        }
        if challenges.count < Self.challengesPerDay, isReflectionDue(on: now, history: history) {
            challenges.append(makeReflectionChallenge(using: &picker))
        }
        for task in InAppTask.allCases.shuffled().prefix(Self.challengesPerDay - challenges.count) {
            switch task {
            case .study: challenges.append(makeStudyChallenge(using: &picker))
            case .prayer: challenges.append(makePrayerChallenge(using: &picker))
            case .game: challenges.append(makeGameChallenge())
            }
        }

        history.days[todayKey] = picker.usedToday
        let oldestKept = Calendar.autoupdatingCurrent.date(
            byAdding: .day,
            value: -(TodayChallengeHistory.windowDays - 1),
            to: now
        ) ?? now
        history.prune(keepingFrom: dayKey(for: oldestKept))
        saveHistory(history)

        return challenges.shuffled()
    }

    private static let challengesPerDay = 3

    /// Reflection tasks are done outside the app, so they come once per calendar week on
    /// a random day: each day without one so far has a 1-in-(days left in the week) chance.
    private func isReflectionDue(on date: Date, history: TodayChallengeHistory) -> Bool {
        let calendar = Calendar.autoupdatingCurrent
        guard let week = calendar.dateInterval(of: .weekOfYear, for: date) else { return false }
        let weekStartKey = dayKey(for: week.start)
        let todayKey = dayKey(for: date)

        let alreadyShown = history.days.contains { day, keys in
            day >= weekStartKey && day < todayKey && keys.contains { $0.hasPrefix(HistoryKey.reflectionPrefix) }
        }
        guard !alreadyShown else { return false }

        let daysLeft = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: week.end).day ?? 1
        return Int.random(in: 1...max(1, daysLeft)) == 1
    }

    /// Picks a chapter that hasn't been read or studied recently, with every chapter in
    /// the Bible equally likely (so one psalm is as likely as Obadiah 1).
    private func pickChapter(using picker: inout FreshPicker) -> (bookName: String, chapter: Int) {
        // Challenges are only created once the corpus has loaded (see loadOrCreateForToday).
        let allChapters = BibleData.books.flatMap { book in
            book.chapters.map { (bookName: book.name, chapter: $0.number) }
        }
        guard let pick = picker.pick(from: allChapters, key: { HistoryKey.chapter($0.bookName, $0.chapter) }) else {
            assertionFailure("Bible fallback corpus must contain at least one book.")
            return ("Genesis", 1)
        }
        return pick
    }

    private func makeReadingChallenge(using picker: inout FreshPicker) -> TodayChallenge {
        let (bookName, chapter) = pickChapter(using: &picker)

        return TodayChallenge(
            id: UUID(),
            kind: .readChapter,
            title: "Read \(bookName) \(chapter)",
            detail: "Open the chapter to complete this.",
            bookName: bookName,
            chapterNumber: chapter,
            gameName: nil,
            minimumMinutes: nil,
            isCompleted: false
        )
    }

    private func makeStudyChallenge(using picker: inout FreshPicker) -> TodayChallenge {
        let (bookName, chapterNumber) = pickChapter(using: &picker)

        return TodayChallenge(
            id: UUID(),
            kind: .studyChapter,
            title: "Study \(bookName) \(chapterNumber)",
            detail: "Explore the chapter’s themes and background.",
            bookName: bookName,
            chapterNumber: chapterNumber,
            gameName: nil,
            minimumMinutes: nil,
            isCompleted: false
        )
    }

    private func makeGameChallenge() -> TodayChallenge {
        // Each game challenge is an independent, equally likely draw. The Today card still
        // balances challenge types separately, but a recently shown game may appear again.
        let gameName = randomGameName()

        return TodayChallenge(
            id: UUID(),
            kind: .playGame,
            title: Self.gameChallengeTitle(for: gameName),
            detail: "Finish a round to complete this.",
            bookName: nil,
            chapterNumber: nil,
            gameName: gameName,
            minimumMinutes: nil,
            isCompleted: false
        )
    }

    /// Picks from the same catalog of games used by the Today card.
    func randomGameName() -> String {
        Array(Set(catalog.gameNames.map(GameStats.canonicalDisplayName))).randomElement() ?? "Quiz"
    }

    static func gameChallengeTitle(for gameName: String) -> String {
        switch GameStats.canonicalDisplayName(gameName) {
        case "Quiz":
            String(localized: "Test your Bible knowledge")
        case "Trivia":
            String(localized: "Tackle Bible trivia")
        case "Hangman":
            String(localized: "Solve a Bible word")
        case "Countdown":
            String(localized: "Race the clock")
        case "Book Order":
            String(localized: "Put the books in order")
        case "Who?":
            String(localized: "Name the Bible character")
        case "Word Search":
            String(localized: "Find hidden Bible words")
        case "Scramble":
            String(localized: "Unscramble Bible words")
        case "Crossword":
            String(localized: "Solve a Bible crossword")
        case "Word":
            String(localized: "Find today's Bible word")
        default:
            String(localized: "Play \(gameName)")
        }
    }

    private func makePrayerChallenge(using picker: inout FreshPicker) -> TodayChallenge {
        let prayerMinutes = picker.pick(from: Array(catalog.prayerMinutes.range), key: HistoryKey.prayer)
            ?? catalog.prayerMinutes.minimum

        return TodayChallenge(
            id: UUID(),
            kind: .prayerTimer,
            title: "Pray for \(prayerMinutes) minutes",
            detail: "Complete a prayer timer to finish this.",
            bookName: nil,
            chapterNumber: nil,
            gameName: nil,
            minimumMinutes: prayerMinutes,
            isCompleted: false
        )
    }

    static func kind(forReflectionTaskTitle title: String) -> TodayChallengeKind {
        switch title {
        case "Add a verse to your favorites":
            .favoriteVerse
        case "Highlight a verse to study later":
            .highlightVerse
        default:
            .reflection
        }
    }

    static func containsRetiredBookmarkTask(in challenges: [TodayChallenge]) -> Bool {
        let retiredTitles = [
            "Bookmark a verse",
            "Add a verse to your bookmarks"
        ]
        return challenges.contains { retiredTitles.contains($0.title) }
    }

    private static let monthlySystemTaskTitles = [
        "Add a verse to your favorites",
        "Highlight a verse to study later"
    ]

    /// A stable pseudo-random date keeps the monthly prompt consistent across devices.
    static func monthlySystemTaskDay(for title: String, on date: Date) -> Int {
        let calendar = Calendar.autoupdatingCurrent
        let dayCount = calendar.range(of: .day, in: .month, for: date)?.count ?? 28
        let components = calendar.dateComponents([.year, .month], from: date)
        let monthIdentifier = "\(components.year ?? 0)-\(components.month ?? 0)"
        var hash: UInt64 = 5_381

        for scalar in (monthIdentifier + title).unicodeScalars {
            hash = ((hash << 5) &+ hash) &+ UInt64(scalar.value)
        }

        var day = Int(hash % UInt64(dayCount)) + 1
        if title == monthlySystemTaskTitles[1] {
            let favoriteDay = monthlySystemTaskDay(for: monthlySystemTaskTitles[0], on: date)
            if day == favoriteDay {
                day = day == dayCount ? 1 : day + 1
            }
        }
        return day
    }

    private func monthlySystemTaskTitlesDue(
        in history: TodayChallengeHistory,
        on date: Date
    ) -> [String] {
        let calendar = Calendar.autoupdatingCurrent
        guard let month = calendar.dateInterval(of: .month, for: date) else { return [] }
        let monthStartKey = dayKey(for: month.start)
        let currentDay = calendar.component(.day, from: date)

        return Self.monthlySystemTaskTitles.filter { title in
            let taskKey = HistoryKey.reflection(title)
            let wasShownThisMonth = history.days.contains { day, keys in
                day >= monthStartKey && keys.contains(taskKey)
            }
            return !wasShownThisMonth &&
                currentDay >= Self.monthlySystemTaskDay(for: title, on: date)
        }
    }

    private func makeMonthlySystemTask(
        title: String,
        using picker: inout FreshPicker
    ) -> TodayChallenge {
        let task = catalog.reflectionTasks.first { $0.title == title }
            ?? TodayChallengeCatalog.ReflectionTask(
                title: title,
                detail: "Save a verse you want to return to."
            )
        picker.record(HistoryKey.reflection(task.title))

        return TodayChallenge(
            id: UUID(),
            kind: Self.kind(forReflectionTaskTitle: task.title),
            title: task.title,
            detail: task.detail,
            bookName: nil,
            chapterNumber: nil,
            gameName: nil,
            minimumMinutes: nil,
            isCompleted: false
        )
    }

    private func makeReflectionChallenge(using picker: inout FreshPicker) -> TodayChallenge {
        // Monthly system-tracked prompts are scheduled separately from weekly reflections.
        let eligibleTasks = catalog.reflectionTasks.filter {
            !Self.monthlySystemTaskTitles.contains($0.title)
        }
        // Keyed by the template, so "Pray for {{prayerFocus}}" counts once whatever the focus.
        let task = picker.pick(from: eligibleTasks, key: { HistoryKey.reflection($0.title) })
            ?? TodayChallengeCatalog.ReflectionTask(
                title: "Reflect on your blessings",
                detail: "Name three things you are grateful for."
            )
        let bookName = BibleData.books.randomElement()?.name ?? "Genesis"
        let prayerFocus = catalog.prayerFocuses.randomElement() ?? "peace"
        let title = task.title
            .replacingOccurrences(of: "{{bookName}}", with: bookName)
            .replacingOccurrences(of: "{{prayerFocus}}", with: prayerFocus)

        return TodayChallenge(
            id: UUID(),
            kind: Self.kind(forReflectionTaskTitle: title),
            title: title,
            detail: task.detail,
            bookName: nil,
            chapterNumber: nil,
            gameName: nil,
            minimumMinutes: nil,
            isCompleted: false
        )
    }
}
