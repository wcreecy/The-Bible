// the entire code of the file with your changes goes here.
// Do not skip over anything.
import SwiftUI
import SwiftData
import Combine
import UserNotifications
import AudioToolbox
import UIKit
import HealthKit
import Foundation
import WidgetKit

private enum VerseScope: String { case old, new, whole, book }

// New: identifiers matching SettingsView’s reorderable/hideable cards
private enum HomeCardID: String, CaseIterable, Identifiable {
    case verseOfDay
    case dailyFocus
    case timer
    case resumeReading
    case streaks // Daily Bible Streak (now includes Daily Goal progress)
    case games   // Games
    case bibleStats // NEW: Bible Stats (Top 5 by reading time)
    var id: String { rawValue }
}

struct HomeView: View {
    // Visibility widened so split cards can reference it
    enum PrayerMode: String { case timer, stopwatch, focus }

    // Always keep newest progress first so `progressList.first` is canonical
    @Query(sort: \ReadingProgress.updatedAt, order: .reverse) private var progressList: [ReadingProgress]
    @State private var showPrayerStudySheet: Bool = false

    @State private var isTimerRunning: Bool = false
    @State private var isPaused: Bool = false
    @State private var remainingSeconds: Int = 0
    @AppStorage("prayerTimerEndDate") private var storedEndDate: Double = 0
    @AppStorage("prayerTimerRunning") private var storedRunning: Bool = false
    @AppStorage("prayerTimerPaused") private var storedPaused: Bool = false
    @AppStorage("prayerTimerRemainingWhenPaused") private var storedRemainingWhenPaused: Int = 0
    @AppStorage("prayerTimerTotalSeconds") private var storedTotalSeconds: Int = 0
    @AppStorage("verseOfDayScope") private var verseScopeRaw: String = "whole"
    @AppStorage("verseOfDaySpecificBook") private var verseSpecificBook: String = ""
    @AppStorage("prayerTimerStartDate") private var storedStartDate: Double = 0
    @AppStorage("healthKitPrompted") private var healthKitPrompted: Bool = false
    @AppStorage("mindfulSessionStartDate") private var mindfulStartDate: Double = 0
    @AppStorage("timerSoundSelection") private var timerSoundSelection: String = TimerSound.default.rawValue

    @AppStorage("didRequestNotifications") private var didRequestNotifications: Bool = false

    @AppStorage("verseOfDayPaused") private var verseOfDayPaused: Bool = false
    @AppStorage("verseOfDayBook") private var storedVerseBook: String = ""
    @AppStorage("verseOfDayChapter") private var storedVerseChapter: Int = 0
    @AppStorage("verseOfDayNumber") private var storedVerseNumber: Int = 0
    @AppStorage("verseOfDayText") private var storedVerseText: String = ""

    @AppStorage("prayerMode") private var prayerMode: PrayerMode = .timer
    @AppStorage("stopwatchRunning") private var stopwatchRunning: Bool = false
    @AppStorage("stopwatchStartDate") private var stopwatchStartDate: Double = 0
    @AppStorage("stopwatchAccumulated") private var stopwatchAccumulated: Int = 0
    @AppStorage("focusTitle") private var focusTitle: String = ""

    private var sharedDefaults: UserDefaults? { UserDefaults(suiteName: "group.bible.app") }

    @AppStorage("focusBody") private var focusBody: String = ""
    @State private var stopwatchElapsed: Int = 0

    @State private var hasSavedFocus: Bool = false
    @FocusState private var focusTitleIsFocused: Bool
    @FocusState private var focusBodyIsFocused: Bool

    @State private var isFocusBodyExpanded: Bool = false

    // NEW: saved-at timestamp for Daily Focus confirmation
    @State private var focusSavedAt: Date? = nil

    // On-demand ticker: only active during timer/stopwatch sessions
    @State private var tickerCancellable: AnyCancellable?
    @State private var showFinishedAlert: Bool = false
    @State private var finishHapticTimer: Timer? = nil

    @Environment(\.modelContext) private var modelContext
    @Query private var favorites: [Favorite]
    @EnvironmentObject private var coordinator: NavigationCoordinator
    @EnvironmentObject private var journalComposer: JournalComposer
    @State private var verseOfDay: HomeVerseRef? = nil

    @State private var showCopyToast: Bool = false
    @State private var showFocusSavedToast: Bool = false
    @State private var lastVerseAutoRefreshToken: String = ""
    @State private var isHealthKitAvailable: Bool = HealthKitManager.shared.isAvailable()

    @Environment(\.scenePhase) private var scenePhase

    private static let notificationID = "PrayerStudyTimerFinished"
    private static let notificationTitle = "Prayer/Study Finished"
    private static let notificationBody = "Your prayer/study timer has completed."

    private var selectedFinishSoundID: SystemSoundID {
        (TimerSound(rawValue: timerSoundSelection) ?? .default).systemSoundID
    }

    private var timerTintColor: Color {
        if remainingSeconds > 300 {
            return .green
        } else if remainingSeconds > 120 {
            return .yellow
        } else {
            return .red
        }
    }

