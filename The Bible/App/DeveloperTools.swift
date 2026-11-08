#if DEBUG
import Foundation
import SwiftData
import UserNotifications

/// Actions behind Settings > Developer Tools. They exist only in debug builds.
@MainActor
enum DeveloperTools {
    // MARK: - Resume Reading previews

    static let resumeReadingPreviewKey = "debugResumeReadingPreview"

    enum ResumeReadingPreview: String, CaseIterable, Identifiable {
        case actual
        case today
        case yesterday
        case threeWeeksAgo

        var id: String { rawValue }

        var title: LocalizedStringResource {
            switch self {
            case .actual: "Actual bookmark"
            case .today: "Saved today"
            case .yesterday: "Saved yesterday"
            case .threeWeeksAgo: "Saved three weeks ago"
            }
        }

        var date: Date? {
            switch self {
            case .actual:
                nil
            case .today:
                .now
            case .yesterday:
                Calendar.current.date(byAdding: .day, value: -1, to: .now)
            case .threeWeeksAgo:
                Calendar.current.date(byAdding: .day, value: -21, to: .now)
            }
        }
    }

    // MARK: - Daily WORD schedule

    /// Makes a new shared Daily WORD schedule for release and applies it to this Debug build.
    /// The caller exports the returned configuration as WORDDailySchedule.json for the next build.
    static func regenerateDailyWordSchedule(startingOn date: Date) -> WordleDailyScheduleConfiguration {
        let configuration = WordleDailySchedule.makeConfiguration(startingOn: date)
        WordleDailySchedule.setDebugConfigurationOverride(configuration)
        return configuration
    }

    // MARK: - Streak and daily goal

    /// Reading time added by the streak tools sits under this source name, so it's easy to spot.
    private static let streakSource = "developer-streak"

    private typealias Contributions = [String: [String: [String: Int]]]

    /// Streaks are derived from reading contributions, so the tools edit those.
    private static func editContributions(_ change: (inout Contributions) -> Void) {
        let store = BibleStatsStore.shared
        var contributions = store.loadReadingContributions()
        change(&contributions)
        store.cacheReadingContributions = contributions
        store.saveJSON(contributions, key: BibleStatsStore.Defaults.keyReadingContributions)
        AppDataChanges.shared.bibleStatsChanged()
    }

    /// Adds just enough reading time to a day for it to meet that day's goal.
    private static func topUp(_ day: Date, in contributions: inout Contributions) {
        let key = BibleStatsStore.isoDateString(day)
        let existing = contributions[key]?.values.reduce(0) { $0 + $1.values.reduce(0, +) } ?? 0
        let shortfall = StreakTracker.dailyGoalSeconds(on: day) - existing
        guard shortfall > 0 else { return }
        contributions[key, default: [:]]["Genesis", default: [:]][streakSource, default: 0] += shortfall
    }

    private static func day(_ offset: Int) -> Date? {
        Calendar.autoupdatingCurrent.date(byAdding: .day, value: -offset, to: Date())
    }

    /// Makes the streak `days` long, ending yesterday. Today then adds one more once its goal is met.
    /// The day before the run is cleared so the streak can't be longer than asked.
    static func setStreak(days: Int) {
        editContributions { contributions in
            for offset in 1...max(1, days) {
                if let date = day(offset) { topUp(date, in: &contributions) }
            }
            if let before = day(days + 1) {
                contributions[BibleStatsStore.isoDateString(before)] = nil
            }
        }
    }

    /// Clears yesterday's reading so the current streak ends.
    static func breakStreak() {
        guard let yesterday = day(1) else { return }
        editContributions { $0[BibleStatsStore.isoDateString(yesterday)] = nil }
    }

    static func completeTodaysGoal() {
        editContributions { topUp(Date(), in: &$0) }
    }

    // MARK: - Onboarding and tips

    /// Shows the Welcome checklist again from its first step.
    static func resetWelcomeChecklist() {
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("homeOnboarding") {
            defaults.removeObject(forKey: key)
        }

        let store = HomeLayoutStore()
        let layout = store.load()
        var hidden = layout.hidden
        hidden.remove(.setup)
        store.save(order: layout.order, hidden: hidden, columns: layout.columns)
    }

