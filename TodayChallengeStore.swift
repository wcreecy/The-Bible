import SwiftUI
import Foundation
import Observation

enum TodayChallengeKind: String, Codable {
    case readChapter
    case studyChapter
    case playGame
    case prayerTimer
    case reflection
    case favoriteVerse
    case highlightVerse
}

struct TodayChallenge: Identifiable, Codable, Equatable {
    let id: UUID
    var kind: TodayChallengeKind
    let title: String
    let detail: String
    let bookName: String?
    let chapterNumber: Int?
    let gameName: String?
    let minimumMinutes: Int?
    var isCompleted: Bool
}

private struct TodayChallengeSnapshot: Codable {
    let dayKey: String
    var challenges: [TodayChallenge]
    var lastModified: Date
}

/// What recent days' tasks were, so the same thing doesn't come back within `windowDays`.
private struct TodayChallengeHistory: Codable {
    static let windowDays = 30

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
private enum HistoryKey {
    static let reflectionPrefix = "reflection:"

    /// Shared by reading and study, so a chapter isn't assigned again either way.
    static func chapter(_ bookName: String, _ chapter: Int) -> String { "chapter:\(bookName)-\(chapter)" }
    static func game(_ name: String) -> String { "game:\(name)" }
    static func prayer(_ minutes: Int) -> String { "prayer:\(minutes)" }
    static func reflection(_ templateTitle: String) -> String { reflectionPrefix + templateTitle }
}

/// Chooses options so nothing repeats within the history window when the pool allows it.
private struct FreshPicker {
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
}


private struct TodayChallengeCatalog: Decodable {
    struct PrayerMinutes: Decodable {
        let minimum: Int
        let maximum: Int

        var range: ClosedRange<Int> {
            min(minimum, maximum)...max(minimum, maximum)
        }
    }

    struct ReflectionTask: Decodable {
        let title: String
        let detail: String
    }

    let gameNames: [String]
    let prayerMinutes: PrayerMinutes
    let prayerFocuses: [String]
    let reflectionTasks: [ReflectionTask]

    static func load() -> Self {
        guard let url = Bundle.main.url(forResource: "TodayChallengeCatalog", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let catalog = try? JSONDecoder().decode(Self.self, from: data),
              !catalog.gameNames.isEmpty,
              !catalog.prayerFocuses.isEmpty,
              !catalog.reflectionTasks.isEmpty else {
            assertionFailure("TodayChallengeCatalog.json is missing or invalid.")
            return fallback
        }

        return catalog
    }

    private static let fallback = Self(
        gameNames: ["Bible Quiz"],
        prayerMinutes: PrayerMinutes(minimum: 2, maximum: 20),
        prayerFocuses: ["peace"],
        reflectionTasks: [
            ReflectionTask(
                title: "Reflect on your blessings",
                detail: "Name three things you are grateful for."
            )
        ]
    )
}

@MainActor
@Observable
final class TodayChallengeStore {
    static let shared = TodayChallengeStore()

    private(set) var challenges: [TodayChallenge] = []

    private let storageKey = "todayChallengesSnapshotV1"
    private let cloudStorageKey = "todayChallengesSnapshotV2"
    private let catalog = TodayChallengeCatalog.load()
    private let cloudStore = NSUbiquitousKeyValueStore.default
    @ObservationIgnored private var corpusWaitTask: Task<Void, Never>?

    private init() {
        cloudStore.synchronize()
        loadOrCreateForToday()
    }

    func refresh() {
        loadOrCreateForToday()
        // A chapter task is complete when every verse in it is recorded as read.
        syncCompletedReadingChallenges()
        syncGameProgress()
    }

    func recordPrayerTimerCompletion(minutes: Int) {
        loadOrCreateForToday()

        updateChallenges { challenge in
            challenge.kind == .prayerTimer &&
            minutes >= (challenge.minimumMinutes ?? .max)
        }
    }

