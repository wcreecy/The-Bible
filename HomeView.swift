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

struct HomeView: View {
    private enum PrayerMode: String { case timer, stopwatch, focus }

    @Query private var progressList: [ReadingProgress]
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

    // On-demand ticker: only active during timer/stopwatch sessions
    @State private var tickerCancellable: AnyCancellable?
    @State private var showFinishedAlert: Bool = false
    @State private var finishHapticTimer: Timer? = nil

    @Environment(\.modelContext) private var modelContext
    @Query private var favorites: [Favorite]
    @EnvironmentObject private var coordinator: NavigationCoordinator
    @State private var verseOfDay: HomeVerseRef? = nil

    // For lazy resume card resolution
    @State private var resumeBook: Book? = nil

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

    // Bible store for async/on-demand loading (now lazy)
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
            let start = Date(timeIntervalSince1970: mindfulStartDate)
            let end = Date()
            if end > start {
                HealthKitManager.shared.saveMindfulSession(start: start, end: end, completion: nil)
            }
            mindfulStartDate = 0
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
        guard let t1 = dateForToday(hour: votdRefresh1Hour, minute: votdRefresh1Minute, from: now),
              let t2 = dateForToday(hour: votdRefresh2Hour, minute: votdRefresh2Minute, from: now) else {
            return now
        }
        if now < t1 { return t1 }
        if now < t2 { return t2 }
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
            Task { await loadRandomVerse() }
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
            Text("Focus").tag(PrayerMode.focus)
        }
        .pickerStyle(.segmented)
        .controlSize(.small)
        .disabled(disabled)
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

    private func mirrorLastReadToAppGroup() async {
        guard let shared = sharedDefaults else { return }
        guard let p = progress else { return }
        // Load only the needed book lazily
        if let book = await BibleStore.shared.book(named: p.bookName),
           let chapter = book.chapters.first(where: { $0.number == p.chapterNumber }),
           let verse = chapter.verses.first(where: { $0.number == p.verseNumber }) {
            shared.set(p.bookName, forKey: "lastReadBook")
            shared.set(p.chapterNumber, forKey: "lastReadChapter")
            shared.set(p.verseNumber, forKey: "lastReadVerse")
            shared.set(verse.text, forKey: "lastReadText")
            shared.set(Date().timeIntervalSince1970, forKey: "lastReadUpdatedAt")
            // Reload only the Last Read widget, debounced
            DebouncedWidgetReloader.shared.reload(kind: "LastReadWidget")
        }
    }

    private func handleOpenPendingVerse() async {
        guard let shared = sharedDefaults else { return }
        guard let book = shared.string(forKey: "pendingOpenBook"),
              let chapter = shared.value(forKey: "pendingOpenChapter") as? Int,
              let verse = shared.value(forKey: "pendingOpenVerse") as? Int else { return }
        shared.removeObject(forKey: "pendingOpenBook")
        shared.removeObject(forKey: "pendingOpenChapter")
        shared.removeObject(forKey: "pendingOpenVerse")

        guard let b = await BibleStore.shared.book(named: book),
              let c = b.chapters.first(where: { $0.number == chapter }) else { return }
        coordinator.push(.reader(book: b, chapter: c, startVerse: verse))
    }

    // MARK: - Split cards to reduce type-checking complexity
    @ViewBuilder
    private var titleCard: some View {
        HeroCard(title: "Word of God", subtitle: "Welcome back", icon: "book.fill", tint: .blue, titleFont: Font.largeTitle, titleFontWeight: Font.Weight.black) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "person.wave.2.fill")
                    .foregroundStyle(.blue)
                Text("What is God saying to you today?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: 700)
        .padding(.horizontal, 16)
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
                        Button(action: { Task { await loadRandomVerse() } }) {
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
                        Text("Verse will refresh automatically at your selected times.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
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
                guard let v = verseOfDay else { return }
                Task {
                    if let b = await BibleStore.shared.book(named: v.bookName),
                       let c = b.chapters.first(where: { $0.number == v.chapterNumber }) {
                        coordinator.push(.reader(book: b, chapter: c, startVerse: v.verseNumber))
                    }
                }
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
        .padding(.horizontal, 16)
        .frame(height: isPad ? iPadCardHeight : nil)
    }

    @ViewBuilder
    private var timerCard: some View {
        Group {
            if prayerMode == .timer {
                if isTimerRunning {
                    HeroCard(
                        title: "Prayer/Study Timer",
                        subtitle: isTimerRunning ? (isPaused ? "Paused" : "In progress") : "Start a timer with an alert when time is up.",
                        icon: "timer",
                        tint: timerTintColor,
                        backgroundColor: isTimerRunning ? timerTintColor.opacity(0.20) : nil,
                        strokeColor: isTimerRunning ? timerTintColor.opacity(0.35) : nil
                    ) {
                        VStack(spacing: 10) {
                            ModePicker(disabled: isTimerRunning || stopwatchRunning)

                            Text(formattedTime(remainingSeconds))
                                .font(.system(size: 36, weight: .semibold, design: .monospaced))
                                .foregroundStyle(timerTintColor)
                            HStack(spacing: 24) {
                                Button(action: { togglePause() }) {
                                    Image(systemName: isPaused ? "play.circle.fill" : "pause.circle.fill")
                                        .font(.system(size: 56))
                                        .foregroundStyle(isPaused ? Color.green : timerTintColor)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(isPaused ? "Resume" : "Pause")

                                Button(action: { stopTimer() }) {
                                    Image(systemName: "stop.circle.fill")
                                        .font(.system(size: 56))
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Stop")

                                Button(action: { addFiveMinutes() }) {
                                    Text("+5")
                                        .font(.subheadline.weight(.semibold))
                                        .frame(width: 44, height: 44)
                                        .foregroundStyle(.white)
                                        .background(
                                            Circle().fill(Color.blue)
                                        )
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Add 5 minutes")
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .frame(height: isPad ? iPadCardHeight : nil)
                } else {
                    HeroCard(
                        title: "Prayer/Study Timer",
                        subtitle: "Choose a preset to begin",
                        icon: "timer",
                        tint: .blue
                    ) {
                        VStack(spacing: 12) {
                            ModePicker(disabled: isTimerRunning || stopwatchRunning)

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
                        }
                    }
                    .padding(.horizontal, 16)
                    .frame(height: isPad ? iPadCardHeight : nil)
                }
            } else if prayerMode == .stopwatch {
                HeroCard(
                    title: "Stopwatch",
                    subtitle: stopwatchRunning ? "Running" : (stopwatchElapsed > 0 ? "Paused" : "Ready"),
                    icon: "stopwatch",
                    tint: .blue
                ) {
                    VStack(spacing: 10) {
                        ModePicker(disabled: isTimerRunning || stopwatchRunning)

                        Text(formattedHMS(stopwatchElapsed))
                            .font(.system(size: 36, weight: .semibold, design: .monospaced))
                        HStack(spacing: 24) {
                            if stopwatchRunning {
                                stopwatchRunningControls()
                            } else if stopwatchElapsed > 0 {
                                stopwatchPausedControls()
                            } else {
                                stopwatchReadyControls()
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .frame(height: isPad ? iPadCardHeight : nil)
            } else {
                HeroCard(
                    title: "Daily Focus",
                    subtitle: "What's something you want to focus on today?",
                    icon: "target",
                    tint: .purple
                ) {
                    VStack(spacing: 12) {
                        ModePicker(disabled: isTimerRunning || stopwatchRunning)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Today's Focus")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            TextField("Shown on Dynamic Island", text: $focusTitle)
                                .textFieldStyle(.roundedBorder)
                                .submitLabel(.done)
                                .focused($focusTitleIsFocused)
                        }

                        let hasTitle = !focusTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

                        if hasTitle && isFocusBodyExpanded {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Body")
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
                                StopwatchActivityController.shared.cancel()
                                PrayerTimerActivityController.shared.ensureActivityForFocus(
                                    title: focusTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : focusTitle,
                                    body: focusBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : focusBody
                                )
                                hasSavedFocus = true
                                focusTitleIsFocused = false
                                focusBodyIsFocused = false
                                withAnimation(.spring()) { showFocusSavedToast = true }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                    withAnimation(.easeOut) { showFocusSavedToast = false }
                                }
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
                            .disabled(!hasSavedFocus)

                            Button {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                                    isFocusBodyExpanded.toggle()
                                }
                                if !isFocusBodyExpanded {
                                    focusBodyIsFocused = false
                                }
                            } label: {
                                Image(systemName: isFocusBodyExpanded ? "chevron.up.circle" : "chevron.down.circle")
                                    .font(.title3)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(isFocusBodyExpanded ? "Hide Body" : "Show Body")
                            .accessibilityHint(isFocusBodyExpanded ? "Hides the focus notes field" : "Shows the focus notes field")
                            .disabled(!hasTitle)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.top, 4)
                        .toolbar { ToolbarItem(placement: .keyboard) { Button("Done") { focusTitleIsFocused = false; focusBodyIsFocused = false } } }
                    }
                }
                .padding(.horizontal, 16)
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
           let book = resumeBook,
           let chapter = book.chapters.first(where: { $0.number == progress.chapterNumber }) {
            Button(action: {
                coordinator.push(.reader(book: book, chapter: chapter, startVerse: progress.verseNumber))
            }) {
                HeroCard(
                    title: "",
                    subtitle: nil,
                    icon: nil,
                    tint: .blue
                ) {
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: "arrow.uturn.backward.circle")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Resume")
                                .font(.headline)
                                .bold()
                            Text("Continue where you left off")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("\(progress.bookName) \(progress.chapterNumber):\(progress.verseNumber)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .frame(height: isPad ? iPadCardHeight : nil)
        } else {
            HeroCard(
                title: "",
                subtitle: nil,
                icon: nil,
                tint: .blue
            ) {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: "arrow.uturn.backward.circle")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Resume")
                            .font(.headline)
                            .bold()
                        Text("Continue where you left off")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
            .padding(.horizontal, 16)
            .frame(height: isPad ? iPadCardHeight : nil)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                titleCard
                verseOfDayCard
                timerCard
                resumeCard
            }
            .padding(.horizontal, 0)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("")
        .appToast(isPresented: $showCopyToast, symbol: "doc.on.doc", text: "Copied to Clipboard", tint: .blue)
        .appToast(isPresented: $showFocusSavedToast, symbol: "checkmark.seal.fill", text: "Focus Saved", tint: .green)
        .onAppear {
            // Restore persisted state
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
                    Task { await loadRandomVerse() }
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
            } else {
                hasSavedFocus = false
            }

            Task {
                await mirrorLastReadToAppGroup()
                await handleOpenPendingVerse()
                // Resolve resume book lazily for the Resume card
                if let p = progress {
                    resumeBook = await BibleStore.shared.book(named: p.bookName)
                }
            }

            handlePrayerTimerPendingAction()
            handleStopwatchPendingAction()

            // Start one-shot scheduler for VOTD
            scheduleNextVerseRefreshTimer()

            // Start ticker if needed
            updateTickerSubscription()
        }
        .onChange(of: progressList) { _, _ in
            Task {
                await mirrorLastReadToAppGroup()
                if let p = progress {
                    resumeBook = await BibleStore.shared.book(named: p.bookName)
                } else {
                    resumeBook = nil
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                startMindfulLoggingIfNeeded()
                handlePrayerTimerPendingAction()
                handleStopwatchPendingAction()
                Task { await handleOpenPendingVerse() }
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

    private func tick() {
        if isEditingFocus { return }
        let shouldUpdateLiveActivities = true

        if isTimerRunning && !isPaused && storedEndDate > 0 {
            let remaining = Int(max(0, storedEndDate - Date().timeIntervalSince1970))
            remainingSeconds = remaining
            if remaining == 0 { handleTimerFinished() }
            if shouldUpdateLiveActivities {
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
            if shouldUpdateLiveActivities {
                StopwatchActivityController.shared.update(elapsed: stopwatchElapsed, isRunning: true)
            }
        }

        // Track minute boundary for potential UI updates
        timeMarker = (timeMarker + 1) % 60
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
            storedRemainingWhenPaused = Int(max(0, storedEndDate - now))
            remainingSeconds = storedRemainingWhenPaused
            cancelNotification()
        } else {
            let newEnd = Date().addingTimeInterval(TimeInterval(remainingSeconds))
            storedEndDate = newEnd.timeIntervalSince1970
            storedRemainingWhenPaused = 0
            scheduleNotification(at: Date(timeIntervalSince1970: storedEndDate))
        }
        PrayerTimerActivityController.shared.update(
            remainingSeconds: remainingSeconds,
            totalSeconds: storedTotalSeconds,
            isPaused: isPaused
        )
    }

    private func addFiveMinutes() {
        guard isTimerRunning else { return }
        let delta: Int = 300
        if isPaused {
            remainingSeconds += delta
            storedRemainingWhenPaused += delta
            storedTotalSeconds += delta
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
        isTimerRunning = false
        isPaused = false
        remainingSeconds = 0

        storedRunning = false
        storedPaused = false
        storedEndDate = 0
        storedRemainingWhenPaused = 0
        storedTotalSeconds = 0
        storedStartDate = 0
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
        if scenePhase != .active { stopMindfulLogging() }
        cancelNotification()
        resetTimerState()
        PrayerTimerActivityController.shared.finish()
        showFinishedAlert = true
        startFinishAlerts()
        updateTickerSubscription()
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

    // New async VOTD loader that uses bookNames + per-book load
    private func loadRandomVerse() async {
        if verseOfDayPaused { return }
        let allNames = await bibleStore.bookNames()
        guard !allNames.isEmpty else { return }

        let scope = VerseScope(rawValue: verseScopeRaw) ?? .whole
        let names: [String]
        switch scope {
        case .old:
            names = allNames.filter { oldTestamentBooks.contains($0) }
        case .new:
            names = allNames.filter { !oldTestamentBooks.contains($0) }
        case .whole:
            names = allNames
        case .book:
            names = allNames.filter { $0 == verseSpecificBook }
        }

        guard let bookName = names.randomElement(),
              let book = await bibleStore.book(named: bookName),
              let chapter = book.chapters.randomElement(),
              !chapter.verses.isEmpty,
              let verse = chapter.verses.randomElement() else { return }

        let v = HomeVerseRef(bookName: book.name, chapterNumber: chapter.number, verseNumber: verse.number, verseText: verse.text)
        verseOfDay = v
        storedVerseBook = v.bookName
        storedVerseChapter = v.chapterNumber
        storedVerseNumber = v.verseNumber
        storedVerseText = v.verseText
        mirrorVerseToAppGroup(book: v.bookName, chapter: v.chapterNumber, verse: v.verseNumber, text: v.verseText)
    }

    private func copyVerse(_ v: HomeVerseRef) {
        UIPasteboard.general.string = shareText(bookName: v.bookName, chapter: v.chapterNumber, verse: v.verseNumber, text: v.verseText)
        withAnimation(.spring()) { showCopyToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut) { showCopyToast = false }
        }
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

    private func formattedHMS(_ totalSeconds: Int) -> String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    private func handlePrayerTimerPendingAction() {
        guard let shared = sharedDefaults else { return }
        guard let action = shared.string(forKey: "prayerTimerPendingAction") else { return }
        shared.removeObject(forKey: "prayerTimerPendingAction")
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
private struct HeroCard<Content: View, TrailingAccessory: View>: View {
    let title: String
    let subtitle: String?
    let icon: String?
    let tint: Color
    let backgroundColor: Color?
    let strokeColor: Color?
    let trailingAccessory: (() -> TrailingAccessory)?
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
    ) where TrailingAccessory == EmptyView {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.tint = tint
        self.backgroundColor = backgroundColor
        self.strokeColor = strokeColor
        self.trailingAccessory = nil
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
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.tint = tint
        self.backgroundColor = backgroundColor
        self.strokeColor = strokeColor
        self.trailingAccessory = trailingAccessory
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
                            Text(title)
                                .font(titleFont)
                                .fontWeight(titleFontWeight)
                                .multilineTextAlignment(.center)
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
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
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