    /// Turns tips on and brings back every tip that was dismissed.
    static func resetContextualTips() {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: AppStorageKey.contextualTipsEnabled)
        defaults.set(defaults.integer(forKey: AppStorageKey.contextualTipsResetGeneration) &+ 1,
                     forKey: AppStorageKey.contextualTipsResetGeneration)
    }

    // MARK: - Test notifications

    enum TestNotification: CaseIterable {
        case verseOfDay
        case streakReminder
    }

    /// Schedules a notification a few seconds out, with the same tap destination as the real one.
    /// Returns false when notifications aren't allowed.
    static func sendTestNotification(_ kind: TestNotification, after seconds: TimeInterval = 5) async -> Bool {
        guard await VOTDNotificationScheduler.requestAuthorizationIfNeeded() else { return false }

        let content = UNMutableNotificationContent()
        switch kind {
        case .verseOfDay:
            let hour = Calendar.autoupdatingCurrent.component(.hour, from: Date())
            content.title = VOTDNotificationScheduler.notificationTitles(forHour: hour).first ?? "Verse of the Day"
            content.body = "Verse of the Day"
            content.badge = 1
            content.userInfo = ["destination": "verseOfDay"]
        case .streakReminder:
            content.title = "Keep your 5-day streak going"
            content.body = "Read 10 more min today to reach your goal."
            content.userInfo = ["destination": StreakReminderScheduler.destination]
        }
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "developer-test-\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        )
        do {
            try await UNUserNotificationCenter.current().add(request)
            return true
        } catch {
            return false
        }
    }

    /// Schedules the Prayer & Study timer alarm shortly from now. It reuses the real timer's alarm,
    /// so it replaces one that's pending.
    static func sendTestTimerAlarm(after seconds: TimeInterval = 10) async -> Bool {
        if PrayerTimerAlarmScheduler.authorizationStatus() != .authorized {
            guard await PrayerTimerAlarmScheduler.requestAuthorization() == .authorized else { return false }
        }
        return await PrayerTimerAlarmScheduler.schedule(at: Date().addingTimeInterval(seconds), title: "Developer test alarm")
    }

    // MARK: - Edge-case content

    private static let stressNotePrefix = "Stress test note"
    /// Titles `DeveloperSampleData` gives the notes it makes.
    private static let sampleNoteTitles: Set<String> = ["Living with courage", "Morning reflection", "Grace in everyday life"]
    private static let sampleHighlightPrefix = "Sample highlight "

    /// Adds many notes, to check lists, search, and sync with a large library.
    static func seedStressNotes(count: Int = 500, in context: ModelContext) throws {
        let categories = [NoteCategory.personal, .sermon]
        for index in 1...count {
            let note = UserNote()
            note.title = "\(stressNotePrefix) \(index)"
            note.content = "Generated note \(index) for checking long lists, search, and sync."
            note.categoryRawValue = categories[index % categories.count].rawValue
            note.createdAt = Date().addingTimeInterval(-Double(index) * 3_600)
            note.updatedAt = note.createdAt
            context.insert(note)
        }
        try context.save()
    }

    /// Adds one note with a very long title and many paragraphs, to check layout and editing.
    static func seedLongNote(in context: ModelContext) throws {
        let note = UserNote()
        note.title = "\(stressNotePrefix): " + String(repeating: "A very long title that keeps going ", count: 8)
        let paragraph = "Grace meets us before we have everything figured out, and equips us to serve with humility, patience, and joy. "
        note.content = (1...200)
            .map { "Paragraph \($0). " + String(repeating: paragraph, count: 4) }
            .joined(separator: "\n\n")
        context.insert(note)
        try context.save()
    }

    /// Removes the notes and highlights made by Generate Sample Data and the edge-case seeds.
    /// Stats and saved verses aren't tagged, so Reset Data is how those are cleared.
    @discardableResult
    static func removeSeededNotes(in context: ModelContext) throws -> Int {
        var removed = 0
        for note in try context.fetch(FetchDescriptor<UserNote>())
        where note.title.hasPrefix(stressNotePrefix) || sampleNoteTitles.contains(note.title) {
            context.delete(note)
            removed += 1
        }
        for note in try context.fetch(FetchDescriptor<VerseNote>())
        where note.title.hasPrefix(sampleHighlightPrefix) || sampleNoteTitles.contains(note.title) {
            context.delete(note)
            removed += 1
        }
        try context.save()
        return removed
    }

    /// Picks verses at random from the active translation that aren't in `taken` ("Book|chapter|verse").
    private static func randomVerses(count: Int, avoiding taken: Set<String>) async -> [(book: String, chapter: Int, verse: Verse)] {
        let books = await BibleRepository.shared.loadAllBooks()
        var taken = taken
        var picked: [(book: String, chapter: Int, verse: Verse)] = []
        var attempts = 0
        while picked.count < count && attempts < count * 50 {
            attempts += 1
            guard let book = books.randomElement(),
                  let chapter = book.chapters.randomElement(),
                  let verse = chapter.verses.randomElement(),
                  !verse.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  taken.insert("\(book.name)|\(chapter.number)|\(verse.number)").inserted else { continue }
            picked.append((book.name, chapter.number, verse))
        }
        return picked
    }

    /// Saves random verses as favorites. They aren't tagged, so Reset Data or Delete All Data clears them.
    @discardableResult
    static func seedRandomFavorites(count: Int = 10, in context: ModelContext) async throws -> Int {
        let existing = try context.fetch(FetchDescriptor<Favorite>())
        let taken = Set(existing.map { "\($0.bookName)|\($0.chapterNumber)|\($0.verseNumber)" })
        let verses = await randomVerses(count: count, avoiding: taken)
        for item in verses {
            context.insert(Favorite(
                bookName: item.book,
                chapterNumber: item.chapter,
                verseNumber: item.verse.number,
                verseText: item.verse.text
            ))
        }
        try context.save()
        return verses.count
    }

    /// Highlights random verses in random colors. Titled like the sample highlights, so
    /// Remove Seeded Notes clears them.
    @discardableResult
    static func seedRandomHighlights(count: Int = 10, in context: ModelContext) async throws -> Int {
        let existing = try context.fetch(FetchDescriptor<VerseNote>()).filter { !$0.highlightColor.isEmpty }
        let taken = Set(existing.map { "\($0.bookName)|\($0.chapterNumber)|\($0.verseNumber)" })
        let verses = await randomVerses(count: count, avoiding: taken)
        for item in verses {
            let note = VerseNote(
                bookName: item.book,
                chapterNumber: item.chapter,
                verseNumber: item.verse.number,
                verseText: item.verse.text,
                highlightColor: (VerseHighlightColor.allCases.randomElement() ?? .yellow).rawValue
            )
            note.title = "\(sampleHighlightPrefix)\(item.book) \(item.chapter):\(item.verse.number)"
            context.insert(note)
        }
        try context.save()
        return verses.count
    }

    // MARK: - Delete all data

    /// Erases everything the app keeps: the whole library, reading and game stats, the reading
    /// position and pinned verse, note drafts, and every setting.
    /// Library deletions sync to CloudKit, and the stats resets are broadcast through iCloud,
    /// so other devices on the account are cleared too.
    static func deleteAllData(in context: ModelContext) async throws {
        try context.delete(model: Favorite.self)
        try context.delete(model: VerseNote.self)
        try context.delete(model: UserNote.self)
        try context.delete(model: Bookmark.self)
        try context.delete(model: SavedCrossReference.self)
        try context.delete(model: ReadingProgress.self)
        try context.save()

        iCloudSyncCoordinator.shared.resetAllGameDataToZero()
        iCloudSyncCoordinator.shared.resetAllBibleStatsAndSessions()

        await PinnedVerseStore.shared.clear()
        ReadingPositionStore.shared.clear()

        let fileManager = FileManager.default
        let support = URL.applicationSupportDirectory
        try? fileManager.removeItem(at: support.appending(path: "NoteDrafts", directoryHint: .isDirectory))

        DeveloperSettingsReset.perform()

        AppDataChanges.shared.bibleStatsChanged()
        AppDataChanges.shared.gameStatsChanged()
        AppDataChanges.shared.prayerStatsChanged()
        AppDataChanges.shared.studyTimeChanged()
        AppDataChanges.shared.chapterProgressChanged()
    }
}
#endif
