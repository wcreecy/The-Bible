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

    // Progress-fill text used in the title card subtitle
    private struct ProgressFillText: View {
        let text: String
        let font: Font
        let progress: Double // 0...1
        // Gradient from blue (cold) to red (hot)
        private var gradient: LinearGradient {
            LinearGradient(colors: [.blue, .red], startPoint: .leading, endPoint: .trailing)
        }

        var body: some View {
            ZStack(alignment: .leading) {
                Text(text)
                    .font(font)
                    .foregroundStyle(.secondary)
                // Overlay the same text, but clipped horizontally by progress, filled with gradient
                Text(text)
                    .font(font)
                    .foregroundStyle(gradient)
                    .mask(
                        GeometryReader { geo in
                            let width = max(0, min(1, progress)) * geo.size.width
                            Rectangle()
                                .frame(width: width, height: geo.size.height)
                                .alignmentGuide(.leading) { d in d[.leading] }
                        }
                    )
            }
            .accessibilityLabel(text)
        }
    }

    @ViewBuilder
    private var titleCard: some View {
        // Determine iPad-specific sizing
        let isPad = self.isPad
        let buttonScale: CGFloat = isPad ? 1.25 : 1.0
        let titleFont: Font = isPad ? .system(.largeTitle, design: .default) : .largeTitle
        let titleWeight: Font.Weight = .black
        let _: Font = isPad ? .title3.weight(.semibold) : .subheadline.weight(.semibold)

        // Compute today's daily goal progress for the subtitle fill
        let goalSeconds = max(1, dailyGoalMinutes) * 60
        // CHANGED: Use sessions-based local-day total to align with Streaks card
        let todayReadingSeconds = BibleStatsStore.shared.todayTotalSeconds()
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
            centerHeader: true // Center on iPhone and iPad
        ) {
            VStack(spacing: isPad ? 16 : 8) {
                // Subtitle that fills with a blue->red gradient as progress increases
                ProgressFillText(
                    text: "What does God have for YOU today?",
                    font: isPad ? .title3.weight(.semibold) : .subheadline.weight(.semibold),
                    progress: progress
                )
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
        // UPDATED: align with StreakTracker (BibleStatsStore daily totals) to avoid mismatch.
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

    // MARK: - NEW: Games Card (Home) using centralized GameStats

    // Local token to re-render on external sync merges
    @State private var gameStatsVersion: Int = 0

    private func colorForPercent(_ pct: Double) -> Color {
        if pct < 60 { return .red }
        else if pct < 75 { return .orange }
        else if pct < 90 { return .purple }
        else { return .green }
    }

    @ViewBuilder
    private var gamesCard: some View {
        // Pull a fresh snapshot; reading version in the view ties it to state updates
        let _ = gameStatsVersion
        let snap = GameStats.shared.snapshot()
        let gamerPct = snap.percentage
        let gamerColor = colorForPercent(gamerPct)
        let isEmpty = (snap.totalAnswered == 0)

        HeroCard(
            title: "Games",
            subtitle: nil,
            icon: "gamecontroller",
            tint: isEmpty ? .secondary : gamerColor,
            backgroundColor: nil,
            strokeColor: nil
        ) {
            VStack(alignment: .leading, spacing: 12) {
                // Compact header: Gamer Score
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

                // Navigation buttons
                HStack(spacing: 10) {
                    Button {
                        NotificationCenter.default.post(name: .switchToTab, object: nil, userInfo: ["tab": 3])
                    } label: {
                        Label("Games", systemImage: "gamecontroller")
                    }
                    .buttonStyle(ModernPillButtonStyle(tint: .blue))

                    Button {
                        NotificationCenter.default.post(name: .switchToTab, object: nil, userInfo: ["tab": 6])
                    } label: {
                        Label("Stats", systemImage: "chart.bar")
                    }
                    .buttonStyle(ModernPillButtonStyle(tint: .teal))
                }
                .padding(.top, 2)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            // Light press anywhere on the card navigates to Games tab
            NotificationCenter.default.post(name: .switchToTab, object: nil, userInfo: ["tab": 3])
        }
        .onReceive(NotificationCenter.default.publisher(for: .gameStatsExternallyUpdated)) { _ in
            // bump local version to trigger recompute/redraw
            gameStatsVersion &+= 1
        }
    }

    // MARK: - NEW: Bible Stats Card (collapsed only; summary mini-pills)

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
            // Collapsed/label content only: show summary mini-pills in a horizontal scroller
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Today with delta vs yesterday
                    statMiniPill(title: "Today", value: bibleVM.formatted(bibleVM.todaySeconds), subtitle: bibleVM.todayDeltaOnlyValue, tint: .blue)
                    // This Week with delta vs last week
                    statMiniPill(title: "This Week", value: bibleVM.formatted(bibleVM.thisWeekSeconds), subtitle: bibleVM.weekDeltaOnlyValue, tint: .green)
                    // New: This Month (sessions-only via BibleStatsStore) with delta vs last month
                    let monthSeconds = BibleStatsStore.shared.totalForMonth(containing: Date())
                    let lastMonthDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
                    let lastMonthSeconds = BibleStatsStore.shared.totalForMonth(containing: lastMonthDate)
                    let monthDeltaOnlyValue: String = {
                        let delta = monthSeconds - lastMonthSeconds
                        if delta == 0 { return "—" }
                        let sign = delta > 0 ? "+" : "−"
                        return "\(sign)\(bibleVM.formatted(abs(delta)))"
                    }()
                    statMiniPill(title: "This Month", value: bibleVM.formatted(monthSeconds), subtitle: monthDeltaOnlyValue, tint: .mint)
                    // New: All-time (sessions-only within retention)
                    statMiniPill(title: "All-time", value: bibleVM.formatted(bibleVM.totalSeconds), subtitle: nil, tint: .purple)
                    // Last Read
                    lastReadMiniPill(title: "Last Read", ref: bibleVM.lastReadBookChapter, relative: bibleVM.lastReadRelativeTime)
                }
                .padding(.vertical, 2)
            }
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
                let prefix = (title == "This Week") ? "vs lst wk: " : (title == "Today" ? "vs yday: " : (title == "This Month" ? "vs lst mo: " : ""))
                if !prefix.isEmpty {
                    Text("\(prefix)\(subtitle)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12) // was 10; slightly taller to allow 2 lines comfortably
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
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Text(relative)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12) // was 10; slightly taller to allow 2 lines comfortably
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

    @ViewBuilder
    private var streaksCard: some View {
        let current = StreakTracker.currentStreak
        let best = StreakTracker.bestStreak
        let last = StreakTracker.lastVisitDate

        // UPDATED: Use authoritative sessions-based "today" total
        let goalSecs = dailyGoalSeconds
        let todayTotal = BibleStatsStore.shared.todayTotalSeconds()
        let progress = min(1.0, Double(todayTotal) / Double(goalSecs))
        let goalMet = BibleStatsStore.shared.isDailyGoalMet(goalSeconds: goalSecs)

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
                        .tint(goalMet ? .green : .blue)
                    HStack {
                        if goalMet {
                            Label("Great job! You reached your goal today.", systemImage: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                                .font(.footnote.weight(.semibold))
                        } else {
                            let remaining = max(0, goalSecs - todayTotal)
                            let m = remaining / 60
                            let s = remaining % 60
                            Label("\(m)m \(s)s left", systemImage: "clock")
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
        // Keep the card live when Bible reading stats change (cross-device, sessions, etc.)
        .onReceive(NotificationCenter.default.publisher(for: .bibleStatsExternallyUpdated)) { _ in
            // No-op body; state derives from BibleStatsStore on render.
            // Trigger a redraw by touching a benign @State if needed in future.
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

            // Weeks grid (uses extracted WeekRow)
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

    // Helper to render a card by ID (avoids duplicating the switch)
    @ViewBuilder
    private func card(for id: HomeCardID) -> some View {
        switch id {
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

    var body: some View {
        // Build the list of visible cards in the saved order
        let activeCards: [HomeCardID] = layoutOrder.filter { !hiddenSet.contains($0) }

        ScrollView {
            if isPad {
                // iPad: Title card full width, then two independent vertical columns for consistent spacing
                // Split the cards into two columns (even/odd index keeps overall order visually top-to-bottom)
                let leftCards = activeCards.enumerated().compactMap { $0.offset % 2 == 0 ? $0.element : nil }
                let rightCards = activeCards.enumerated().compactMap { $0.offset % 2 == 1 ? $0.element : nil }

                VStack(spacing: 16) {
                    titleCard

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
                // iPhone: original single-column stack
                VStack(spacing: 16) {
                    titleCard

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
            gameStatsVersion = GameStats.shared.snapshot().totalAnswered // seed read; any value ok
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
        // Keep Home view live with Bible stats changes too
        .onReceive(NotificationCenter.default.publisher(for: .bibleStatsExternallyUpdated)) { _ in
            // bibleVM already refreshes on appear/active; nothing else required for computed streak card.
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
        // Reset expanded states whenever leaving Home
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

private struct HomeVerseRef {
    let bookName: String
    let chapterNumber: Int
    let verseNumber: Int
    let verseText: String
}