    func toggleManualChallenge(id: UUID) {
        loadOrCreateForToday()

        guard let index = challenges.firstIndex(where: { $0.id == id && $0.kind == .reflection }) else {
            return
        }

        challenges[index].isCompleted.toggle()
        save()
    }

    /// Marks today's favorite-verse task complete after a verse is successfully saved.
    func recordFavoriteVerseSaved() {
        loadOrCreateForToday()
        updateChallenges { $0.kind == .favoriteVerse }
    }

    /// Marks today's highlight task complete after a verse highlight is successfully saved.
    func recordVerseHighlightSaved() {
        loadOrCreateForToday()
        updateChallenges { $0.kind == .highlightVerse }
    }

    func completeStudyChallenge(id: UUID) {
        loadOrCreateForToday()

        guard let index = challenges.firstIndex(where: { $0.id == id && $0.kind == .studyChapter }),
              !challenges[index].isCompleted else {
            return
        }

        challenges[index].isCompleted = true
        save()
    }

    // MARK: - History

    private let historyKey = "todayChallengesHistoryV1"

    /// Combines this device's history with the synced copy, so tasks shown on another
    /// device count too.
    private func loadHistory() -> TodayChallengeHistory {
        func decode(_ data: Data?) -> TodayChallengeHistory {
            guard let data, let history = try? JSONDecoder().decode(TodayChallengeHistory.self, from: data) else {
                return TodayChallengeHistory()
            }
            return history
        }
        return decode(UserDefaults.standard.data(forKey: historyKey))
            .merged(with: decode(cloudStore.data(forKey: historyKey)))
    }

    /// Saved locally and to iCloud; the next snapshot publish synchronizes the store.
    private func saveHistory(_ history: TodayChallengeHistory) {
        guard let data = try? JSONEncoder().encode(history) else { return }
        UserDefaults.standard.set(data, forKey: historyKey)
        cloudStore.set(data, forKey: historyKey)
    }

    #if DEBUG
    func regenerateForDebug() {
        challenges = makeChallenges()
        save()
    }
    #endif

    private func syncCompletedReadingChallenges() {
        updateChallenges { challenge in
            guard challenge.kind == .readChapter,
                  let bookName = challenge.bookName,
                  let chapterNumber = challenge.chapterNumber,
                  let book = BibleData.books.first(where: { $0.name == bookName }),
                  let chapter = book.chapters.first(where: { $0.number == chapterNumber }) else {
                return false
            }

            return BibleStatsStore.shared.isChapterComplete(
                bookName: bookName,
                chapter: chapterNumber,
                totalVerses: chapter.verses.count
            )
        }
    }

    private func syncGameProgress() {
        updateChallenges { challenge in
            guard challenge.kind == .playGame, let gameName = challenge.gameName else {
                return false
            }

            return (GameStats.shared.dailySeriesLast(days: 1, forDisplayName: gameName).last?.answered ?? 0) > 0
        }
    }

    private func loadOrCreateForToday() {
        let now = Date()
        let localSnapshot = snapshot(from: UserDefaults.standard.data(forKey: storageKey))
        let cloudSnapshot = snapshot(from: cloudStore.data(forKey: cloudStorageKey))

        if let cloudSnapshot,
           !Self.needsNewChallenges(snapshotDayKey: cloudSnapshot.dayKey, on: now),
           cloudSnapshot.challenges.count == 3,
           !Self.containsRetiredBookmarkTask(in: cloudSnapshot.challenges) {
            let cloudChallenges = cloudSnapshot.challenges.map(repairedChallenge)
            challenges = cloudChallenges
            persistLocally(lastModified: cloudSnapshot.lastModified)

            if cloudChallenges != cloudSnapshot.challenges {
                save()
            }
        } else if let localSnapshot,
                  !Self.needsNewChallenges(snapshotDayKey: localSnapshot.dayKey, on: now),
                  localSnapshot.challenges.count == 3,
                  !Self.containsRetiredBookmarkTask(in: localSnapshot.challenges) {
            challenges = localSnapshot.challenges.map(repairedChallenge)
            if challenges != localSnapshot.challenges {
                save()
            } else {
                publishToCloud(localSnapshot)
            }
        } else if BibleData.books.isEmpty {
            // Reading challenges are drawn from the corpus, which loads asynchronously.
            // Creating them now would pick only from the small fallback corpus.
            createChallengesWhenCorpusLoads()
        } else {
            challenges = makeChallenges()
            save()
        }
    }

