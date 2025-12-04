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
    private enum PrayerMode: String { case timer, stopwatch, focus }

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

    // NEW: move popover state here so it persists
    @State private var showFocusInfoPopover: Bool = false

    // NEW: saved-at timestamp for Daily Focus confirmation
    @State private var focusSavedAt: Date? = nil

    // MARK: - DEBUG helpers
    private func dbgWrite<T>(_ name: String, old: T, new: T, note: String) {
        print("[TimerDBG][WRITE] \(name): \(old) -> \(new) :: \(note)")
    }
    private func dbgSnapshot(_ where_: String) {
        print("[TimerDBG][SNAPSHOT] \(where_) isTimerRunning=\(isTimerRunning) isPaused=\(isPaused) remaining=\(remainingSeconds) storedStartDate=\(storedStartDate) storedEndDate=\(storedEndDate) storedTotal=\(storedTotalSeconds) storedPaused=\(storedPaused) storedRunning=\(storedRunning) storedRemainingWhenPaused=\(storedRemainingWhenPaused)")
    }

    private struct ModernPillButtonStyle: ButtonStyle {
        var tint: Color = .accentColor
        @Environment(\.isEnabled) private var isEnabled
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(.footnote.weight(.semibold))
                .foregroundStyle(isEnabled ? .white : .secondary)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    Capsule(style: .continuous)
                        .fill(isEnabled ? tint : Color(.secondarySystemFill))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(tint.opacity(configuration.isPressed ? 0.6 : 0.35), lineWidth: configuration.isPressed ? 2 : 1)
                )
                .shadow(color: .black.opacity(configuration.isPressed ? 0.04 : 0.08), radius: configuration.isPressed ? 1 : 3, x: 0, y: configuration.isPressed ? 0 : 2)
                .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
                .animation(.spring(response: 0.22, dampingFraction: 0.85), value: configuration.isPressed)
        }
    }

    // White pill style (for "Read" button): white background, black text, subtle stroke
    private struct WhitePillButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.black)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.white)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.black.opacity(configuration.isPressed ? 0.35 : 0.2), lineWidth: configuration.isPressed ? 2 : 1)
                )
                .shadow(color: .black.opacity(configuration.isPressed ? 0.04 : 0.08), radius: configuration.isPressed ? 1 : 3, x: 0, y: configuration.isPressed ? 0 : 2)
                .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
                .animation(.spring(response: 0.22, dampingFraction: 0.9), value: configuration.isPressed)
        }
    }

    // New: Subtle pill style used in the title card for calmer appearance
    private struct SubtlePillButtonStyle: ButtonStyle {
        var emphasized: Bool = false
        // Add optional size scaling for iPad
        var sizeScale: CGFloat = 1.0
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(.system(size: 13 * sizeScale, weight: .semibold))
                .foregroundStyle(emphasized ? Color.primary : Color.secondary)
                .padding(.vertical, 6 * sizeScale)
                .padding(.horizontal, 10 * sizeScale)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: .black.opacity(configuration.isPressed ? 0.02 : 0.04), radius: configuration.isPressed ? 0.5 : 1.5, x: 0, y: configuration.isPressed ? 0 : 1)
                .scaleEffect(configuration.isPressed ? 0.99 : 1.0)
                .animation(.spring(response: 0.22, dampingFraction: 0.9), value: configuration.isPressed)
        }
    }

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
    @State private var timeMarker: Int = 0
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

    // Small filling flame icon
    private struct FlameFillIcon: View {
        var progress: Double // 0...1
        var size: CGFloat = 20
        var tint: Color = .orange

        var clamped: Double { max(0, min(1, progress)) }

        var body: some View {
            ZStack {
                // Filled layer masked by vertical progress
                Image(systemName: "flame.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(tint)
                    .mask(
                        GeometryReader { geo in
                            let h = geo.size.height
                            let fillHeight = h * clamped
                            Rectangle()
                                .frame(width: geo.size.width, height: fillHeight)
                                .position(x: geo.size.width / 2, y: h - fillHeight / 2)
                        }
                    )
                // Outline on top to keep “unfilled” look
                Image(systemName: "flame")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.secondary)
            }
            .frame(width: size, height: size)
            .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var titleCard: some View {
        // Determine iPad-specific sizing
        let isPad = self.isPad
        let buttonScale: CGFloat = isPad ? 1.25 : 1.0
        let titleFont: Font = isPad ? .system(.largeTitle, design: .default) : .largeTitle
        let titleWeight: Font.Weight = .black
        let subtitleFont: Font = isPad ? .title3.weight(.semibold) : .subheadline.weight(.semibold)

        // Compute today's daily goal progress for the flame
        let goalSeconds = max(1, dailyGoalMinutes) * 60
        // Use Bible reading time (today) from BibleStatsStore instead of app usage time
        let todayReadingSeconds = BibleStatsStore.shared.totalForLast(days: 1)
        let progress = min(1.0, Double(max(0, todayReadingSeconds)) / Double(goalSeconds))
        let percent = Int(round(progress * 100))
        let streak = StreakTracker.currentStreak

        HeroCard(
            title: "Word of God",
            subtitle: nil,
            icon: "book.fill",
            tint: .blue,
            titleFont: titleFont,
            titleFontWeight: titleWeight,
            centerHeader: true, // Center on iPhone and iPad
            titleAccessory: {
                // Place small flame next to the title
                HStack(spacing: 6) {
                    FlameFillIcon(progress: progress, size: isPad ? 22 : 18, tint: .orange)
                        .accessibilityHidden(true)
                }
            }
        ) {
            VStack(spacing: isPad ? 16 : 8) {
                Text("What does God have for YOU today?")
                    .font(subtitleFont)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
                    .accessibilityLabel("What does God have for you today? Daily goal progress \(percent) percent. Current streak \(streak) days.")

                HStack(spacing: isPad ? 16 : 12) {
                    Button {
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(name: .switchToTab, object: nil, userInfo: ["tab": 5])
                        }
                    } label: {
                        Label("Search", systemImage: "magnifyingglass")
                            .lineLimit(1)
                            .allowsTightening(true)
                            .minimumScaleFactor(0.85)
                    }
                    .buttonStyle(SubtlePillButtonStyle(emphasized: false, sizeScale: buttonScale))

                    Button {
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(name: .switchToTab, object: nil, userInfo: ["tab": 1])
                        }
                    } label: {
                        Label("Read", systemImage: "book")
                            .lineLimit(1)
                            .allowsTightening(true)
                            .minimumScaleFactor(0.85)
                    }
                    .buttonStyle(SubtlePillButtonStyle(emphasized: true, sizeScale: buttonScale))

                    Button {
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(name: .switchToTab, object: nil, userInfo: ["tab": 4])
                        }
                    } label: {
                        Label("Favorites", systemImage: "heart")
                            .lineLimit(1)
                            .allowsTightening(true)
                            .minimumScaleFactor(0.85)
                    }
                    .buttonStyle(SubtlePillButtonStyle(emphasized: false, sizeScale: buttonScale))
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .frame(maxWidth: 700)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    @ViewBuilder
    private var verseOfDayCard: some View {
        HeroCard(
            title: verseCardTitle,
            subtitle: nil,
            icon: verseCardIcon,
            tint: .orange,
            trailingAccessory: {
                HStack(spacing: 8) {
                    if verseOfDayPaused {
                        Text("Paused")
                            .font(.caption2).bold()
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule().fill(Color.red.opacity(0.15))
                            )
                            .overlay(
                                Capsule().stroke(Color.red.opacity(0.4), lineWidth: 1)
                            )
                            .foregroundStyle(.red)
                    }
                    Button(action: {
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
                    }) {
                        Image(systemName: verseOfDayPaused ? "pause.circle.fill" : "pause.circle")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(verseOfDayPaused ? Color.red : Color.blue)
                    .accessibilityLabel(verseOfDayPaused ? "Unpause Verse Refresh" : "Pause Verse Refresh")
                    .help(verseOfDayPaused ? "Unpause Verse Refresh" : "Pause Verse Refresh")
                }
            }
        ) {
            VStack(alignment: .leading, spacing: 10) {
                if let v = verseOfDay {
                    Text(v.verseText)
                        .font(.headline)
                        .italic()
                        .lineLimit(8)
                        .truncationMode(.tail)
                    Text("\(v.bookName) \(v.chapterNumber):\(v.verseNumber)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 24) {
                        Button(action: { loadRandomVerse() }) {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        .labelStyle(.iconOnly)
                        .foregroundStyle(verseOfDayPaused ? AnyShapeStyle(.secondary) : AnyShapeStyle(.green))
                        .font(.title3)
                        .help("Refresh")
                        .disabled(verseOfDayPaused)

                        Button(action: {
                            copyVerse(v)
                        }) {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                        .labelStyle(.iconOnly)
                        .font(.title3)
                        .help("Copy")

                        ShareLink(item: shareText(bookName: v.bookName, chapter: v.chapterNumber, verse: v.verseNumber, text: v.verseText)) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .font(.title3)
                        .help("Share")

                        Button(action: {
                            let refText = "\(v.bookName) \(v.chapterNumber):\(v.verseNumber)"
                            openJournalForReference(text: refText)
                        }) {
                            Image(systemName: "book.closed")
                        }
                        .font(.title3)
                        .foregroundStyle(.brown)
                        .help("Journal")

                        Button(action: { toggleFavorite(for: v) }) {
                            Image(systemName: isFavorited(v) ? "heart.fill" : "heart")
                                .foregroundStyle(.red)
                        }
                        .font(.title3)
                        .help("Favorite")
                    }
                    .frame(maxWidth: .infinity)

                    Text(nextVerseRefreshDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        if !bibleStore.isReady {
                            Text("Loading verse data…")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .redacted(reason: .placeholder)
                        } else {
                            Text("Verse will refresh automatically at your selected times.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Text(nextVerseRefreshDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                let generator = UIImpactFeedbackGenerator(style: .heavy)
                generator.impactOccurred()
                guard let v = verseOfDay,
                      let book = BibleData.books.first(where: { $0.name == v.bookName }),
                      let chapter = book.chapters.first(where: { $0.number == v.chapterNumber }) else { return }
                coordinator.push(.reader(book: book, chapter: chapter, startVerse: v.verseNumber))
            }
            .contextMenu {
                if let v = verseOfDay {
                    Button {
                        copyVerse(v)
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }

                    ShareLink(item: shareText(bookName: v.bookName, chapter: v.chapterNumber, verse: v.verseNumber, text: v.verseText)) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var dailyFocusCard: some View {
        @AppStorage("liveActivitiesEnabled") var liveActivitiesEnabled: Bool = true

        HeroCard(
            title: "Daily Focus",
            subtitle: nil,
            icon: "target",
            tint: .purple,
            trailingAccessory: {
                HStack(spacing: 8) {
                    if hasSavedFocus {
                        Text("Saved")
                            .font(.caption2).bold()
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule().fill(Color.green.opacity(0.15))
                            )
                            .overlay(
                                Capsule().stroke(Color.green.opacity(0.5), lineWidth: 1)
                            )
                            .foregroundStyle(.green)
                            .accessibilityHidden(false)
                            .accessibilityLabel("Saved Focus")
                    }
                    Button {
                        showFocusInfoPopover.toggle()
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showFocusInfoPopover) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("About Daily Focus")
                                    .font(.headline)
                                Text("Type a title and optional notes, then save. Your focus will appear on the dynamic island (iPhone only) and the lock screen when live activities are enabled (enable/disable live activities from the app's settings menu).")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                Button("Got it") { showFocusInfoPopover = false }
                                    .buttonStyle(.borderedProminent)
                            }
                            .padding()
                        }
                        .presentationDetents([.medium, .large])
                    }
                }
            }
        ) {
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Today's Focus")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    TextField("What's your focus on today?", text: $focusTitle)
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.done)
                        .focused($focusTitleIsFocused)
                }

                let hasTitle = !focusTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

                if hasTitle && isFocusBodyExpanded {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        ZStack(alignment: .topLeading) {
                            if focusBody.isEmpty {
                                Text("Enter your focus notes…")
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                            }
                            TextEditor(text: $focusBody)
                                .focused($focusBodyIsFocused)
                                .frame(minHeight: 120)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                                )
                        }
                    }
                }

                let hasTypedLetter: Bool = {
                    let letters = CharacterSet.letters
                    let t = focusTitle.unicodeScalars.contains { letters.contains($0) }
                    let b = focusBody.unicodeScalars.contains { letters.contains($0) }
                    return t || b
                }()

                HStack(spacing: 12) {
                    Button {
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
                    } label: {
                        Label("Save", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(ModernPillButtonStyle(tint: .green))
                    .controlSize(.regular)
                    .accessibilityLabel("Save Focus")
                    .accessibilityHint("Saves your daily focus and shows it on the Dynamic Island")
                    .disabled(!hasTypedLetter)

                    Button {
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
                    } label: {
                        Label("Clear", systemImage: "xmark.circle.fill")
                    }
                    .buttonStyle(ModernPillButtonStyle(tint: .red))
                    .controlSize(.regular)
                    .accessibilityLabel("Clear Focus")
                    .accessibilityHint("Clears your daily focus and removes it from the Dynamic Island")
                    .disabled(!hasTitle)

                    if hasTitle {
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                                isFocusBodyExpanded = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                focusBodyIsFocused = true
                            }
                        } label: {
                            Image(systemName: "chevron.down.circle")
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Show Notes")
                        .accessibilityHint("Opens the focus notes field")
                    }
                }
                .padding(.top, 4)
                .toolbar { ToolbarItem(placement: .keyboard) { Button("Done") { focusTitleIsFocused = false; focusBodyIsFocused = false } } }

                if hasSavedFocus, let savedAt = focusSavedAt {
                    let cal = Calendar.current
                    let isToday = cal.isDateInToday(savedAt)
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.seal")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text(isToday ? "Today’s Focus saved at \(savedAt.formatted(date: .omitted, time: .shortened))"
                                     : "Focus saved on \(savedAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.top, 2)
                }

                if !liveActivitiesEnabled {
                    HStack(alignment: .center, spacing: 8) {
                        Image(systemName: "livephoto.slash")
                            .foregroundStyle(.secondary)
                        Text("Live Activities are off. Enable in Settings to show your Focus on the Lock Screen and Dynamic Island.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 8)
                        Button("Enable") {
                            NotificationCenter.default.post(name: .openSettingsTab, object: nil)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .tint(.purple)
                    }
                    .padding(.top, 6)
                }
            }
        }
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
        // CHANGED: align with Stats tab by using bibleVM.todaySeconds (session-derived)
        let used = max(0, bibleVM.todaySeconds)
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

    // Friendly formatter for goal minutes (e.g., "30 min", "1 hr", "1 hr 15 min")
    private func goalMinutesString(_ minutes: Int) -> String {
        let mins = max(0, minutes)
        let hrs = mins / 60
        let rem = mins % 60
        if hrs == 0 { return "\(rem) min" }
        if rem == 0 { return "\(hrs) hr" }
        return "\(hrs) hr \(rem) min"
    }

    @ViewBuilder
    private var timerCard: some View {
        Group {
            if prayerMode == .timer {
                if isTimerRunning {
                    HeroCard(
                        title: "Prayer Timer",
                        subtitle: nil,
                        icon: "timer",
                        tint: timerTintColor,
                        backgroundColor: isTimerRunning ? timerTintColor.opacity(0.20) : nil,
                        strokeColor: isTimerRunning ? timerTintColor.opacity(0.35) : nil,
                        trailingAccessory: {
                            ModePicker(disabled: isTimerRunning || stopwatchRunning)
                        }
                    ) {
                        HStack(alignment: .center, spacing: 16) {
                            HStack(spacing: 16) {
                                Button(action: { togglePause() }) {
                                    Image(systemName: isPaused ? "play.circle.fill" : "pause.circle.fill")
                                        .font(.system(size: 44))
                                        .foregroundStyle(isPaused ? Color.green : timerTintColor)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(isPaused ? "Resume" : "Pause")

                                Button(action: { stopTimer() }) {
                                    Image(systemName: "stop.circle.fill")
                                        .font(.system(size: 44))
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Stop")
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Text(formattedTime(remainingSeconds))
                                .font(.system(size: 36, weight: .semibold, design: .monospaced))
                                .foregroundStyle(timerTintColor)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    let generator = UIImpactFeedbackGenerator(style: .light)
                                    generator.impactOccurred()
                                    togglePause()
                                }
                                .accessibilityAddTraits(.isButton)
                                .accessibilityLabel(isPaused ? "Resume timer" : "Pause timer")
                                .accessibilityHint("Tap the time to \(isPaused ? "resume" : "pause")")

                            HStack(spacing: 16) {
                                Button(action: { addOneMinute() }) {
                                    Text("+1")
                                        .font(.subheadline.weight(.semibold))
                                        .frame(width: 40, height: 40)
                                        .foregroundStyle(.white)
                                        .background(Circle().fill(Color.blue))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Add 1 minute")

                                Button(action: { addFiveMinutes() }) {
                                    Text("+5")
                                        .font(.subheadline.weight(.semibold))
                                        .frame(width: 40, height: 40)
                                        .foregroundStyle(.white)
                                        .background(Circle().fill(Color.blue))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Add 5 minutes")
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                } else {
                    HeroCard(
                        title: "Prayer Timer",
                        subtitle: nil,
                        icon: "timer",
                        tint: .blue,
                        trailingAccessory: {
                            ModePicker(disabled: isTimerRunning || stopwatchRunning)
                        }
                    ) {
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                Button {
                                    if isHealthKitAvailable && !healthKitPrompted {
                                        Task { await requestHealthKitIfNeeded() }
                                    }
                                    let generator = UIImpactFeedbackGenerator(style: .light)
                                    generator.impactOccurred()
                                    showPrayerStudySheet = true
                                } label: {
                                    Image(systemName: "slider.horizontal.3")
                                        .font(.subheadline.weight(.semibold))
                                        .frame(width: 40, height: 40)
                                        .foregroundStyle(.primary)
                                        .background(
                                            Circle().fill(Color(.secondarySystemBackground))
                                        )
                                        .overlay(
                                            Circle().stroke(Color.gray.opacity(0.25), lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Custom duration")

                                Button { startTimer(minutes: 5) } label: { presetCircle("5") }
                                .accessibilityLabel("Start 5 minutes")

                                Button { startTimer(minutes: 10) } label: { presetCircle("10") }
                                .accessibilityLabel("Start 10 minutes")

                                Button { startTimer(minutes: 15) } label: { presetCircle("15") }
                                .accessibilityLabel("Start 15 minutes")

                                Button { startTimer(minutes: 20) } label: { presetCircle("20") }
                                .accessibilityLabel("Start 20 minutes")

                                Button { startTimer(minutes: 30) } label: { presetCircle("30") }
                                .accessibilityLabel("Start 30 minutes")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 4)

                            Text(formattedTime(remainingSeconds == 0 ? 0 : remainingSeconds))
                                .font(.system(size: 36, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 2)
                        }
                    }
                }
            } else if prayerMode == .stopwatch {
                HeroCard(
                    title: "Stopwatch",
                    subtitle: nil,
                    icon: "stopwatch",
                    tint: .blue,
                    trailingAccessory: {
                        ModePicker(disabled: isTimerRunning || stopwatchRunning)
                    }
                ) {
                    HStack(alignment: .center, spacing: 16) {
                        Group {
                            if stopwatchRunning {
                                Button(action: { pauseStopwatch() }) {
                                    Image(systemName: "pause.circle.fill")
                                        .font(.system(size: 44))
                                        .foregroundStyle(.yellow)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Pause")
                            } else if stopwatchElapsed > 0 {
                                Button(action: { startStopwatch() }) {
                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 44))
                                        .foregroundStyle(.green)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Resume")
                            } else {
                                Color.clear.frame(width: 44, height: 44)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Text(formattedStopwatch(stopwatchElapsed))
                            .font(.system(size: 36, weight: .semibold, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(stopwatchRunning ? .primary : .secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                let gen = UIImpactFeedbackGenerator(style: .light)
                                gen.impactOccurred()
                                if stopwatchRunning {
                                    pauseStopwatch()
                                } else {
                                    startStopwatch()
                                }
                            }
                            .accessibilityAddTraits(.isButton)
                            .accessibilityLabel(stopwatchRunning ? "Pause stopwatch" : (stopwatchElapsed > 0 ? "Resume stopwatch" : "Start stopwatch"))
                            .accessibilityHint("Tap the time to \(stopwatchRunning ? "pause" : (stopwatchElapsed > 0 ? "resume" : "start"))")

                        HStack(spacing: 16) {
                            if stopwatchRunning {
                                Button(action: { stopStopwatch() }) {
                                    Image(systemName: "stop.circle.fill")
                                        .font(.system(size: 44))
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.red)
                                .accessibilityLabel("Stop")
                            } else if stopwatchElapsed > 0 {
                                Button(action: { stopStopwatch() }) {
                                    Image(systemName: "stop.circle.fill")
                                        .font(.system(size: 44))
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.red)
                                .accessibilityLabel("Stop")
                            } else {
                                Button(action: { startStopwatch() }) {
                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 44))
                                        .foregroundStyle(.green)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Start")
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
        }
    }

    private func presetCircle(_ label: String) -> some View {
        Text(label)
            .font(.subheadline.weight(.semibold))
            .frame(width: 40, height: 40)
            .foregroundStyle(.primary)
            .background(Circle().fill(Color(.secondarySystemBackground)))
            .overlay(Circle().stroke(Color.gray.opacity(0.25), lineWidth: 1))
            .buttonStyle(.plain)
    }

    @ViewBuilder
    private var resumeCard: some View {
        if let progress = progress,
           let book = BibleData.books.first(where: { $0.name == progress.bookName }),
           let chapter = book.chapters.first(where: { $0.number == progress.chapterNumber }) {
            let verseText = chapter.verses.first(where: { $0.number == progress.verseNumber })?.text
            Button(action: {
                NotificationCenter.default.post(
                    name: .openBibleReference,
                    object: nil,
                    userInfo: [
                        "book": progress.bookName,
                        "chapter": progress.chapterNumber,
                        "verse": progress.verseNumber
                    ]
                )
            }) {
                HeroCard(
                    title: "",
                    subtitle: nil,
                    icon: nil,
                    tint: .blue
                ) {
                    HStack(alignment: .center, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "bookmark.fill")
                                .font(.title3)
                                .foregroundStyle(.blue)
                            Text("Continue Reading")
                                .font(.headline)
                                .bold()
                        }
                        Spacer()
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(progress.bookName) \(progress.chapterNumber):\(progress.verseNumber)")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.primary)

                        if let verseText, !verseText.isEmpty {
                            Text("“\(verseText)”")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .truncationMode(.tail)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
        } else {
            HeroCard(
                title: "",
                subtitle: nil,
                icon: nil,
                tint: .blue
            ) {
                HStack(alignment: .center, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "bookmark.fill")
                            .font(.title3)
                            .foregroundStyle(.blue)
                        Text("Continue Reading")
                            .font(.headline)
                            .bold()
                    }
                    Spacer()
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Start reading from the Bible tab")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - NEW: Games Card

    private struct GameStat {
        let name: String
        let correct: Int
        let answered: Int
        let bestStreak: Int?
    }

    private func readInt(_ key: String) -> Int {
        UserDefaults.standard.integer(forKey: key)
    }

    private var quizStat: GameStat {
        let c = readInt("quizAllTimeCorrect_easy") + readInt("quizAllTimeCorrect_normal") + readInt("quizAllTimeCorrect_hard")
        let a = readInt("quizAllTimeAnswered_easy") + readInt("quizAllTimeAnswered_normal") + readInt("quizAllTimeAnswered_hard")
        let best = max(readInt("quizAllTimeBestStreak_easy"), readInt("quizAllTimeBestStreak_normal"), readInt("quizAllTimeBestStreak_hard"))
        return .init(name: "Quiz", correct: c, answered: a, bestStreak: best)
    }

    private var hangmanStat: GameStat {
        // Per-difficulty keys
        let c = readInt("hangmanAllTimeCorrect_easy") + readInt("hangmanAllTimeCorrect_medium") + readInt("hangmanAllTimeCorrect_hard") + readInt("hangmanAllTimeCorrect")
        let a = readInt("hangmanAllTimeAnswered_easy") + readInt("hangmanAllTimeAnswered_medium") + readInt("hangmanAllTimeAnswered_hard") + readInt("hangmanAllTimeAnswered")
        let best = max(readInt("hangmanAllTimeBestStreak_easy"), readInt("hangmanAllTimeBestStreak_medium"), readInt("hangmanAllTimeBestStreak_hard"), readInt("hangmanAllTimeBestStreak"))
        return .init(name: "Hangman", correct: c, answered: a, bestStreak: best == 0 ? nil : best)
    }

    private var refMatchStat: GameStat {
        let c = readInt("refmatchAllTimeCorrect_easy") + readInt("refmatchAllTimeCorrect_medium") + readInt("refmatchAllTimeCorrect_hard") + readInt("refmatchAllTimeCorrect")
        let a = readInt("refmatchAllTimeAnswered_easy") + readInt("refmatchAllTimeAnswered_medium") + readInt("refmatchAllTimeAnswered_hard") + readInt("refmatchAllTimeAnswered")
        let best = max(readInt("refmatchAllTimeBestStreak_easy"), readInt("refmatchAllTimeBestStreak_medium"), readInt("refmatchAllTimeBestStreak_hard"), readInt("refmatchAllTimeBestStreak"))
        return .init(name: "Verse Match", correct: c, answered: a, bestStreak: best == 0 ? nil : best)
    }

    private var beatClockStat: GameStat {
        let c = readInt("beatclockAllTimeCorrect_easy") + readInt("beatclockAllTimeCorrect_medium") + readInt("beatclockAllTimeCorrect_hard")
        let a = readInt("beatclockAllTimeAnswered_easy") + readInt("beatclockAllTimeAnswered_medium") + readInt("beatclockAllTimeAnswered_hard")
        let best = max(readInt("beatclockAllTimeBestStreak_easy"), readInt("beatclockAllTimeBestStreak_medium"), readInt("beatclockAllTimeBestStreak_hard"))
        return .init(name: "Beat the Clock", correct: c, answered: a, bestStreak: best)
    }

    private var bookOrderStat: GameStat {
        let c = readInt("bookorderAllTimeCorrect")
        let a = readInt("bookorderAllTimeAnswered")
        let best = readInt("bookorderAllTimeBestStreak")
        return .init(name: "Book Order", correct: c, answered: a, bestStreak: best == 0 ? nil : best)
    }

    private var allGameStats: [GameStat] {
        [quizStat, hangmanStat, refMatchStat, beatClockStat, bookOrderStat]
    }

    private var totalAnsweredAllGames: Int {
        allGameStats.reduce(0) { $0 + $1.answered }
    }
    private var totalCorrectAllGames: Int {
        allGameStats.reduce(0) { $0 + $1.correct }
    }

    private func percent(_ correct: Int, _ answered: Int) -> Double {
        guard answered > 0 else { return 0 }
        return (Double(correct) / Double(answered)) * 100.0
    }

    private func colorForPercent(_ pct: Double) -> Color {
        if pct < 60 { return .red }
        else if pct < 75 { return .orange }
        else if pct < 90 { return .purple }
        else { return .green }
    }

    // Collapsible Games Card state
    @State private var gamesExpanded: Bool = false

    @ViewBuilder
    private var gamesCard: some View {
        let totalAnswered = totalAnsweredAllGames
        let totalCorrect = totalCorrectAllGames
        let gamerPct = percent(totalCorrect, totalAnswered)
        let gamerColor = colorForPercent(gamerPct)

        let isEmpty = (totalAnswered == 0)

        HeroCard(
            title: "Games",
            subtitle: nil,
            icon: "gamecontroller",
            tint: isEmpty ? .secondary : gamerColor,
            backgroundColor: nil,
            strokeColor: nil // removed colored outline around the Games card
        ) {
            VStack(alignment: .leading, spacing: 12) {
                DisclosureGroup(isExpanded: $gamesExpanded) {
                    // Expanded content with horizontal scroll to prevent overflow on compact widths
                    ScrollView(.horizontal, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 12) {
                            if isEmpty {
                                Text("Play any game to build your Gamer Score.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            } else {
                                // Expanded content: Player Stat Sheet
                                Divider()

                                // Player Stat Sheet with header and aligned columns (center numeric columns)
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Player Stat Sheet")
                                        .font(.subheadline).bold()
                                        .foregroundStyle(.secondary)

                                    // Column metrics
                                    let nameWidth: CGFloat = 140
                                    let colWidth: CGFloat = 72

                                    // Header
                                    HStack(spacing: 10) {
                                        Text("Game")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                            .frame(width: nameWidth, alignment: .leading)
                                        Spacer(minLength: 0)
                                        Text("Played")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                            .frame(width: colWidth, alignment: .center)
                                        Text("Avg")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                            .frame(width: colWidth, alignment: .center)
                                        Text("Streak")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                            .frame(width: colWidth, alignment: .center)
                                    }

                                    // Rows
                                    let stats = allGameStats

                                    // Precompute column values for highlighting
                                    let shares: [Double] = stats.map { s in
                                        totalAnswered > 0 ? (Double(s.answered) / Double(totalAnswered)) * 100.0 : 0
                                    }
                                    let avgs: [Double] = stats.map { s in
                                        s.answered > 0 ? (Double(s.correct) / Double(s.answered)) * 100.0 : 0
                                    }
                                    let streaks: [Int] = stats.map { s in
                                        s.bestStreak ?? 0
                                    }

                                    // Determine unique maxima (no highlight if tie or all zero)
                                    let bestShareIndex = uniqueMaxIndex(shares)
                                    let bestAvgIndex = uniqueMaxIndex(avgs)
                                    let bestStreakIndex = uniqueMaxIndex(streaks)

                                    // Determine unique minima (no highlight if tie)
                                    let worstShareIndex = uniqueMinIndex(shares)
                                    let worstAvgIndex = uniqueMinIndex(avgs)
                                    // For streaks, only consider > 0 values; map zeros to a sentinel so they don’t become the minimum highlight
                                    let streaksForMin: [Int] = streaks.map { $0 == 0 ? Int.max : $0 }
                                    let worstStreakIndex = uniqueMinIndex(streaksForMin)

                                    ForEach(Array(stats.enumerated()), id: \.offset) { pair in
                                        let idx = pair.offset
                                        let s = pair.element
                                        let share = shares[idx]
                                        let avg = avgs[idx]
                                        let best = streaks[idx]

                                        HStack(spacing: 10) {
                                            Text(s.name)
                                                .font(.subheadline.weight(.semibold))
                                                .frame(width: nameWidth, alignment: .leading)

                                            Spacer(minLength: 0)

                                            // Played share column
                                            Text("\(Int(round(share)))%")
                                                .font(.footnote)
                                                .monospacedDigit()
                                                .frame(width: colWidth, alignment: .center)
                                                .foregroundStyle(
                                                    bestShareIndex == idx ? Color.green :
                                                    (worstShareIndex == idx ? Color.red : Color.primary)
                                                )

                                            // Average accuracy column
                                            Text("\(Int(round(avg)))%")
                                                .font(.footnote)
                                                .monospacedDigit()
                                                .frame(width: colWidth, alignment: .center)
                                                .foregroundStyle(
                                                    bestAvgIndex == idx ? Color.green :
                                                    (worstAvgIndex == idx ? Color.red : Color.primary)
                                                )

                                            // Streak column (dash when nil/zero). Avoid red highlight for zero/absent streaks.
                                            Text(s.bestStreak != nil && s.bestStreak! > 0 ? "\(best)" : "—")
                                                .font(.footnote)
                                                .monospacedDigit()
                                                .frame(width: colWidth, alignment: .center)
                                                .foregroundStyle(
                                                    s.bestStreak != nil && s.bestStreak! > 0
                                                    ? (bestStreakIndex == idx ? Color.green :
                                                       (worstStreakIndex == idx ? Color.red : Color.primary))
                                                    : Color.primary
                                                )
                                        }
                                        .foregroundStyle(s.answered == 0 ? .secondary : .primary)
                                        .accessibilityElement(children: .ignore)
                                        .accessibilityLabel(
                                            {
                                                var parts: [String] = [s.name]
                                                parts.append("Share \(Int(round(share))) percent")
                                                parts.append("Average \(Int(round(avg))) percent")
                                                if let bs = s.bestStreak, bs > 0 {
                                                    parts.append("Best streak \(bs)")
                                                }
                                                return parts.joined(separator: ". ") + "."
                                            }()
                                        )
                                    }
                                }
                            }
                        }
                        .padding(.trailing, 4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                } label: {
                    // Collapsed label: Gamer Score row only
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 10) {
                            Text("Gamer Score:")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            if isEmpty {
                                Text("Let’s play!")
                                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("\(Int(round(gamerPct)))%")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundStyle(gamerColor)
                                    .accessibilityHidden(true)
                                    .overlay(
                                        Color.clear
                                            .accessibilityElement(children: .ignore)
                                            .accessibilityLabel("Gamer Score \(Int(round(gamerPct))) percent.")
                                    )
                            }
                        }
                    }
                }
                .animation(.spring(response: 0.25, dampingFraction: 0.9), value: gamesExpanded)
            }
        }
    }

    // MARK: - NEW: Bible Stats Card (collapsible; compact label shows only 3 mini-pills; expanded shows more)

    @StateObject private var bibleVM = HomeBibleStatsViewModel()
    @AppStorage("bibleStatsExpanded") private var bibleStatsExpanded: Bool = false

    @ViewBuilder
    private var bibleStatsCard: some View {
        HeroCard(
            title: "Bible Stats",
            subtitle: "At a glance",
            icon: "chart.bar.fill",
            tint: .teal
        ) {
            DisclosureGroup(isExpanded: $bibleStatsExpanded) {
                // Expanded content: Top Books (Top 3) and Completion (OT/NT graph removed)
                VStack(alignment: .leading, spacing: 12) {
                    // Add a horizontal separator to create space from the mini-pills row above
                    Divider()
                        .padding(.vertical, 4)

                    // Row: Top books (Top 3, ranked list without progress bars)
                    VStack(alignment: .leading, spacing: 8) {
                        // Title only (removed trailing first top book text)
                        Text("Top Books")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        let rows = Array(bibleVM.topBooks.prefix(3))
                        ForEach(Array(rows.enumerated()), id: \.offset) { index, entry in
                            HStack(spacing: 10) {
                                // Rank badge
                                Text("\(index + 1)")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 20, height: 20)
                                    .background(Circle().fill(index == 0 ? Color.teal : (index == 1 ? Color.blue : Color.gray)))
                                    .accessibilityHidden(true)

                                // Book name
                                Text(entry.book)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                // Time
                                Text(BibleStatsStore.shared.format(entry.seconds))
                                    .font(.footnote.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.teal.opacity(0.06))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.teal.opacity(0.12), lineWidth: 1)
                            )
                        }
                    }


                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            } label: {
                // Collapsed/label content: only the three mini-pills
                HStack(spacing: 12) {
                    // Today with delta vs yesterday (new)
                    statMiniPill(title: "Today", value: bibleVM.formatted(bibleVM.todaySeconds), subtitle: bibleVM.todayDeltaOnlyValue, tint: .blue)
                    statMiniPill(title: "This Week", value: bibleVM.formatted(bibleVM.thisWeekSeconds), subtitle: bibleVM.weekDeltaOnlyValue, tint: .green)
                    lastReadMiniPill(title: "Last Read", ref: bibleVM.lastReadBookChapter, relative: bibleVM.lastReadRelativeTime)
                }
            }
            .animation(.spring(response: 0.25, dampingFraction: 0.9), value: bibleStatsExpanded)
            .onAppear {
                bibleVM.refresh()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    bibleVM.refresh()
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            // Navigate to Stats tab (tag 6) when tapping the Bible Stats card
            NotificationCenter.default.post(name: .switchToTab, object: nil, userInfo: ["tab": 6])
        }
    }

    private func statMiniPill(title: String, value: String, subtitle: String? = nil, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption).foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
            // Show subtitle for both Today and This Week when provided
            if let subtitle, !subtitle.isEmpty {
                let prefix = (title == "This Week") ? "vs lst wk: " : (title == "Today" ? "vs yday: " : "")
                if !prefix.isEmpty {
                    Text("\(prefix)\(subtitle)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(tint.opacity(0.25), lineWidth: 1)
        )
    }

    private func lastReadMiniPill(title: String, ref: String, relative: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption).foregroundStyle(.secondary)
            Text(ref)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Text(relative)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.orange.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.orange.opacity(0.25), lineWidth: 1)
        )
    }

    private func otNtMiniBar(ot: Int, nt: Int) -> some View {
        let total = max(1, ot + nt)
        let otFrac = CGFloat(ot) / CGFloat(total)
        let ntFrac = CGFloat(nt) / CGFloat(total)
        return GeometryReader { geo in
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.blue.opacity(0.6))
                    .frame(width: geo.size.width * otFrac)
                Rectangle()
                    .fill(Color.green.opacity(0.6))
                    .frame(width: geo.size.width * ntFrac)
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .frame(height: 10)
    }

    // MARK: - NEW: Streaks Card (now includes Daily Goal progress + expandable calendar)

    // Local UI state for expanding the calendar
    @State private var streaksExpanded: Bool = false
    // Track the month being displayed (start with current month)
    @State private var calendarMonthAnchor: Date = Date()

    // Calendar helpers
    private func startOfMonth(for date: Date) -> Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: date)
        return cal.date(from: comps) ?? date
    }
    private func daysGrid(for month: Date) -> [[Date?]] {
        let cal = Calendar.current
        let start = startOfMonth(for: month)
        guard let range = cal.range(of: .day, in: .month, for: start) else { return [] }
        let firstWeekday = cal.component(.weekday, from: start) // 1=Sunday ... 7=Saturday (default in US)
        let daysCount = range.count

        var grid: [[Date?]] = []
        var row: [Date?] = []

        // Leading blanks
        let leading = (firstWeekday - cal.firstWeekday + 7) % 7
        for _ in 0..<leading { row.append(nil) }

        // Fill days
        for day in 1...daysCount {
            if let d = cal.date(byAdding: .day, value: day - 1, to: start) {
                row.append(d)
                if row.count == 7 {
                    grid.append(row)
                    row = []
                }
            }
        }
        // Trailing blanks
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

    // Extracted small cell view to reduce type-checking depth
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
                    // Ensure both branches are ShapeStyle to satisfy the generic requirement
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

    // Extracted week row to further simplify nested ForEach
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
    private var streaksCard: some View {
        let current = StreakTracker.currentStreak
        let best = StreakTracker.bestStreak
        let last = StreakTracker.lastVisitDate

        // CHANGED: align used seconds with Stats tab via HomeBibleStatsViewModel (session-derived today)
        let usedSecs = max(0, bibleVM.todaySeconds)
        let goalSecs = dailyGoalSeconds
        let progress = min(1.0, Double(usedSecs) / Double(goalSecs))

        HeroCard(
            title: "Daily Bible Streak",
            subtitle: nil,
            icon: "flame.fill",
            tint: current > 0 ? .orange : .secondary
        ) {
            VStack(alignment: .leading, spacing: 10) {
                // Header row: current streak and best
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("\(current)")
                        .font(.system(size: isPad ? 48 : 40, weight: .black, design: .rounded))
                        .foregroundStyle(current > 0 ? .orange : .secondary)
                        .accessibilityLabel("Current streak \(current) days")
                    Text(current == 1 ? "day" : "days")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if best > 0 {
                        HStack(spacing: 6) {
                            Image(systemName: "trophy.fill")
                                .foregroundStyle(.yellow)
                            Text("Best \(best)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Best streak \(best) days")
                    }
                }

                // Last read / encouragement
                if let last {
                    Text("Last read: \(friendlyDate(last))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Start your first day today.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                // Today's progress toward goal
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Today")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        // NEW: Show goal minutes from Settings by the progress bar header
                        Text("Goal: \(goalMinutesString(dailyGoalMinutes_streaks))")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    ProgressView(value: progress)
                        .tint(progress >= 1.0 ? .green : .blue)
                    HStack {
                        if progress >= 1.0 {
                            Label("Great job! You reached your goal today.", systemImage: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                                .font(.footnote.weight(.semibold))
                        } else {
                            Label(remainingFormatted, systemImage: "clock")
                                .foregroundStyle(.secondary)
                                .font(.footnote)
                        }
                        Spacer()
                    }
                }
                .padding(.top, 4)
                
                // Expandable calendar
                DisclosureGroup(isExpanded: $streaksExpanded) {
                    VStack(alignment: .leading, spacing: 8) {
                        calendarMonthView(anchor: calendarMonthAnchor)
                    }
                    .padding(.top, 4)
                } label: {
                    HStack {
                        Text("Calendar")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(calendarMonthAnchor.formatted(.dateTime.month().year()))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .animation(.spring(response: 0.25, dampingFraction: 0.9), value: streaksExpanded)
            }
        }
        .accessibilityElement(children: .contain)
        .onAppear {
            // Ensure we’re reading current values (ContentView updates counters)
            _ = dailyUsageTodayKey // touch to avoid warnings; values are @AppStorage-backed
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // Refresh reads of @AppStorage-backed usage values on return to Home
                _ = dailyUsageTodayKey
            }
        }
    }

    @ViewBuilder
    private func calendarMonthView(anchor: Date) -> some View {
        let cal = Calendar.current
        let grid = daysGrid(for: anchor)
        let weekdays = cal.shortWeekdaySymbols // localized e.g., ["Sun","Mon",...]

        VStack(alignment: .leading, spacing: 8) {
            // Month header with prev/next
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

            // Weekday header
            HStack {
                ForEach(weekdays, id: \.self) { w in
                    Text(w.uppercased())
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Weeks grid (extracted WeekRow to lower complexity)
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

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                titleCard

                // Render reorderable/hideable cards based on saved layout
                ForEach(layoutOrder, id: \.self) { card in
                    if !hiddenSet.contains(card) {
                        switch card {
                        case .verseOfDay:
                            verseOfDayCard
                        case .dailyFocus:
                            dailyFocusCard
                        case .timer:
                            timerCard
                        case .resumeReading:
                            resumeCard
                        case .games:
                            gamesCard
                        case .streaks:
                            streaksCard
                        case .bibleStats:
                            bibleStatsCard
                        }
                    }
                }
            }
            // Adjusted: give iPhone horizontal padding too so cards don’t touch edges
            .padding(.horizontal, isPad ? 24 : 16)
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
            dbgSnapshot("onAppear after hydration")

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
        }
        // Update when AppStorage strings change (e.g., after Settings saves or user toggles)
        .onChange(of: homeCardOrderRaw) { _, _ in decodeHomeLayout() }
        .onChange(of: homeCardHiddenRaw) { _, _ in decodeHomeLayout() }
        // Also observe explicit notification sent by Settings (extra safety)
        .onReceive(NotificationCenter.default.publisher(for: .init("homeLayoutChanged"))) { _ in
            decodeHomeLayout()
        }
        .onChange(of: progressList) { _, _ in
            // SwiftData/CloudKit changes will flow here; mirror to widget
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
        // Reset Games card state whenever leaving Home
        .onDisappear {
            gamesExpanded = false
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
                print("[TimerDBG] ticker subscribed (isTimerRunning=\(isTimerRunning), stopwatchRunning=\(stopwatchRunning))")
            }
        } else {
            tickerCancellable?.cancel()
            tickerCancellable = nil
            print("[TimerDBG] ticker cancelled")
        }
    }

    // Suppression windows to prevent immediate Live Activity/timer recompute churn after +1/+5/+10
    @State private var suppressTimerActivityUpdatesUntil: Date = .distantPast
    @State private var suppressTimerRecomputeUntil: Date = .distantPast

    // One-shot token for pending actions so stale actions are ignored
    @AppStorage("prayerTimerLastActionToken") private var lastActionToken: String = ""

    private func tick() {
        dbgSnapshot("tick start")
        if handlePrayerTimerPendingAction() {
            print("[TimerDBG] tick consumed pending action")
            return
        }
        handleStopwatchPendingAction()

        if isEditingFocus { return }

        if isTimerRunning && !isPaused && storedEndDate > 0 {
            if Date() < suppressTimerRecomputeUntil {
                // During suppression window, don't trust storedEndDate; decrement locally
                let before = remainingSeconds
                let after = max(0, remainingSeconds - 1)
                if before != after {
                    dbgWrite("remainingSeconds", old: before, new: after, note: "tick local decrement (suppressed recompute)")
                }
                remainingSeconds = after
            } else {
                let before = remainingSeconds
                let remaining = Int(max(0, storedEndDate - Date().timeIntervalSince1970))
                if remainingSeconds != remaining {
                    dbgWrite("remainingSeconds", old: before, new: remaining, note: "tick recompute (storedEndDate=\(storedEndDate), now=\(Date().timeIntervalSince1970))")
                }
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

        timeMarker = (timeMarker + 1) % 60
    }

    private func startTimer(minutes: Int) {
        Task { await requestNotificationsIfNeeded() }
        if isHealthKitAvailable && !healthKitPrompted {
            Task { await requestHealthKitIfNeeded() }
        }

        let secs = max(1, minutes) * 60
        let oldRemaining = remainingSeconds
        remainingSeconds = secs
        dbgWrite("remainingSeconds", old: oldRemaining, new: secs, note: "startTimer set initial remaining")

        let oldTotal = storedTotalSeconds
        storedTotalSeconds = secs
        dbgWrite("storedTotalSeconds", old: oldTotal, new: secs, note: "startTimer set total")

        let start = Date()
        let end = start.addingTimeInterval(TimeInterval(secs))
        isPaused = false
        isTimerRunning = true

        let oldRunning = storedRunning
        storedRunning = true
        dbgWrite("storedRunning", old: oldRunning, new: true, note: "startTimer")

        let oldPaused = storedPaused
        storedPaused = false
        dbgWrite("storedPaused", old: oldPaused, new: false, note: "startTimer")

        let oldStart = storedStartDate
        storedStartDate = start.timeIntervalSince1970
        dbgWrite("storedStartDate", old: oldStart, new: storedStartDate, note: "startTimer")

        let oldEnd = storedEndDate
        storedEndDate = end.timeIntervalSince1970
        dbgWrite("storedEndDate", old: oldEnd, new: storedEndDate, note: "startTimer set end")

        let oldPausedRemain = storedRemainingWhenPaused
        storedRemainingWhenPaused = 0
        dbgWrite("storedRemainingWhenPaused", old: oldPausedRemain, new: 0, note: "startTimer reset")

        print("[TimerDBG] startTimer minutes=\(minutes) -> remaining=\(remainingSeconds), storedEndDate=\(storedEndDate) (start=\(storedStartDate))")

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
        let oldPaused = isPaused
        isPaused.toggle()
        dbgWrite("isPaused", old: oldPaused, new: isPaused, note: "togglePause local")

        let oldStoredPaused = storedPaused
        storedPaused = isPaused
        dbgWrite("storedPaused", old: oldStoredPaused, new: storedPaused, note: "togglePause mirror")

        if isPaused {
            let now = Date().timeIntervalSince1970
            let newRemain = Int(max(0, storedEndDate - now))
            let oldRemaining = remainingSeconds
            remainingSeconds = newRemain
            dbgWrite("remainingSeconds", old: oldRemaining, new: newRemain, note: "togglePause -> PAUSED recompute")

            let oldPausedRemain = storedRemainingWhenPaused
            storedRemainingWhenPaused = newRemain
            dbgWrite("storedRemainingWhenPaused", old: oldPausedRemain, new: newRemain, note: "togglePause -> PAUSED")

            print("[TimerDBG] togglePause -> PAUSED remaining=\(remainingSeconds) storedRemainingWhenPaused=\(storedRemainingWhenPaused) storedEndDate=\(storedEndDate)")
            cancelNotification()
        } else {
            let newEnd = Date().addingTimeInterval(TimeInterval(remainingSeconds))
            let oldEnd = storedEndDate
            storedEndDate = newEnd.timeIntervalSince1970
            dbgWrite("storedEndDate", old: oldEnd, new: storedEndDate, note: "togglePause -> RESUMED set new end")

            let oldPausedRemain = storedRemainingWhenPaused
            storedRemainingWhenPaused = 0
            dbgWrite("storedRemainingWhenPaused", old: oldPausedRemain, new: 0, note: "togglePause -> RESUMED clear")

            print("[TimerDBG] togglePause -> RESUMED remaining=\(remainingSeconds) new storedEndDate=\(storedEndDate)")
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
            let before = remainingSeconds
            let newRem = remainingSeconds + delta
            dbgWrite("remainingSeconds", old: before, new: newRem, note: "+1 while PAUSED")
            remainingSeconds = newRem

            let oldPausedRemain = storedRemainingWhenPaused
            let newPausedRemain = storedRemainingWhenPaused + delta
            dbgWrite("storedRemainingWhenPaused", old: oldPausedRemain, new: newPausedRemain, note: "+1 while PAUSED")
            storedRemainingWhenPaused = newPausedRemain

            let oldTotal = storedTotalSeconds
            let newTotal = storedTotalSeconds + delta
            dbgWrite("storedTotalSeconds", old: oldTotal, new: newTotal, note: "+1 while PAUSED")
            storedTotalSeconds = newTotal

            print("[TimerDBG] +1 while PAUSED \(before) -> \(remainingSeconds) storedRemainingWhenPaused=\(storedRemainingWhenPaused) total=\(storedTotalSeconds)")
            PrayerTimerActivityController.shared.update(
                remainingSeconds: remainingSeconds,
                totalSeconds: storedTotalSeconds,
                isPaused: isPaused
            )
        } else {
            let oldEnd = storedEndDate
            storedEndDate += TimeInterval(delta)
            dbgWrite("storedEndDate", old: oldEnd, new: storedEndDate, note: "+1 while RUNNING shift end")

            let oldTotal = storedTotalSeconds
            storedTotalSeconds += delta
            dbgWrite("storedTotalSeconds", old: oldTotal, new: storedTotalSeconds, note: "+1 while RUNNING increase total")

            let newRemaining = Int(max(0, storedEndDate - Date().timeIntervalSince1970))
            let before = remainingSeconds
            remainingSeconds = newRemaining
            dbgWrite("remainingSeconds", old: before, new: newRemaining, note: "+1 while RUNNING recompute from end")

            print("[TimerDBG] +1 while RUNNING remaining \(before) -> \(remainingSeconds) new storedEndDate=\(storedEndDate) now=\(Date().timeIntervalSince1970)")
            scheduleNotification(at: Date(timeIntervalSince1970: storedEndDate))
            PrayerTimerActivityController.shared.update(
                remainingSeconds: remainingSeconds,
                totalSeconds: storedTotalSeconds,
                isPaused: isPaused
            )
        }
        suppressTimerActivityUpdatesUntil = Date().addingTimeInterval(0.75)
        suppressTimerRecomputeUntil = Date().addingTimeInterval(0.75)

        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.impactOccurred()
    }

    private func addFiveMinutes() {
        guard isTimerRunning else { return }
        let delta: Int = 300
        if isPaused {
            let before = remainingSeconds
            let newRem = remainingSeconds + delta
            dbgWrite("remainingSeconds", old: before, new: newRem, note: "+5 while PAUSED")
            remainingSeconds = newRem

            let oldPausedRemain = storedRemainingWhenPaused
            let newPausedRemain = storedRemainingWhenPaused + delta
            dbgWrite("storedRemainingWhenPaused", old: oldPausedRemain, new: newPausedRemain, note: "+5 while PAUSED")
            storedRemainingWhenPaused = newPausedRemain

            let oldTotal = storedTotalSeconds
            let newTotal = storedTotalSeconds + delta
            dbgWrite("storedTotalSeconds", old: oldTotal, new: newTotal, note: "+5 while PAUSED")
            storedTotalSeconds = newTotal

            print("[TimerDBG] +5 while PAUSED \(before) -> \(remainingSeconds) storedRemainingWhenPaused=\(storedRemainingWhenPaused) total=\(storedTotalSeconds)")
            PrayerTimerActivityController.shared.update(
                remainingSeconds: remainingSeconds,
                totalSeconds: storedTotalSeconds,
                isPaused: isPaused
            )
        } else {
            let oldEnd = storedEndDate
            storedEndDate += TimeInterval(delta)
            dbgWrite("storedEndDate", old: oldEnd, new: storedEndDate, note: "+5 while RUNNING shift end")

            let oldTotal = storedTotalSeconds
            storedTotalSeconds += delta
            dbgWrite("storedTotalSeconds", old: oldTotal, new: storedTotalSeconds, note: "+5 while RUNNING increase total")

            let newRemaining = Int(max(0, storedEndDate - Date().timeIntervalSince1970))
            let before = remainingSeconds
            remainingSeconds = newRemaining
            dbgWrite("remainingSeconds", old: before, new: newRemaining, note: "+5 while RUNNING recompute from end")

            print("[TimerDBG] +5 while RUNNING remaining \(before) -> \(remainingSeconds) new storedEndDate=\(storedEndDate) now=\(Date().timeIntervalSince1970)")
            scheduleNotification(at: Date(timeIntervalSince1970: storedEndDate))
            PrayerTimerActivityController.shared.update(
                remainingSeconds: remainingSeconds,
                totalSeconds: storedTotalSeconds,
                isPaused: isPaused
            )
        }
        suppressTimerActivityUpdatesUntil = Date().addingTimeInterval(0.75)
        suppressTimerRecomputeUntil = Date().addingTimeInterval(0.75)

        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.impactOccurred()
    }

    private func addTenMinutes() {
        guard isTimerRunning else { return }
        let delta: Int = 600
        if isPaused {
            let before = remainingSeconds
            let newRem = remainingSeconds + delta
            dbgWrite("remainingSeconds", old: before, new: newRem, note: "+10 while PAUSED")
            remainingSeconds = newRem

            let oldPausedRemain = storedRemainingWhenPaused
            let newPausedRemain = storedRemainingWhenPaused + delta
            dbgWrite("storedRemainingWhenPaused", old: oldPausedRemain, new: newPausedRemain, note: "+10 while PAUSED")
            storedRemainingWhenPaused = newPausedRemain

            let oldTotal = storedTotalSeconds
            let newTotal = storedTotalSeconds + delta
            dbgWrite("storedTotalSeconds", old: oldTotal, new: newTotal, note: "+10 while PAUSED")
            storedTotalSeconds = newTotal

            print("[TimerDBG] +10 while PAUSED \(before) -> \(remainingSeconds) storedRemainingWhenPaused=\(storedRemainingWhenPaused) total=\(storedTotalSeconds)")
            PrayerTimerActivityController.shared.update(
                remainingSeconds: remainingSeconds,
                totalSeconds: storedTotalSeconds,
                isPaused: isPaused
            )
        } else {
            let oldEnd = storedEndDate
            storedEndDate += TimeInterval(delta)
            dbgWrite("storedEndDate", old: oldEnd, new: storedEndDate, note: "+10 while RUNNING shift end")

            let oldTotal = storedTotalSeconds
            storedTotalSeconds += delta
            dbgWrite("storedTotalSeconds", old: oldTotal, new: storedTotalSeconds, note: "+10 while RUNNING increase total")

            let newRemaining = Int(max(0, storedEndDate - Date().timeIntervalSince1970))
            let before = remainingSeconds
            remainingSeconds = newRemaining
            dbgWrite("remainingSeconds", old: before, new: newRemaining, note: "+10 while RUNNING recompute from end")

            print("[TimerDBG] +10 while RUNNING remaining \(before) -> \(remainingSeconds) new storedEndDate=\(storedEndDate) now=\(Date().timeIntervalSince1970)")
            scheduleNotification(at: Date(timeIntervalSince1970: storedEndDate))
            PrayerTimerActivityController.shared.update(
                remainingSeconds: remainingSeconds,
                totalSeconds: storedTotalSeconds,
                isPaused: isPaused
            )
        }
        suppressTimerActivityUpdatesUntil = Date().addingTimeInterval(0.75)
        suppressTimerRecomputeUntil = Date().addingTimeInterval(0.75)
        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.impactOccurred()
    }

    private func resetTimerState() {
        let oldRunning = storedRunning
        storedRunning = false
        dbgWrite("storedRunning", old: oldRunning, new: false, note: "resetTimerState")

        let oldPaused = storedPaused
        storedPaused = false
        dbgWrite("storedPaused", old: oldPaused, new: false, note: "resetTimerState")

        let oldEnd = storedEndDate
        storedEndDate = 0
        dbgWrite("storedEndDate", old: oldEnd, new: 0, note: "resetTimerState")

        let oldPausedRemain = storedRemainingWhenPaused
        storedRemainingWhenPaused = 0
        dbgWrite("storedRemainingWhenPaused", old: oldPausedRemain, new: 0, note: "resetTimerState")

        let oldTotal = storedTotalSeconds
        storedTotalSeconds = 0
        dbgWrite("storedTotalSeconds", old: oldTotal, new: 0, note: "resetTimerState")

        let oldStart = storedStartDate
        storedStartDate = 0
        dbgWrite("storedStartDate", old: oldStart, new: 0, note: "resetTimerState")

        let oldLocalRunning = isTimerRunning
        isTimerRunning = false
        dbgWrite("isTimerRunning", old: oldLocalRunning, new: false, note: "resetTimerState")

        let oldLocalPaused = isPaused
        isPaused = false
        dbgWrite("isPaused", old: oldLocalPaused, new: false, note: "resetTimerState")

        let oldRemaining = remainingSeconds
        remainingSeconds = 0
        dbgWrite("remainingSeconds", old: oldRemaining, new: 0, note: "resetTimerState")

        print("[TimerDBG] resetTimerState")
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
        print("[TimerDBG] scheduleNotification at \(date) (in \(date.timeIntervalSinceNow)s)")
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
        print("[TimerDBG] cancelNotification")
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
        print("[TimerDBG] handleTimerFinished")
    }

    private func startFinishAlerts() {
        stopFinishAlerts()
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
            print("[TimerDBG] handlePrayerTimerPendingAction ignored stale action token=\(token)")
            return false
        }

        // Consume keys up-front
        shared.removeObject(forKey: "prayerTimerPendingAction")
        shared.removeObject(forKey: "prayerTimerActionToken")
        print("[TimerDBG] handlePrayerTimerPendingAction action=\(action) token=\(token)")

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
        dbgSnapshot("after handlePrayerTimerPendingAction")
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

// Generic HeroCard with a trailing accessory closure (no AnyView)
private struct HeroCard<Content: View, TrailingAccessory: View, TitleAccessory: View>: View {
    let title: String
    let subtitle: String?
    let icon: String?
    let tint: Color
    let backgroundColor: Color?
    let strokeColor: Color?
    let trailingAccessory: (() -> TrailingAccessory)?
    let titleAccessory: (() -> TitleAccessory)?
    let titleFont: Font
    let titleFontWeight: Font.Weight
    let centerHeader: Bool
    @ViewBuilder var content: Content

    @Environment(\.colorScheme) private var colorScheme

    init(
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        tint: Color = .accentColor,
        backgroundColor: Color? = nil,
        strokeColor: Color? = nil,
        titleFont: Font = .headline,
        titleFontWeight: Font.Weight = .bold,
        centerHeader: Bool = false,
        @ViewBuilder content: () -> Content
    ) where TrailingAccessory == EmptyView, TitleAccessory == EmptyView {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.tint = tint
        self.backgroundColor = backgroundColor
        self.strokeColor = strokeColor
        self.trailingAccessory = nil
        self.titleAccessory = nil
        self.titleFont = titleFont
        self.titleFontWeight = titleFontWeight
        self.centerHeader = centerHeader
        self.content = content()
    }

    init(
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        tint: Color = .accentColor,
        backgroundColor: Color? = nil,
        strokeColor: Color? = nil,
        trailingAccessory: @escaping () -> TrailingAccessory,
        titleFont: Font = .headline,
        titleFontWeight: Font.Weight = .bold,
        centerHeader: Bool = false,
        @ViewBuilder content: () -> Content
    ) where TitleAccessory == EmptyView {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.tint = tint
        self.backgroundColor = backgroundColor
        self.strokeColor = strokeColor
        self.trailingAccessory = trailingAccessory
        self.titleAccessory = nil
        self.titleFont = titleFont
        self.titleFontWeight = titleFontWeight
        self.centerHeader = centerHeader
        self.content = content()
    }

    init(
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        tint: Color = .accentColor,
        backgroundColor: Color? = nil,
        strokeColor: Color? = nil,
        titleFont: Font = .headline,
        titleFontWeight: Font.Weight = .bold,
        centerHeader: Bool = false,
        titleAccessory: @escaping () -> TitleAccessory,
        @ViewBuilder content: () -> Content
    ) where TrailingAccessory == EmptyView {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.tint = tint
        self.backgroundColor = backgroundColor
        self.strokeColor = strokeColor
        self.trailingAccessory = nil
        self.titleAccessory = titleAccessory
        self.titleFont = titleFont
        self.titleFontWeight = titleFontWeight
        self.centerHeader = centerHeader
        self.content = content()
    }

    init(
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        tint: Color = .accentColor,
        backgroundColor: Color? = nil,
        strokeColor: Color? = nil,
        trailingAccessory: @escaping () -> TrailingAccessory,
        titleFont: Font = .headline,
        titleFontWeight: Font.Weight = .bold,
        centerHeader: Bool = false,
        titleAccessory: @escaping () -> TitleAccessory,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.tint = tint
        self.backgroundColor = backgroundColor
        self.strokeColor = strokeColor
        self.trailingAccessory = trailingAccessory
        self.titleAccessory = titleAccessory
        self.titleFont = titleFont
        self.titleFontWeight = titleFontWeight
        self.centerHeader = centerHeader
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !(title.isEmpty && subtitle == nil && icon == nil) {
                if centerHeader {
                    VStack(alignment: .center, spacing: 6) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            if let icon {
                                Image(systemName: icon)
                                    .foregroundStyle(tint)
                                    .font(titleFont)
                            }
                            // Title + optional accessory (e.g., flame)
                            HStack(spacing: 6) {
                                Text(title)
                                    .font(titleFont)
                                    .fontWeight(titleFontWeight)
                                    .multilineTextAlignment(.center)
                                if let titleAccessory {
                                    titleAccessory()
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)

                        if let subtitle {
                            Text(subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    HStack(alignment: .center, spacing: 10) {
                        if let icon {
                            Image(systemName: icon)
                                .foregroundStyle(tint)
                                .font(titleFont)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title)
                                .font(titleFont)
                                .fontWeight(titleFontWeight)
                            if let subtitle {
                                Text(subtitle)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if let trailingAccessory {
                            trailingAccessory()
                        }
                    }
                }
            }
            content
        }
        .padding(16)
        .background(
            Group {
                if let backgroundColor {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(backgroundColor)
                } else {
                    if colorScheme == .dark {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    } else {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color(.secondarySystemBackground), Color(.systemBackground)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
            }
        )
        .overlay(
            Group {
                if let strokeColor {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(strokeColor, lineWidth: 1)
                } else {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder((colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.06)), lineWidth: 1)
                }
            }
        )
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
    }
}

private struct HomeVerseRef {
    let bookName: String
    let chapterNumber: Int
    let verseNumber: Int
    let verseText: String
}

private struct PrayerStudyTimerSetupView: View {
    @Environment(\.dismiss) private var dismiss
    let onStart: (Int) -> Void

    @State private var selectedMinutes: Int = 15

    var body: some View {
        VStack(alignment: .center, spacing: 20) {
            Text("Prayer/Study Timer")
                .font(.title2)
                .bold()

            VStack(spacing: 16) {
                Text("Duration")
                    .font(.headline)

                Picker("Minutes", selection: $selectedMinutes) {
                    ForEach(1...120, id: \.self) { m in
                        Text("\(m) minute\(m == 1 ? "" : "s")").tag(m)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 160)

                Text("Selected: \(selectedMinutes) minute\(selectedMinutes == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button {
                onStart(selectedMinutes)
                dismiss()
            } label: {
                HStack {
                    Spacer()
                    Text("Start Timer")
                        .font(.headline)
                        .bold()
                    Spacer()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
        }
        .padding()
    }
}

// Debounced widget reloader to minimize reloadAllTimelines churn
private final class DebouncedWidgetReloader {
    static let shared = DebouncedWidgetReloader()
    private init() {}

    private var workItem: DispatchWorkItem?
    private let queue = DispatchQueue(label: "DebouncedWidgetReloader")
    private var pendingKinds = Set<String>()
    private let lock = NSLock()

    func reloadAll() {
        schedule {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    func reload(kind: String) {
        lock.lock()
        pendingKinds.insert(kind)
        lock.unlock()
        schedule { [weak self] in
            guard let self else { return }
            self.lock.lock()
            let kinds = Array(self.pendingKinds)
            self.pendingKinds.removeAll()
            self.lock.unlock()
            if kinds.isEmpty {
                WidgetCenter.shared.reloadAllTimelines()
            } else {
                kinds.forEach { WidgetCenter.shared.reloadTimelines(ofKind: $0) }
            }
        }
    }

    private func schedule(_ action: @escaping () -> Void) {
        workItem?.cancel()
        let item = DispatchWorkItem { action() }
        workItem = item
        queue.asyncAfter(deadline: .now() + 0.6, execute: item)
    }
}