    private var isEvening: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour >= 18 || hour < 5
    }

    private var verseCardTitle: String { isEvening ? "Word of the Night" : "Verse of the Day" }
    private var verseCardIcon: String { isEvening ? "moon.stars" : "sun.max.fill" }

    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
    private var iPadCardHeight: CGFloat { 200 }

    private var isEditingFocus: Bool {
        prayerMode == .focus && (focusTitleIsFocused || focusBodyIsFocused)
    }

    var progress: ReadingProgress? {
        progressList.first
    }

    // Verse-of-the-Day: configurable times and scheduler
    @AppStorage("votdRefresh1Hour") private var votdRefresh1Hour: Int = 6
    @AppStorage("votdRefresh1Minute") private var votdRefresh1Minute: Int = 0
    @AppStorage("votdRefresh2Hour") private var votdRefresh2Hour: Int = 18
    @AppStorage("votdRefresh2Minute") private var votdRefresh2Minute: Int = 0
    @State private var nextRefreshTimer: Timer?

    // Bible store for async/on-demand loading
    @StateObject private var bibleStore = BibleStore.shared

    // Debounced widget reload helper
    private func debouncedReloadAllWidgets() {
        DebouncedWidgetReloader.shared.reloadAll()
    }

    private func debouncedReload(kind: String) {
        DebouncedWidgetReloader.shared.reload(kind: kind)
    }

    private func startMindfulLoggingIfNeeded() {
        guard isHealthKitAvailable else { return }
        if mindfulStartDate == 0 {
            mindfulStartDate = Date().timeIntervalSince1970
        }
    }

    private func stopMindfulLogging() {
        guard isHealthKitAvailable else { return }
        if mindfulStartDate > 0 {
            let startDate = Date(timeIntervalSince1970: mindfulStartDate)
            let endDate = Date()
            if endDate > startDate {
                HealthKitManager.shared.saveMindfulSession(start: startDate, end: endDate, completion: nil)
            }
            mindfulStartDate = 0
        }
    }

    // MARK: - Home layout state (read from Settings)

    @AppStorage("homeCardOrder") private var homeCardOrderRaw: String = ""
    @AppStorage("homeCardHidden") private var homeCardHiddenRaw: String = ""

    @State private var layoutOrder: [HomeCardID] = HomeCardID.allCases
    @State private var hiddenSet: Set<HomeCardID> = []

    private func decodeHomeLayout() {
        // Order
        if let data = homeCardOrderRaw.data(using: .utf8),
           let ids = try? JSONDecoder().decode([String].self, from: data) {
            // Filter out any legacy "dailyGoal" id
            let filtered = ids.filter { $0 != "dailyGoal" }
            let mapped = filtered.compactMap { HomeCardID(rawValue: $0) }
            let missing = HomeCardID.allCases.filter { !mapped.contains($0) }
            layoutOrder = mapped + missing
        } else {
            layoutOrder = HomeCardID.allCases
        }
        // Hidden
        if let data = homeCardHiddenRaw.data(using: .utf8),
           let ids = try? JSONDecoder().decode([String].self, from: data) {
            let filtered = ids.filter { $0 != "dailyGoal" } // migrate legacy
            hiddenSet = Set(filtered.compactMap { HomeCardID(rawValue: $0) })
        } else {
            // Match Settings defaults: Games and Streaks hidden by default
            // NEW: Bible Stats hidden by default as requested
            hiddenSet = [.games, .streaks, .bibleStats]
        }
    }

    // MARK: - Next Verse Auto-Refresh Helpers (one-shot scheduler)

    private func dateForToday(hour: Int, minute: Int, from now: Date = Date()) -> Date? {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day], from: now)
        return cal.date(from: DateComponents(year: comps.year, month: comps.month, day: comps.day, hour: hour, minute: minute, second: 0))
    }

    private func nextAutoRefreshDate(from now: Date = Date()) -> Date {
        let cal = Calendar.current
        guard let startOfTodayRefresh1 = dateForToday(hour: votdRefresh1Hour, minute: votdRefresh1Minute, from: now),
              let startOfTodayRefresh2 = dateForToday(hour: votdRefresh2Hour, minute: votdRefresh2Minute, from: now) else {
            return now
        }
        if now < startOfTodayRefresh1 { return startOfTodayRefresh1 }
        if now < startOfTodayRefresh2 { return startOfTodayRefresh2 }
        let tomorrow = cal.date(byAdding: .day, value: 1, to: now) ?? now
        return dateForToday(hour: votdRefresh1Hour, minute: votdRefresh1Minute, from: tomorrow) ?? now
    }

    private var nextVerseRefreshDescription: String {
        if verseOfDayPaused { return "Auto refresh is paused." }
        let now = Date()
        let next = nextAutoRefreshDate(from: now)
        let cal = Calendar.current
        let isSameDay = cal.isDate(now, inSameDayAs: next)
        let isTomorrow = cal.isDate(next, inSameDayAs: cal.date(byAdding: .day, value: 1, to: now) ?? next)
        let dayString: String = isSameDay ? "Today" : (isTomorrow ? "Tomorrow" : next.formatted(date: .abbreviated, time: .omitted))
        let timeString = next.formatted(date: .omitted, time: .shortened)
        return "Next auto refresh: \(dayString) at \(timeString)"
    }

    private func scheduleNextVerseRefreshTimer() {
        nextRefreshTimer?.invalidate()
        guard !verseOfDayPaused else { return }
        let next = nextAutoRefreshDate()
        let interval = max(1, next.timeIntervalSinceNow)
        nextRefreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { _ in
            loadRandomVerse()
            // Schedule the next one
            scheduleNextVerseRefreshTimer()
        }
        RunLoop.main.add(nextRefreshTimer!, forMode: .common)
    }

    // MARK: - Shared Small Views / Helpers

    @ViewBuilder
    private func ModePicker(disabled: Bool) -> some View {
        Picker("Mode", selection: $prayerMode) {
            Text("Timer").tag(PrayerMode.timer)
            Text("Stopwatch").tag(PrayerMode.stopwatch)
        }
        .pickerStyle(.segmented)
        .controlSize(.small)
        .disabled(disabled)
        .frame(maxWidth: 280)
    }

    private func mirrorVerseToAppGroup(book: String, chapter: Int, verse: Int, text: String) {
        guard let shared = sharedDefaults else { return }
        shared.set(book, forKey: "verseOfDayBook")
        shared.set(chapter, forKey: "verseOfDayChapter")
        shared.set(verse, forKey: "verseOfDayNumber")
        shared.set(text, forKey: "verseOfDayText")
        // Reload only the Verse widget, debounced
        DebouncedWidgetReloader.shared.reload(kind: "VerseWidget")
    }

    private func mirrorLastReadToAppGroup() {
        guard let shared = sharedDefaults else { return }
        guard let p = progress else { return }
        // Resolve using BibleData (always available)
        if let book = BibleData.books.first(where: { $0.name == p.bookName }),
           let chapter = book.chapters.first(where: { $0.number == p.chapterNumber }),
           let verse = chapter.verses.first(where: { $0.number == p.verseNumber }) {
            shared.set(p.bookName, forKey: "lastReadBook")
            shared.set(p.chapterNumber, forKey: "lastReadChapter")
            shared.set(p.verseNumber, forKey: "lastReadVerse")
            shared.set(verse.text, forKey: "lastReadText")
            // Reload only the Last Read widget, debounced
            DebouncedWidgetReloader.shared.reload(kind: "LastReadWidget")
        }
    }

    private func handleOpenPendingVerse() {
        guard let shared = sharedDefaults else { return }
        guard let book = shared.string(forKey: "pendingOpenBook"),
              let chapter = shared.value(forKey: "pendingOpenChapter") as? Int,
              let verse = shared.value(forKey: "pendingOpenVerse") as? Int else { return }
        shared.removeObject(forKey: "pendingOpenBook")
        shared.removeObject(forKey: "pendingOpenChapter")
        shared.removeObject(forKey: "pendingOpenVerse")

        let books = bibleStore.isReady ? bibleStore.books : []
        guard let b = books.first(where: { $0.name == book }),
              let c = b.chapters.first(where: { $0.number == chapter }) else { return }
        coordinator.push(.reader(book: b, chapter: c, startVerse: verse))
    }

    // MARK: - Split cards to reduce type-checking complexity

    // Daily goal values for flame progress
    @AppStorage("dailyGoalMinutes") private var dailyGoalMinutes: Int = 30
    @AppStorage("dailyUsageTodaySeconds") private var dailyUsageTodaySeconds: Int = 0

    // Helper reused by TitleCardView
    private func goalMinutesString(_ minutes: Int) -> String {
        let mins = max(0, minutes)
        let hrs = mins / 60
        let rem = mins % 60
        if hrs == 0 { return "\(rem) min" }
        if rem == 0 { return "\(hrs) hr" }
        return "\(hrs) hr \(rem) min"
    }

    // Daily goal values (used inside Streaks card)
    @AppStorage("dailyGoalMinutes") private var dailyGoalMinutes_streaks: Int = 30
    @AppStorage("dailyUsageTodaySeconds") private var dailyUsageTodaySeconds_streaks: Int = 0
    @AppStorage("dailyUsageTodayKey") private var dailyUsageTodayKey: String = ""

    private var dailyGoalSeconds: Int { max(1, dailyGoalMinutes_streaks) * 60 }
    // Use Bible reading time (today) rather than app usage
    private var dailyProgress: Double {
        let used = max(0, BibleStatsStore.shared.totalForLast(days: 1))
        return min(1.0, Double(used) / Double(dailyGoalSeconds))
    }
    private var remainingSecondsToday: Int {
        let todayKey = BibleStatsStore.isoDateString(Date())
        let used = max(0, BibleStatsStore.shared.loadDailyTotals()[todayKey, default: 0])
        return max(0, dailyGoalSeconds - used)
    }
    private var remainingFormatted: String {
        if remainingSecondsToday == 0 { return "Goal reached" }
        let m = remainingSecondsToday / 60
        let s = remainingSecondsToday % 60
        return "\(m)m \(s)s left"
    }

    private func formatHMS(_ seconds: Int) -> String {
        let s = max(0, seconds)
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, sec)
        } else {
            return String(format: "%d:%02d", m, sec)
        }
    }

    @ViewBuilder
    private var streaksCard: some View {
        StreaksCard()
    }

    // Local UI state for expanding the calendar
    @State private var streaksExpanded: Bool = false
    // Track the month being displayed (start with current month)
    @State private var calendarMonthAnchor: Date = Date()

    private func startOfMonth(for date: Date) -> Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: date)
        return cal.date(from: comps) ?? date
    }
    private func daysGrid(for month: Date) -> [[Date?]] {
        let cal = Calendar.current
        let start = startOfMonth(for: month)
        guard let range = cal.range(of: .day, in: .month, for: start) else { return [] }
        let firstWeekday = cal.component(.weekday, from: start)
        let daysCount = range.count

        var grid: [[Date?]] = []
        var row: [Date?] = []

        let leading = (firstWeekday - cal.firstWeekday + 7) % 7
        for _ in 0..<leading { row.append(nil) }

        for day in 1...daysCount {
            if let d = cal.date(byAdding: .day, value: day - 1, to: start) {
                row.append(d)
                if row.count == 7 {
                    grid.append(row)
                    row = []
                }
            }
        }
        if !row.isEmpty {
            while row.count < 7 { row.append(nil) }
            grid.append(row)
        }
        return grid
    }

    private func isFuture(_ date: Date, relativeTo today: Date = Date()) -> Bool {
        let cal = Calendar.current
        if cal.isDate(date, inSameDayAs: today) { return false }
        return date > today
    }

    private struct DayCell: View {
        let dayNumber: Int
        let met: Bool
        let future: Bool

        var body: some View {
            VStack(spacing: 4) {
                Text("\(dayNumber)")
                    .font(.caption)
                    .foregroundStyle(future ? .tertiary : .secondary)
                Image(systemName: met ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(future ? AnyShapeStyle(.tertiary) : AnyShapeStyle(met ? Color.green : Color.red))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )
        }
    }

    private struct WeekRow: View {
        let dates: [Date?]

        var body: some View {
            HStack(spacing: 6) {
                ForEach(0..<7, id: \.self) { c in
                    if let day = dates[c] {
                        let dayNum = Calendar.current.component(.day, from: day)
                        let met = StreakTracker.isGoalMet(on: day)
                        let future = {
                            let cal = Calendar.current
                            if cal.isDate(day, inSameDayAs: Date()) { return false }
                            return day > Date()
                        }()
                        DayCell(dayNumber: dayNum, met: met, future: future)
                    } else {
                        Color.clear
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func calendarMonthView(anchor: Date) -> some View {
        let cal = Calendar.current
        let grid = daysGrid(for: anchor)
        let weekdays = cal.shortWeekdaySymbols

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button {
                    if let prev = cal.date(byAdding: .month, value: -1, to: anchor) {
                        calendarMonthAnchor = prev
                    }
                } label: {
                    Image(systemName: "chevron.left.circle.fill")
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    if let next = cal.date(byAdding: .month, value: 1, to: anchor) {
                        calendarMonthAnchor = next
                    }
                } label: {
                    Image(systemName: "chevron.right.circle.fill")
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(.blue)

            HStack {
                ForEach(weekdays, id: \.self) { w in
                    Text(w.uppercased())
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            VStack(spacing: 6) {
                ForEach(0..<grid.count, id: \.self) { r in
                    WeekRow(dates: grid[r])
                }
            }
        }
    }

    private func friendlyDate(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    // MARK: - Dynamic body using saved layout

    @ViewBuilder
    private func card(for id: HomeCardID) -> some View {
        switch id {
        case .verseOfDay:
            VerseOfDayCard(
                verseOfDay: $verseOfDay,
                verseOfDayPaused: $verseOfDayPaused,
                isBibleStoreReady: bibleStore.isReady,
                nextRefreshDescription: nextVerseRefreshDescription,
                onRefresh: { loadRandomVerse() },
                onCopy: { v in copyVerse(v) },
                onShareText: { v in shareText(bookName: v.bookName, chapter: v.chapterNumber, verse: v.verseNumber, text: v.verseText) },
                isFavorited: { v in isFavorited(v) },
                onToggleFavorite: { v in toggleFavorite(for: v) },
                onOpenReader: { v in
                    guard let book = BibleData.books.first(where: { $0.name == v.bookName }),
                          let chapter = book.chapters.first(where: { $0.number == v.chapterNumber }) else { return }
                    coordinator.push(.reader(book: book, chapter: chapter, startVerse: v.verseNumber))
                },
                onTogglePaused: {
                    let newValue = !verseOfDayPaused
                    verseOfDayPaused = newValue
                    if newValue, let v = verseOfDay {
                        storedVerseBook = v.bookName
                        storedVerseChapter = v.chapterNumber
                        storedVerseNumber = v.verseNumber
                        storedVerseText = v.verseText
                    }
                    mirrorVerseToAppGroup(book: storedVerseBook, chapter: storedVerseChapter, verse: storedVerseNumber, text: storedVerseText)
                    if verseOfDayPaused {
                        nextRefreshTimer?.invalidate()
                        nextRefreshTimer = nil
                    } else {
                        scheduleNextVerseRefreshTimer()
                    }
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                },
                title: verseCardTitle,
                icon: verseCardIcon
            )
            .contentShape(Rectangle())
            .onTapGesture {
                let generator = UIImpactFeedbackGenerator(style: .heavy)
                generator.impactOccurred()
                guard let v = verseOfDay,
                      let book = BibleData.books.first(where: { $0.name == v.bookName }),
                      let chapter = book.chapters.first(where: { $0.number == v.chapterNumber }) else { return }
                coordinator.push(.reader(book: book, chapter: chapter, startVerse: v.verseNumber))
            }
        case .dailyFocus:
            DailyFocusCard(
                focusTitle: $focusTitle,
                focusBody: $focusBody,
                hasSavedFocus: $hasSavedFocus,
                focusSavedAt: $focusSavedAt,
                focusTitleIsFocused: _focusTitleIsFocused.projectedValue,
                focusBodyIsFocused: _focusBodyIsFocused.projectedValue,
                isFocusBodyExpanded: $isFocusBodyExpanded,
                liveActivitiesEnabled: UserDefaults.standard.bool(forKey: "liveActivitiesEnabled"),
                onSave: {
                    sharedDefaults?.set(focusTitle, forKey: "focusTitle")
                    sharedDefaults?.set(focusBody, forKey: "focusBody")
                    let now = Date()
                    sharedDefaults?.set(now.timeIntervalSince1970, forKey: "focusSavedAt")
                    focusSavedAt = now

                    StopwatchActivityController.shared.cancel()
                    PrayerTimerActivityController.shared.ensureActivityForFocus(
                        title: focusTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : focusTitle,
                        body: focusBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : focusBody
                    )
                    hasSavedFocus = true
                    focusTitleIsFocused = false
                    focusBodyIsFocused = false
                    withAnimation(.spring()) { showFocusSavedToast = true }
                },
                onClear: {
                    focusTitle = ""
                    focusBody = ""
                    sharedDefaults?.set("", forKey: "focusTitle")
                    sharedDefaults?.set("", forKey: "focusBody")
                    sharedDefaults?.removeObject(forKey: "focusSavedAt")
                    focusSavedAt = nil

                    PrayerTimerActivityController.shared.cancel()
                    hasSavedFocus = false
                    focusTitleIsFocused = false
                    focusBodyIsFocused = false
                    isFocusBodyExpanded = false
                },
                onEnableLiveActivities: {
                    NotificationCenter.default.post(name: .openSettingsTab, object: nil)
                }
            )
        case .timer:
            if prayerMode == .timer {
                PrayerTimerCard(
                    prayerMode: $prayerMode,
                    isTimerRunning: isTimerRunning,
                    isPaused: isPaused,
                    remainingSeconds: remainingSeconds,
                    timerTintColor: timerTintColor,
                    formattedTime: { formattedTime($0) },
                    onOpenSetup: {
                        if isHealthKitAvailable && !healthKitPrompted {
                            Task { await requestHealthKitIfNeeded() }
                        }
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        showPrayerStudySheet = true
                    },
                    onStartPreset: { minutes in
                        startTimer(minutes: minutes)
                    },
                    onTogglePause: { togglePause() },
                    onAddOne: { addOneMinute() },
                    onAddFive: { addFiveMinutes() },
                    onAddTen: { addTenMinutes() },
                    onStop: { stopTimer() },
                    stopwatchRunning: stopwatchRunning,
                    modePicker: { disabled in AnyView(ModePicker(disabled: disabled)) }
                )
            } else {
                StopwatchCard(
                    prayerMode: $prayerMode,
                    stopwatchRunning: stopwatchRunning,
                    stopwatchElapsed: stopwatchElapsed,
                    formattedStopwatch: { formattedStopwatch($0) },
                    onStart: { startStopwatch() },
                    onPause: { pauseStopwatch() },
                    onStop: { stopStopwatch() },
                    isTimerRunning: isTimerRunning,
                    modePicker: { disabled in AnyView(ModePicker(disabled: disabled)) }
                )
            }
        case .resumeReading:
            ResumeReadingCard(
                progress: progress,
                onOpenReference: { p in
                    NotificationCenter.default.post(
                        name: .openBibleReference,
                        object: nil,
                        userInfo: [
                            "book": p.bookName,
                            "chapter": p.chapterNumber,
                            "verse": p.verseNumber
                        ]
                    )
                }
            )
        case .games:
            GamesCard(
                onOpenGames: {
                    NotificationCenter.default.post(name: .switchToTab, object: nil, userInfo: ["tab": 3])
                },
                onOpenStats: {
                    NotificationCenter.default.post(name: .switchToTab, object: nil, userInfo: ["tab": 6])
                }
            )
        case .streaks:
            streaksCard
        case .bibleStats:
            BibleStatsCard(
                bibleVM: bibleVM,
                scenePhase: scenePhase,
                onOpenStats: {
                    NotificationCenter.default.post(name: .switchToTab, object: nil, userInfo: ["tab": 6])
                }
            )
        }
    }

    var body: some View {
        // Build the list of visible cards in the saved order
        let activeCards: [HomeCardID] = layoutOrder.filter { !hiddenSet.contains($0) }

        ScrollView {
            if isPad {
                let leftCards = activeCards.enumerated().compactMap { $0.offset % 2 == 0 ? $0.element : nil }
                let rightCards = activeCards.enumerated().compactMap { $0.offset % 2 == 1 ? $0.element : nil }

                VStack(spacing: 16) {
                    TitleCardView(
                        isPad: isPad,
                        goalMinutes: dailyGoalMinutes,
                        todayReadingSeconds: BibleStatsStore.shared.todayTotalSeconds(),
                        streak: StreakTracker.currentStreak,
                        onSearch: {
                            DispatchQueue.main.async {
                                NotificationCenter.default.post(name: .switchToTab, object: nil, userInfo: ["tab": 5])
                            }
                        },
                        onRead: {
                            DispatchQueue.main.async {
                                NotificationCenter.default.post(name: .switchToTab, object: nil, userInfo: ["tab": 1])
                            }
                        },
                        onFavorites: {
                            DispatchQueue.main.async {
                                NotificationCenter.default.post(name: .switchToTab, object: nil, userInfo: ["tab": 4])
                            }
                        }
                    )

                    HStack(alignment: .top, spacing: 16) {
                        VStack(spacing: 16) {
                            ForEach(leftCards, id: \.self) { id in
                                card(for: id)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .top)

                        VStack(spacing: 16) {
                            ForEach(rightCards, id: \.self) { id in
                                card(for: id)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .top)
                    }
                }
                .padding(.horizontal, 24)
            } else {
                VStack(spacing: 16) {
                    TitleCardView(
                        isPad: isPad,
                        goalMinutes: dailyGoalMinutes,
                        todayReadingSeconds: BibleStatsStore.shared.todayTotalSeconds(),
                        streak: StreakTracker.currentStreak,
                        onSearch: {
                            DispatchQueue.main.async {
                                NotificationCenter.default.post(name: .switchToTab, object: nil, userInfo: ["tab": 5])
                            }
                        },
                        onRead: {
                            DispatchQueue.main.async {
                                NotificationCenter.default.post(name: .switchToTab, object: nil, userInfo: ["tab": 1])
                            }
                        },
                        onFavorites: {
                            DispatchQueue.main.async {
                                NotificationCenter.default.post(name: .switchToTab, object: nil, userInfo: ["tab": 4])
                            }
                        }
                    )

                    ForEach(layoutOrder, id: \.self) { cardID in
                        if !hiddenSet.contains(cardID) {
                            card(for: cardID)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("")
        .appToast(isPresented: $showCopyToast, symbol: "doc.on.doc", text: "Copied to Clipboard", tint: .blue)
        .appToast(isPresented: $showFocusSavedToast, symbol: "checkmark.seal.fill", text: "Focus Saved", tint: .green)
        .onAppear {
            Task { _ = await BibleLibrary.shared.bookNames() }

            bibleStore.ensureLoaded()

            if prayerMode == .focus { prayerMode = .timer }

            isTimerRunning = storedRunning
            isPaused = storedPaused
            isHealthKitAvailable = HealthKitManager.shared.isAvailable()

            if storedRunning {
                if isPaused {
                    remainingSeconds = storedRemainingWhenPaused
                } else if storedEndDate > 0 {
                    let remaining = Int(max(0, storedEndDate - Date().timeIntervalSince1970))
                    remainingSeconds = remaining
                    if remaining == 0 { handleTimerFinished() }
                }
            }

            if verseOfDayPaused {
                if !storedVerseBook.isEmpty && storedVerseChapter > 0 && storedVerseNumber > 0 && !storedVerseText.isEmpty {
                    verseOfDay = HomeVerseRef(bookName: storedVerseBook, chapterNumber: storedVerseChapter, verseNumber: storedVerseNumber, verseText: storedVerseText)
                    mirrorVerseToAppGroup(book: storedVerseBook, chapter: storedVerseChapter, verse: storedVerseNumber, text: storedVerseText)
                }
            } else {
                if !storedVerseBook.isEmpty && storedVerseChapter > 0 && storedVerseNumber > 0 && !storedVerseText.isEmpty {
                    verseOfDay = HomeVerseRef(bookName: storedVerseBook, chapterNumber: storedVerseChapter, verseNumber: storedVerseNumber, verseText: storedVerseText)
                    mirrorVerseToAppGroup(book: storedVerseBook, chapter: storedVerseChapter, verse: storedVerseNumber, text: storedVerseText)
                } else {
                    loadRandomVerse()
                }
            }

            if stopwatchRunning {
                let now = Date().timeIntervalSince1970
                let base = stopwatchAccumulated + Int(max(0, now - stopwatchStartDate))
                stopwatchElapsed = base
            } else {
                stopwatchElapsed = stopwatchAccumulated
            }

            if let shared = sharedDefaults {
                let savedTitle = (shared.string(forKey: "focusTitle") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let savedBody = (shared.string(forKey: "focusBody") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                hasSavedFocus = !(savedTitle.isEmpty && savedBody.isEmpty)
                let ts = shared.double(forKey: "focusSavedAt")
                if ts > 0 {
                    focusSavedAt = Date(timeIntervalSince1970: ts)
                } else {
                    focusSavedAt = nil
                }
            } else {
                hasSavedFocus = false
                focusSavedAt = nil
            }

            // One-time safety net: if multiple ReadingProgress rows exist, keep newest and delete older
            dedupeReadingProgress()

            mirrorLastReadToAppGroup()
            handleOpenPendingVerse()

            _ = handlePrayerTimerPendingAction()
            handleStopwatchPendingAction()

            scheduleNextVerseRefreshTimer()
            updateTickerSubscription()

            // Load saved layout on appear; migrate legacy dailyGoal id away
            decodeHomeLayout()

            // Initial load of Bible Stats (even if card is hidden, keep state fresh)
            bibleVM.refresh()

            // Initialize GameStats and bind to its version for immediate refresh
            gameStatsVersion = GameStats.shared.snapshot().totalAnswered
        }
        .onChange(of: homeCardOrderRaw) { _, _ in decodeHomeLayout() }
        .onChange(of: homeCardHiddenRaw) { _, _ in decodeHomeLayout() }
        .onReceive(NotificationCenter.default.publisher(for: .init("homeLayoutChanged"))) { _ in
            decodeHomeLayout()
        }
        .onChange(of: progressList) { _, _ in
            mirrorLastReadToAppGroup()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                startMindfulLoggingIfNeeded()
                _ = handlePrayerTimerPendingAction()
                handleStopwatchPendingAction()
                handleOpenPendingVerse()
                bibleVM.refresh()
            case .inactive, .background:
                if !isTimerRunning && !stopwatchRunning {
                    stopMindfulLogging()
                }
            @unknown default:
                break
            }
        }
        .onChange(of: isTimerRunning) { _, _ in updateTickerSubscription() }
        .onChange(of: stopwatchRunning) { _, _ in updateTickerSubscription() }
        .onChange(of: votdRefresh1Hour) { _, _ in scheduleNextVerseRefreshTimer() }
        .onChange(of: votdRefresh1Minute) { _, _ in scheduleNextVerseRefreshTimer() }
        .onChange(of: votdRefresh2Hour) { _, _ in scheduleNextVerseRefreshTimer() }
        .onChange(of: votdRefresh2Minute) { _, _ in scheduleNextVerseRefreshTimer() }
        .onReceive(NotificationCenter.default.publisher(for: .bibleStatsExternallyUpdated)) { _ in
            // bibleVM already refreshes on appear/active
        }
        .sheet(isPresented: $showPrayerStudySheet) {
            PrayerStudyTimerSetupView(onStart: { minutes in
                startTimer(minutes: minutes)
                showPrayerStudySheet = false
            })
            .presentationDetents([.medium, .large])
        }
        .alert("Prayer/Study Finished", isPresented: $showFinishedAlert) {
            Button("Dismiss", role: .cancel) {
                stopFinishAlerts()
                showFinishedAlert = false
            }
        } message: {
            Text("Your prayer/study timer has completed.")
        }
        .onDisappear {
            streaksExpanded = false
        }
    }

    // Ticker management
    private func updateTickerSubscription() {
        if isTimerRunning || stopwatchRunning {
            if tickerCancellable == nil {
                tickerCancellable = Timer.publish(every: 1, on: .main, in: .common)
                    .autoconnect()
                    .sink { _ in tick() }
            }
        } else {
            tickerCancellable?.cancel()
            tickerCancellable = nil
        }
    }

    // Suppression windows to prevent immediate Live Activity/timer recompute churn after +1/+5/+10
    @State private var suppressTimerActivityUpdatesUntil: Date = .distantPast
    @State private var suppressTimerRecomputeUntil: Date = .distantPast

    // Authoritative in-memory end date used briefly after adjustments to avoid @AppStorage staleness
    @State private var liveEndDate: TimeInterval = 0

    // One-shot token for pending actions so stale actions are ignored
    @AppStorage("prayerTimerLastActionToken") private var lastActionToken: String = ""

    private func tick() {
        if handlePrayerTimerPendingAction() {
            return
        }
        handleStopwatchPendingAction()

        if isEditingFocus { return }

        if isTimerRunning && !isPaused {
            let now = Date().timeIntervalSince1970

            if Date() < suppressTimerRecomputeUntil {
                let after = max(0, remainingSeconds - 1)
                remainingSeconds = after
            } else {
                let endToUse: TimeInterval
                let endDelta = abs(liveEndDate - storedEndDate)
                if liveEndDate > 0 && endDelta > 0.5 {
                    endToUse = liveEndDate
                } else {
                    endToUse = storedEndDate
                    liveEndDate = 0
                }

                let remaining = Int(max(0, endToUse - now))
                remainingSeconds = remaining
                if remaining == 0 { handleTimerFinished() }
            }

            if Date() >= suppressTimerActivityUpdatesUntil {
                PrayerTimerActivityController.shared.update(
                    remainingSeconds: remainingSeconds,
                    totalSeconds: storedTotalSeconds,
                    isPaused: isPaused
                )
            }
        }

        if stopwatchRunning {
            let now = Date().timeIntervalSince1970
            let base = stopwatchAccumulated + Int(max(0, now - stopwatchStartDate))
            stopwatchElapsed = base
            StopwatchActivityController.shared.update(elapsed: stopwatchElapsed, isRunning: true)
        }
    }

    private func startTimer(minutes: Int) {
        Task { await requestNotificationsIfNeeded() }
        if isHealthKitAvailable && !healthKitPrompted {
            Task { await requestHealthKitIfNeeded() }
        }

        let secs = max(1, minutes) * 60
        remainingSeconds = secs

        storedTotalSeconds = secs

        let start = Date()
        let end = start.addingTimeInterval(TimeInterval(secs))
        isPaused = false
        isTimerRunning = true

        storedRunning = true
        storedPaused = false
        storedStartDate = start.timeIntervalSince1970
        storedEndDate = end.timeIntervalSince1970

        // Set authoritative live end date and suppression windows
        liveEndDate = storedEndDate
        suppressTimerActivityUpdatesUntil = Date().addingTimeInterval(1.0)
        suppressTimerRecomputeUntil = Date().addingTimeInterval(1.75)

        storedRemainingWhenPaused = 0

        startMindfulLoggingIfNeeded()
        scheduleNotification(at: end)

        StopwatchActivityController.shared.cancel()
        PrayerTimerActivityController.shared.start(
            sessionName: "Prayer/Study",
            totalSeconds: storedTotalSeconds,
            remainingSeconds: remainingSeconds,
            isPaused: false
        )

        updateTickerSubscription()
    }

    private func togglePause() {
        guard isTimerRunning else { return }
        isPaused.toggle()
        storedPaused = isPaused

        if isPaused {
            let now = Date().timeIntervalSince1970
            let newRemain = Int(max(0, storedEndDate - now))
            remainingSeconds = newRemain
            storedRemainingWhenPaused = newRemain
            cancelNotification()
        } else {
            let newEnd = Date().addingTimeInterval(TimeInterval(remainingSeconds))
            storedEndDate = newEnd.timeIntervalSince1970

            // Set authoritative live end date and suppression windows
            liveEndDate = storedEndDate
            suppressTimerActivityUpdatesUntil = Date().addingTimeInterval(1.0)
            suppressTimerRecomputeUntil = Date().addingTimeInterval(1.75)

            storedRemainingWhenPaused = 0
            scheduleNotification(at: Date(timeIntervalSince1970: storedEndDate))
        }
        PrayerTimerActivityController.shared.update(
            remainingSeconds: remainingSeconds,
            totalSeconds: storedTotalSeconds,
            isPaused: isPaused
        )
    }

    private func addOneMinute() {
        guard isTimerRunning else { return }
        let delta: Int = 60
        if isPaused {
            let newRem = remainingSeconds + delta
            remainingSeconds = newRem
            storedRemainingWhenPaused = storedRemainingWhenPaused + delta
            storedTotalSeconds = storedTotalSeconds + delta
            PrayerTimerActivityController.shared.update(
                remainingSeconds: remainingSeconds,
                totalSeconds: storedTotalSeconds,
                isPaused: isPaused
            )
        } else {
            storedEndDate += TimeInterval(delta)
            storedTotalSeconds += delta

            let newRemaining = Int(max(0, storedEndDate - Date().timeIntervalSince1970))
            remainingSeconds = newRemaining

            // Set authoritative live end date and suppression windows
            liveEndDate = storedEndDate
            suppressTimerActivityUpdatesUntil = Date().addingTimeInterval(1.0)
            suppressTimerRecomputeUntil = Date().addingTimeInterval(1.75)

            scheduleNotification(at: Date(timeIntervalSince1970: storedEndDate))
            PrayerTimerActivityController.shared.update(
                remainingSeconds: remainingSeconds,
                totalSeconds: storedTotalSeconds,
                isPaused: isPaused
            )
        }

        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.impactOccurred()
    }

    private func addFiveMinutes() {
        guard isTimerRunning else { return }
        let delta: Int = 300
        if isPaused {
            let newRem = remainingSeconds + delta
            remainingSeconds = newRem
            storedRemainingWhenPaused = storedRemainingWhenPaused + delta
            storedTotalSeconds = storedTotalSeconds + delta
            PrayerTimerActivityController.shared.update(
                remainingSeconds: remainingSeconds,
                totalSeconds: storedTotalSeconds,
                isPaused: isPaused
            )
        } else {
            storedEndDate += TimeInterval(delta)
            storedTotalSeconds += delta

            let newRemaining = Int(max(0, storedEndDate - Date().timeIntervalSince1970))
            remainingSeconds = newRemaining

            // Set authoritative live end date and suppression windows
            liveEndDate = storedEndDate
            suppressTimerActivityUpdatesUntil = Date().addingTimeInterval(1.0)
            suppressTimerRecomputeUntil = Date().addingTimeInterval(1.75)

            scheduleNotification(at: Date(timeIntervalSince1970: storedEndDate))
            PrayerTimerActivityController.shared.update(
                remainingSeconds: remainingSeconds,
                totalSeconds: storedTotalSeconds,
                isPaused: isPaused
            )
        }

        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.impactOccurred()
    }

    private func addTenMinutes() {
        guard isTimerRunning else { return }
        let delta: Int = 600
        if isPaused {
            let newRem = remainingSeconds + delta
            remainingSeconds = newRem
            storedRemainingWhenPaused = storedRemainingWhenPaused + delta
            storedTotalSeconds = storedTotalSeconds + delta
            PrayerTimerActivityController.shared.update(
                remainingSeconds: remainingSeconds,
                totalSeconds: storedTotalSeconds,
                isPaused: isPaused
            )
        } else {
            storedEndDate += TimeInterval(delta)
            storedTotalSeconds += delta

            let newRemaining = Int(max(0, storedEndDate - Date().timeIntervalSince1970))
            remainingSeconds = newRemaining

            // Set authoritative live end date and suppression windows
            liveEndDate = storedEndDate
            suppressTimerActivityUpdatesUntil = Date().addingTimeInterval(1.0)
            suppressTimerRecomputeUntil = Date().addingTimeInterval(1.75)

            scheduleNotification(at: Date(timeIntervalSince1970: storedEndDate))
            PrayerTimerActivityController.shared.update(
                remainingSeconds: remainingSeconds,
                totalSeconds: storedTotalSeconds,
                isPaused: isPaused
            )
        }
        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.impactOccurred()
    }

    private func resetTimerState() {
        storedRunning = false
        storedPaused = false
        storedEndDate = 0
        storedRemainingWhenPaused = 0
        storedTotalSeconds = 0
        storedStartDate = 0

        isTimerRunning = false
        isPaused = false
        remainingSeconds = 0

        // Clear live end date
        liveEndDate = 0
    }

    private func stopTimer() {
        if scenePhase != .active {
            stopMindfulLogging()
        }
        resetTimerState()
        cancelNotification()
        stopFinishAlerts()
        PrayerTimerActivityController.shared.cancel()
        showFinishedAlert = false
        updateTickerSubscription()
    }

    private func formattedTime(_ totalSeconds: Int) -> String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    private func scheduleNotification(at date: Date) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.notificationID])

        let content = UNMutableNotificationContent()
        content.title = Self.notificationTitle
        content.body = Self.notificationBody
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, date.timeIntervalSinceNow), repeats: false)
        let request = UNNotificationRequest(identifier: Self.notificationID, content: content, trigger: trigger)
        center.add(request, withCompletionHandler: nil)
    }

    private func cancelNotification() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.notificationID])
    }

    private func handleTimerFinished() {
        if !isTimerRunning { return }
        if scenePhase != .active {
            stopMindfulLogging()
        }
        cancelNotification()
        resetTimerState()
        PrayerTimerActivityController.shared.finish()
        showFinishedAlert = true
        startFinishAlerts()
        updateTickerSubscription()
    }

    private func startFinishAlerts() {
        let soundID = selectedFinishSoundID
        finishHapticTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
            AudioServicesPlaySystemSound(soundID)
            AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
        }
        AudioServicesPlaySystemSound(soundID)
        AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
    }

    private func stopFinishAlerts() {
        finishHapticTimer?.invalidate()
        finishHapticTimer = nil
    }

    private func loadRandomVerse() {
        if verseOfDayPaused { return }
        let allBooks = BibleData.books
        guard !allBooks.isEmpty else { return }

        let scope = VerseScope(rawValue: verseScopeRaw) ?? .whole
        let books: [Book]
        switch scope {
        case .old:
            books = allBooks.filter { oldTestamentBooks.contains($0.name) }
        case .new:
            books = allBooks.filter { !oldTestamentBooks.contains($0.name) }
        case .whole:
            books = allBooks
        case .book:
            if let chosen = allBooks.first(where: { $0.name == verseSpecificBook }) {
                books = [chosen]
            } else {
                books = allBooks
            }
        }

        guard let book = books.randomElement(),
              let chapter = book.chapters.randomElement(),
              !chapter.verses.isEmpty,
              let verse = chapter.verses.randomElement() else { return }

        verseOfDay = HomeVerseRef(bookName: book.name, chapterNumber: chapter.number, verseNumber: verse.number, verseText: verse.text)
        storedVerseBook = book.name
        storedVerseChapter = chapter.number
        storedVerseNumber = verse.number
        storedVerseText = verse.text
        mirrorVerseToAppGroup(book: book.name, chapter: chapter.number, verse: verse.number, text: verse.text)
    }

    private func copyVerse(_ v: HomeVerseRef) {
        UIPasteboard.general.string = shareText(bookName: v.bookName, chapter: v.chapterNumber, verse: v.verseNumber, text: v.verseText)
        withAnimation(.spring()) { showCopyToast = true }
    }

    private func isFavorited(_ v: HomeVerseRef) -> Bool {
        favorites.contains { fav in
            fav.bookName == v.bookName && fav.chapterNumber == v.chapterNumber && fav.verseNumber == v.verseNumber
        }
    }

    private func toggleFavorite(for v: HomeVerseRef) {
        if let existing = favorites.first(where: { $0.bookName == v.bookName && $0.chapterNumber == v.chapterNumber && $0.verseNumber == v.verseNumber }) {
            modelContext.delete(existing)
            try? modelContext.save()
        } else {
            let fav = Favorite(bookName: v.bookName, chapterNumber: v.chapterNumber, verseNumber: v.verseNumber, verseText: v.verseText)
            modelContext.insert(fav)
            try? modelContext.save()
        }
    }

    // Stopwatch helper methods

    private func startStopwatch() {
        if isHealthKitAvailable && !healthKitPrompted {
            Task { await requestHealthKitIfNeeded() }
        }
        let now = Date().timeIntervalSince1970
        if stopwatchStartDate == 0 { stopwatchStartDate = now }
        stopwatchRunning = true
        startMindfulLoggingIfNeeded()
        PrayerTimerActivityController.shared.cancel()
        StopwatchActivityController.shared.start(sessionName: "Stopwatch", initialElapsed: stopwatchElapsed)
        updateTickerSubscription()
    }

    private func pauseStopwatch() {
        guard stopwatchRunning else { return }
        let now = Date().timeIntervalSince1970
        if stopwatchStartDate > 0 {
            let delta = Int(max(0, now - stopwatchStartDate))
            stopwatchAccumulated += delta
            stopwatchStartDate = 0
        }
        stopwatchRunning = false
        StopwatchActivityController.shared.update(elapsed: stopwatchElapsed, isRunning: false)
        updateTickerSubscription()
    }

    private func stopStopwatch() {
        if scenePhase != .active {
            stopMindfulLogging()
        }
        stopwatchRunning = false
        stopwatchStartDate = 0
        stopwatchAccumulated = 0
        stopwatchElapsed = 0
        StopwatchActivityController.shared.finish(finalStatus: "Stopped")
        updateTickerSubscription()
    }

    // New: mm:ss under an hour, hh:mm:ss at/after an hour
    private func formattedStopwatch(_ totalSeconds: Int) -> String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    // Returns true if an action was consumed
    @discardableResult
    private func handlePrayerTimerPendingAction() -> Bool {
        guard let shared = sharedDefaults else { return false }
        guard let action = shared.string(forKey: "prayerTimerPendingAction") else { return false }

        // Read token (new)
        let token = shared.string(forKey: "prayerTimerActionToken") ?? ""
        // If token already consumed, ignore stale action
        if !token.isEmpty && token == lastActionToken {
            // Clean up stale key to avoid repeated checks
            shared.removeObject(forKey: "prayerTimerPendingAction")
            shared.removeObject(forKey: "prayerTimerActionToken")
            return false
        }

        // Consume keys up-front
        shared.removeObject(forKey: "prayerTimerPendingAction")
        shared.removeObject(forKey: "prayerTimerActionToken")

        switch action {
        case "togglePause":
            if isTimerRunning { togglePause() }
        case "add5":
            if isTimerRunning { addFiveMinutes() }
        case "stop":
            if isTimerRunning { stopTimer() }
        default:
            break
        }
        // Record last consumed token
        if !token.isEmpty {
            lastActionToken = token
        }
        suppressTimerActivityUpdatesUntil = .distantPast
        return true
    }

    private func handleStopwatchPendingAction() {
        guard let shared = sharedDefaults else { return }
        guard let action = shared.string(forKey: "stopwatchPendingAction") else { return }
        shared.removeObject(forKey: "stopwatchPendingAction")
        switch action {
        case "togglePause":
            if stopwatchRunning { pauseStopwatch() } else { startStopwatch() }
        case "stop":
            if stopwatchRunning || stopwatchElapsed > 0 { stopStopwatch() }
        default:
            break
        }
    }

    // MARK: - Stopwatch control subviews

    @ViewBuilder
    private func stopwatchRunningControls() -> some View {
        Button(action: { pauseStopwatch() }) {
            Image(systemName: "pause.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.yellow)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Pause")

        Button(action: { stopStopwatch() }) {
            Image(systemName: "stop.circle.fill")
                .font(.system(size: 44))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.red)
        .accessibilityLabel("Stop")
    }

    @ViewBuilder
    private func stopwatchPausedControls() -> some View {
        Button(action: { startStopwatch() }) {
            Image(systemName: "play.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.green)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Resume")

        Button(action: { stopStopwatch() }) {
            Image(systemName: "stop.circle.fill")
                .font(.system(size: 44))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.red)
        .accessibilityLabel("Stop")
    }

    @ViewBuilder
    private func stopwatchReadyControls() -> some View {
        Button(action: { startStopwatch() }) {
            Image(systemName: "play.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Start")
    }

    // MARK: - Permissions (async/await)

    private func requestNotificationsIfNeeded() async {
        guard !didRequestNotifications else { return }
        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        didRequestNotifications = true
    }

    private func requestHealthKitIfNeeded() async {
        guard isHealthKitAvailable && !healthKitPrompted else { return }
        await withCheckedContinuation { continuation in
            HealthKitManager.shared.requestAuthorizationIfNeeded { _ in
                Task { @MainActor in
                    self.healthKitPrompted = true
                }
                continuation.resume()
            }
        }
    }

    // MARK: - Journal helper (matching ReadingView behavior)

    private func openJournalForReference(text: String) {
        journalComposer.present(initialBody: text, verseRef: nil, showTagColors: false)
    }

    // MARK: - Small helpers moved out of ViewBuilder to avoid result-builder declaration errors

    private func uniqueMaxIndex<T: Comparable & Equatable>(_ values: [T]) -> Int? {
        guard let maxVal = values.max() else { return nil }
        let indices = values.enumerated().filter { $0.element == maxVal }.map { $0.offset }
        return indices.count == 1 ? indices.first : nil
    }

    private func uniqueMinIndex<T: Comparable & Equatable>(_ values: [T]) -> Int? {
        guard let minVal = values.min() else { return nil }
        let indices = values.enumerated().filter { $0.element == minVal }.map { $0.offset }
        return indices.count == 1 ? indices.first : nil
    }

    // MARK: - ReadingProgress safety dedupe on Home (one-time)
    private func dedupeReadingProgress() {
        guard progressList.count > 1 else { return }
        // progressList is already sorted newest-first by the @Query
        let toDelete = progressList.dropFirst()
        for p in toDelete {
            modelContext.delete(p)
        }
        try? modelContext.save()
    }

    // MARK: - NEW: Games Card (Home) using centralized GameStats
    @State private var gameStatsVersion: Int = 0

    // MARK: - NEW: Bible Stats Card
    @StateObject private var bibleVM = HomeBibleStatsViewModel()
}

private let oldTestamentBooks: Set<String> = [
    "Genesis","Exodus","Leviticus","Numbers","Deuteronomy",
    "Joshua","Judges","Ruth",
    "1 Samuel","2 Samuel",
    "1 Kings","2 Kings",
    "1 Chronicles","2 Chronicles",
    "Ezra","Nehemiah","Esther",
    "Job","Psalms","Proverbs","Ecclesiastes","Song of Solomon",
    "Isaiah","Jeremiah","Lamentations","Ezekiel","Daniel",
    "Hosea","Joel","Amos","Obadiah","Jonah",
    "Micah","Nahum","Habakkuk","Zephaniah",
    "Haggai","Zechariah","Malachi"
]

// Note: HeroCard, button styles, DayCell, WeekRow,
// PrayerStudyTimerSetupView, and DebouncedWidgetReloader have been
// moved to their own files as part of UI extraction.