    static func needsNewChallenges(snapshotDayKey: String, on date: Date) -> Bool {
        snapshotDayKey != GameStats.localDayKey(for: date)
    }

    private func createChallengesWhenCorpusLoads() {
        guard corpusWaitTask == nil else { return }
        corpusWaitTask = Task { [weak self] in
            _ = await BibleRepository.shared.loadAllBooks()
            guard let self else { return }
            corpusWaitTask = nil
            loadOrCreateForToday()
            syncCompletedReadingChallenges()
            syncGameProgress()
        }
    }

    private func updateChallenges(where shouldComplete: (TodayChallenge) -> Bool) {
        var didChange = false

        for index in challenges.indices where !challenges[index].isCompleted && shouldComplete(challenges[index]) {
            challenges[index].isCompleted = true
            didChange = true
        }

        if didChange {
            save()
        }
    }

    private func save() {
        let snapshot = TodayChallengeSnapshot(
            dayKey: dayKey(for: Date()),
            challenges: challenges,
            lastModified: Date()
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
        publishToCloud(snapshot)
    }

    private func snapshot(from data: Data?) -> TodayChallengeSnapshot? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(TodayChallengeSnapshot.self, from: data)
    }

    private func persistLocally(lastModified: Date) {
        let snapshot = TodayChallengeSnapshot(
            dayKey: dayKey(for: Date()),
            challenges: challenges,
            lastModified: lastModified
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func publishToCloud(_ snapshot: TodayChallengeSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        cloudStore.set(data, forKey: cloudStorageKey)

        Task.detached {
            NSUbiquitousKeyValueStore.default.synchronize()
        }
    }

    private func dayKey(for date: Date) -> String {
        GameStats.localDayKey(for: date)
    }

    private func repairedChallenge(_ challenge: TodayChallenge) -> TodayChallenge {
        var challenge = challenge

        switch challenge.kind {
        case .readChapter where challenge.title == "Read (book.name) (chapter)":
            if let bookName = challenge.bookName, let chapterNumber = challenge.chapterNumber {
                challenge = TodayChallenge(
                    id: challenge.id,
                    kind: challenge.kind,
                    title: "Read \(bookName) \(chapterNumber)",
                    detail: challenge.detail,
                    bookName: challenge.bookName,
                    chapterNumber: challenge.chapterNumber,
                    gameName: challenge.gameName,
                    minimumMinutes: challenge.minimumMinutes,
                    isCompleted: challenge.isCompleted
                )
            }
        case .playGame where challenge.title == "Play (gameName)":
            if let gameName = challenge.gameName {
                challenge = TodayChallenge(
                    id: challenge.id,
                    kind: challenge.kind,
                    title: "Play \(gameName)",
                    detail: challenge.detail,
                    bookName: challenge.bookName,
                    chapterNumber: challenge.chapterNumber,
                    gameName: challenge.gameName,
                    minimumMinutes: challenge.minimumMinutes,
                    isCompleted: challenge.isCompleted
                )
            }
        case .prayerTimer where challenge.title == "Pray for (prayerMinutes) minutes":
            if let minimumMinutes = challenge.minimumMinutes {
                challenge = TodayChallenge(
                    id: challenge.id,
                    kind: challenge.kind,
                    title: "Pray for \(minimumMinutes) minutes",
                    detail: challenge.detail,
                    bookName: challenge.bookName,
                    chapterNumber: challenge.chapterNumber,
                    gameName: challenge.gameName,
                    minimumMinutes: challenge.minimumMinutes,
                    isCompleted: challenge.isCompleted
                )
            }
        default:
            break
        }

        return challenge
    }

    /// The tasks tracked inside the app, which fill the slots after reading (and reflection).
    private enum InAppTask: CaseIterable {
        case study, prayer, game
    }

    /// Builds today's three tasks: one reading every day, a reflection once a week, and
    /// the rest drawn from study, prayer, and games, with each kind at most once a day.
    /// Nothing shown in the last 30 days comes back when there's anything fresh to pick.
    private func makeChallenges() -> [TodayChallenge] {
        let now = Date()
        let todayKey = dayKey(for: now)
        var history = loadHistory()
        var picker = FreshPicker(lastShown: history.lastShown(excluding: todayKey))

        var challenges = [makeReadingChallenge(using: &picker)]
        if isReflectionDue(on: now, history: history) {
            challenges.append(makeReflectionChallenge(using: &picker))
        }
        for task in InAppTask.allCases.shuffled().prefix(Self.challengesPerDay - challenges.count) {
            switch task {
            case .study: challenges.append(makeStudyChallenge(using: &picker))
            case .prayer: challenges.append(makePrayerChallenge(using: &picker))
            case .game: challenges.append(makeGameChallenge(using: &picker))
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

    private func makeGameChallenge(using picker: inout FreshPicker) -> TodayChallenge {
        let gameName = picker.pick(from: catalog.gameNames, key: HistoryKey.game) ?? "Bible Quiz"

        return TodayChallenge(
            id: UUID(),
            kind: .playGame,
            title: "Play \(gameName)",
            detail: "Finish a round to complete this.",
            bookName: nil,
            chapterNumber: nil,
            gameName: gameName,
            minimumMinutes: nil,
            isCompleted: false
        )
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

    private static func containsRetiredBookmarkTask(in challenges: [TodayChallenge]) -> Bool {
        challenges.contains { $0.title == "Add a verse to your bookmarks" }
    }

    private func makeReflectionChallenge(using picker: inout FreshPicker) -> TodayChallenge {
        // Keyed by the template, so "Pray for {{prayerFocus}}" counts once whatever the focus.
        let task = picker.pick(from: catalog.reflectionTasks, key: { HistoryKey.reflection($0.title) })
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

struct HomeTodayCard: View {
    private var store = TodayChallengeStore.shared
    @State private var studyChallenge: TodayChallenge?

    /// Starts the Home prayer timer for the given number of minutes.
    let onStartPrayerTimer: (Int) -> Void

    var body: some View {
        HeroCard(title: "Today", icon: "checklist", tint: .teal) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Three small ways to grow today")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 8)

                    #if DEBUG
                    Button {
                        store.regenerateForDebug()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Refresh Today challenges")
                    .accessibilityHint("Available only in debug builds.")
                    #endif
                }

                ForEach(store.challenges) { challenge in
                    TodayChallengeRow(challenge: challenge) {
                        perform(challenge)
                    }
                }
            }
        }
        .sheet(item: $studyChallenge) { challenge in
            NavigationStack {
                if let bookName = challenge.bookName, let chapterNumber = challenge.chapterNumber {
                    ChapterInsightsView(bookName: bookName, chapterNumber: chapterNumber)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") {
                                    studyChallenge = nil
                                }
                            }
                        }
                } else {
                    ContentUnavailableView("Study unavailable", systemImage: "text.book.closed")
                }
            }
        }
        .onAppear {
            store.refresh()
        }
        .task {
            await refreshAtNextDayBoundary()
        }
        .onNotification(.bibleStatsExternallyUpdated) {
            store.refresh()
        }
        // Only the default key-value store posts this, so no object filter is needed.
        .onNotification(NSUbiquitousKeyValueStore.didChangeExternallyNotification) {
            store.refresh()
        }
    }

    /// Refreshes the card at each local calendar-day boundary while it remains visible.
    private func refreshAtNextDayBoundary() async {
        let calendar = Calendar.autoupdatingCurrent

        while !Task.isCancelled {
            let now = Date()
            let startOfTomorrow = calendar.date(
                byAdding: .day,
                value: 1,
                to: calendar.startOfDay(for: now)
            ) ?? now.addingTimeInterval(86_400)
            let interval = max(1, startOfTomorrow.timeIntervalSince(now))

            do {
                try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            } catch {
                return
            }

            guard !Task.isCancelled else { return }
            store.refresh()
        }
    }

    /// Takes the person straight to the activity a challenge describes.
    private func perform(_ challenge: TodayChallenge) {
        switch challenge.kind {
        case .readChapter:
            guard let bookName = challenge.bookName, let chapter = challenge.chapterNumber else { return }
            Haptics.selection()
            AppRouter.shared.openBibleReference(book: bookName, chapter: chapter, verse: 1)
        case .studyChapter:
            guard challenge.bookName != nil, challenge.chapterNumber != nil else { return }
            Haptics.selection()
            store.completeStudyChallenge(id: challenge.id)
            studyChallenge = challenge
        case .playGame:
            guard let gameName = challenge.gameName else { return }
            Haptics.selection()
            GameLaunchRequest.open(gameName: gameName)
        case .prayerTimer:
            guard !challenge.isCompleted, let minutes = challenge.minimumMinutes else { return }
            Haptics.selection()
            onStartPrayerTimer(minutes)
        case .reflection:
            store.toggleManualChallenge(id: challenge.id)
        case .favoriteVerse, .highlightVerse:
            break
        }
    }
}

private struct TodayChallengeRow: View {
    let challenge: TodayChallenge
    let action: () -> Void

    /// Completed prayer challenges have nothing left to start.
    private var isActionable: Bool {
        ![.favoriteVerse, .highlightVerse].contains(challenge.kind) &&
            !(challenge.kind == .prayerTimer && challenge.isCompleted)
    }

    var body: some View {
        Button(action: action) {
            rowContent
        }
        .buttonStyle(.plain)
        .disabled(!isActionable)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
    }

    private var rowContent: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: challenge.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(challenge.isCompleted ? Color.green : Color.secondary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(challenge.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(challenge.isCompleted ? .secondary : .primary)
                    .strikethrough(challenge.isCompleted, color: .secondary)

                Text(challenge.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            if let actionLabel {
                Label(actionLabel.title, systemImage: actionLabel.systemImage)
                    .labelStyle(.iconOnly)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .padding(.top, 2)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
    }

    /// The trailing affordance for rows that open another part of the app.
    private var actionLabel: (title: String, systemImage: String)? {
        switch challenge.kind {
        case .readChapter: ("Read", "book")
        case .studyChapter: ("Study", "text.book.closed")
        case .playGame: ("Play", "gamecontroller")
        case .prayerTimer: challenge.isCompleted ? nil : ("Start", "timer")
        case .reflection: nil
        case .favoriteVerse: ("Favorite verse", "heart")
        case .highlightVerse: ("Highlight verse", "highlighter")
        }
    }

    private var accessibilityLabel: String {
        challenge.isCompleted ? "\(challenge.title), completed" : challenge.title
    }

    private var accessibilityHint: String {
        switch challenge.kind {
        case .readChapter:
            "Opens the chapter."
        case .studyChapter:
            "Opens chapter insights and marks this study complete."
        case .playGame:
            "Opens the game."
        case .prayerTimer:
            challenge.isCompleted ? "" : "Starts a prayer timer."
        case .reflection:
            challenge.isCompleted ? "Double tap to mark incomplete." : "Double tap to mark complete."
        case .favoriteVerse:
            challenge.isCompleted ? "Completed automatically when a verse was added to Favorites." : "Add a verse to Favorites to complete this automatically."
        case .highlightVerse:
            challenge.isCompleted ? "Completed automatically when a verse was highlighted." : "Highlight a verse to complete this automatically."
        }
    }
}
