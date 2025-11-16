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

    @State private var unifiedTick: Int = 0
    private let unifiedTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    @State private var showFinishedAlert: Bool = false
    @State private var finishHapticTimer: Timer? = nil

    @Environment(\.modelContext) private var modelContext
    @Query private var favorites: [Favorite]
    @EnvironmentObject private var coordinator: NavigationCoordinator
    @State private var verseOfDay: HomeVerseRef? = nil

    @State private var showCopyToast: Bool = false
    @State private var showFocusSavedToast: Bool = false
    @State private var timeMarker: Int = 0
    @State private var lastVerseAutoRefreshToken: String = ""
    @State private var isHealthKitAvailable: Bool = HealthKitManager.shared.isAvailable()

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var hSize

    private static let sharedGridColumns: [GridItem] = [GridItem(.flexible())]
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

    private var gridColumns: [GridItem] { Self.sharedGridColumns }

    private var isEditingFocus: Bool {
        prayerMode == .focus && (focusTitleIsFocused || focusBodyIsFocused)
    }

    var progress: ReadingProgress? {
        progressList.first
    }

    // Configurable auto-refresh times (defaults to 6:00 AM and 6:00 PM)
    @AppStorage("votdRefresh1Hour") private var votdRefresh1Hour: Int = 6
    @AppStorage("votdRefresh1Minute") private var votdRefresh1Minute: Int = 0
    @AppStorage("votdRefresh2Hour") private var votdRefresh2Hour: Int = 18
    @AppStorage("votdRefresh2Minute") private var votdRefresh2Minute: Int = 0

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

    // MARK: - Next Verse Auto-Refresh Helpers

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

        if now < t1 {
            return t1
        } else if now < t2 {
            return t2
        } else {
            // Tomorrow at t1
            let tomorrow = cal.date(byAdding: .day, value: 1, to: now) ?? now
            return dateForToday(hour: votdRefresh1Hour, minute: votdRefresh1Minute, from: tomorrow) ?? now
        }
    }

    private var nextVerseRefreshDescription: String {
        if verseOfDayPaused {
            return "Auto refresh is paused."
        }
        let now = Date()
        let next = nextAutoRefreshDate(from: now)
        let cal = Calendar.current

        let isSameDay = cal.isDate(now, inSameDayAs: next)
        let isTomorrow = cal.isDate(next, inSameDayAs: cal.date(byAdding: .day, value: 1, to: now) ?? next)

        let dayString: String
        if isSameDay {
            dayString = "Today"
        } else if isTomorrow {
            dayString = "Tomorrow"
        } else {
            dayString = next.formatted(date: .abbreviated, time: .omitted)
        }

        let timeString = next.formatted(date: .omitted, time: .shortened)
        return "Next refresh: \(dayString) at \(timeString)"
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
        WidgetCenter.shared.reloadAllTimelines()
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
                        // Mirror current stored verse to App Group for widget sync
                        mirrorVerseToAppGroup(book: storedVerseBook, chapter: storedVerseChapter, verse: storedVerseNumber, text: storedVerseText)
                        // Prompt widgets to refresh
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

                        Button(action: { toggleFavorite(for: v) }) {
                            Image(systemName: isFavorited(v) ? "heart.fill" : "heart")
                                .foregroundStyle(.red)
                        }
                        .font(.title3)
                        .help("Favorite")
                    }
                    .frame(maxWidth: .infinity)

                    // Next auto-refresh description
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
                                // Pause or Resume toggle
                                Button(action: { togglePause() }) {
                                    Image(systemName: isPaused ? "play.circle.fill" : "pause.circle.fill")
                                        .font(.system(size: 56))
                                        .foregroundStyle(isPaused ? Color.green : timerTintColor)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(isPaused ? "Resume" : "Pause")

                                // Stop (red) — placed next to Pause
                                Button(action: { stopTimer() }) {
                                    Image(systemName: "stop.circle.fill")
                                        .font(.system(size: 56))
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Stop")

                                // +5 minutes — blue button with "+5" label
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
                                // Custom
                                Button {
                                    if isHealthKitAvailable && !healthKitPrompted {
                                        Task {
                                            await requestHealthKitIfNeeded()
                                        }
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

                                // 5
                                Button { startTimer(minutes: 5) } label: {
                                    Text("5")
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
                                .accessibilityLabel("Start 5 minutes")

                                // 10
                                Button { startTimer(minutes: 10) } label: {
                                    Text("10")
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
                                .accessibilityLabel("Start 10 minutes")

                                // 15
                                Button { startTimer(minutes: 15) } label: {
                                    Text("15")
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
                                .accessibilityLabel("Start 15 minutes")

                                // 20
                                Button { startTimer(minutes: 20) } label: {
                                    Text("20")
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
                                .accessibilityLabel("Start 20 minutes")

                                // 30
                                Button { startTimer(minutes: 30) } label: {
                                    Text("30")
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
                                .accessibilityLabel("Start 30 minutes")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal, 16)
                    .frame(height: isPad ? iPadCardHeight : nil)
                }
            } else if prayerMode == .stopwatch { // Stopwatch mode
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
            } else { // Focus mode
                HeroCard(
                    title: "Daily Focus",
                    subtitle: "What's something you want to focus on today?",
                    icon: "target",
                    tint: .purple
                ) {
                    VStack(spacing: 12) {
                        ModePicker(disabled: isTimerRunning || stopwatchRunning)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Title")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            TextField("Shown on Dynamic Island", text: $focusTitle)
                                .textFieldStyle(.roundedBorder)
                                .submitLabel(.done)
                                .focused($focusTitleIsFocused)
                        }

                        let hasTitle = !focusTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

                        if hasTitle {
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
                                // Save focus to shared defaults and update Live Activity/Dynamic Island
                                sharedDefaults?.set(focusTitle, forKey: "focusTitle")
                                sharedDefaults?.set(focusBody, forKey: "focusBody")
                                // Ensure only one activity is active: stop stopwatch
                                StopwatchActivityController.shared.cancel()
                                // Ensure Focus is active in Live Activity/DI with compact leading/trailing via focusTitle and body
                                PrayerTimerActivityController.shared.ensureActivityForFocus(
                                    title: focusTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : focusTitle,
                                    body: focusBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : focusBody
                                )
                                // Mark as saved and dismiss keyboard
                                hasSavedFocus = true
                                focusTitleIsFocused = false
                                focusBodyIsFocused = false
                                // Show confirmation toast
                                withAnimation(.spring()) { showFocusSavedToast = true }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                    withAnimation(.easeOut) { showFocusSavedToast = false }
                                }
                            } label: {
                                Label("Save", systemImage: "square.and.arrow.down")
                            }
                            .labelStyle(.iconOnly)
                            .font(.title3)
                            .buttonStyle(.plain)
                            .help("Save")
                            .accessibilityLabel("Save")
                            .disabled(!hasTypedLetter)

                            Button {
                                // Clear focus fields and update shared defaults/live activity
                                focusTitle = ""
                                focusBody = ""
                                sharedDefaults?.set("", forKey: "focusTitle")
                                sharedDefaults?.set("", forKey: "focusBody")
                                // Remove Focus from Live Activity/Dynamic Island
                                PrayerTimerActivityController.shared.cancel()
                                // Mark as not saved and dismiss keyboard
                                hasSavedFocus = false
                                focusTitleIsFocused = false
                                focusBodyIsFocused = false
                            } label: {
                                Label("Clear", systemImage: "xmark.circle.fill")
                            }
                            .labelStyle(.iconOnly)
                            .font(.title3)
                            .buttonStyle(.plain)
                            .foregroundStyle(.red)
                            .help("Clear")
                            .accessibilityLabel("Clear")
                            .disabled(!hasSavedFocus)
                        }
                        .padding(.top, 4)
                        .toolbar { ToolbarItem(placement: .keyboard) { Button("Done") { focusTitleIsFocused = false; focusBodyIsFocused = false } } }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    @ViewBuilder
    private var resumeCard: some View {
        if let progress = progress,
           let book = BibleData.books.first(where: { $0.name == progress.bookName }),
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
                        Text("Start reading from the Bible tab")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
            .redacted(reason: .placeholder)
            .padding(.horizontal, 16)
            .frame(height: isPad ? iPadCardHeight : nil)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Title Card
                titleCard

                // Verse of the Day Card
                verseOfDayCard

                // Timer / Stopwatch Card
                timerCard

                // Resume Card
                resumeCard
            }
            .padding(.horizontal, 0)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("")
        .appToast(isPresented: $showCopyToast, symbol: "doc.on.doc", text: "Copied to Clipboard", tint: .blue)
        .appToast(isPresented: $showFocusSavedToast, symbol: "checkmark.seal.fill", text: "Focus Saved", tint: .green)
        .onAppear {
            // Defer prompts: DO NOT request notifications/HealthKit here.
            // Restore persisted state
            isTimerRunning = storedRunning
            isPaused = storedPaused
            // Cache HealthKit availability
            isHealthKitAvailable = HealthKitManager.shared.isAvailable()
            // Do not request HealthKit authorization here; defer to first timer/stopwatch start.

            if storedRunning {
                if isPaused {
                    remainingSeconds = storedRemainingWhenPaused
                } else if storedEndDate > 0 {
                    let remaining = Int(max(0, storedEndDate - Date().timeIntervalSince1970))
                    remainingSeconds = remaining
                    if remaining == 0 {
                        handleTimerFinished()
                    }
                }
            }
            if verseOfDayPaused {
                // Restore last verse without refreshing when paused
                if !storedVerseBook.isEmpty && storedVerseChapter > 0 && storedVerseNumber > 0 && !storedVerseText.isEmpty {
                    verseOfDay = HomeVerseRef(bookName: storedVerseBook, chapterNumber: storedVerseChapter, verseNumber: storedVerseNumber, verseText: storedVerseText)
                    mirrorVerseToAppGroup(book: storedVerseBook, chapter: storedVerseChapter, verse: storedVerseNumber, text: storedVerseText)
                }
            } else {
                // Do not arbitrarily refresh; show the last stored verse if available, otherwise seed an initial verse.
                if !storedVerseBook.isEmpty && storedVerseChapter > 0 && storedVerseNumber > 0 && !storedVerseText.isEmpty {
                    verseOfDay = HomeVerseRef(bookName: storedVerseBook, chapterNumber: storedVerseChapter, verseNumber: storedVerseNumber, verseText: storedVerseText)
                    mirrorVerseToAppGroup(book: storedVerseBook, chapter: storedVerseChapter, verse: storedVerseNumber, text: storedVerseText)
                } else {
                    loadRandomVerse()
                }
            }

            // Initialize stopwatch elapsed from stored state
            if stopwatchRunning {
                let now = Date().timeIntervalSince1970
                let base = stopwatchAccumulated + Int(max(0, now - stopwatchStartDate))
                stopwatchElapsed = base
            } else {
                stopwatchElapsed = stopwatchAccumulated
            }

            // Initialize saved focus state from shared defaults
            if let shared = sharedDefaults {
                let savedTitle = (shared.string(forKey: "focusTitle") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let savedBody = (shared.string(forKey: "focusBody") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                hasSavedFocus = !(savedTitle.isEmpty && savedBody.isEmpty)
            } else {
                hasSavedFocus = false
            }

            handlePrayerTimerPendingAction()
            handleStopwatchPendingAction()
        }
        .onReceive(unifiedTimer) { _ in
            // Process any pending Live Activity actions promptly
            handlePrayerTimerPendingAction()

            // Increment a unified tick counter
            unifiedTick &+= 1

            // If the user is actively typing in Focus, skip per-second background work to keep the UI responsive
            if isEditingFocus {
                return
            }
            let shouldUpdateLiveActivities = true

            // Timer logic: update remaining seconds when running and not paused
            if isTimerRunning && !isPaused && storedEndDate > 0 {
                let remaining = Int(max(0, storedEndDate - Date().timeIntervalSince1970))
                remainingSeconds = remaining
                if remaining == 0 {
                    handleTimerFinished()
                }

                // Live Activity: update each tick
                if shouldUpdateLiveActivities {
                    PrayerTimerActivityController.shared.update(
                        remainingSeconds: remainingSeconds,
                        totalSeconds: storedTotalSeconds,
                        isPaused: isPaused
                    )
                }
            }

            // Stopwatch logic: update elapsed when running
            if stopwatchRunning {
                let now = Date().timeIntervalSince1970
                let base = stopwatchAccumulated + Int(max(0, now - stopwatchStartDate))
                stopwatchElapsed = base

                // Live Activity: update stopwatch each tick
                if shouldUpdateLiveActivities {
                    StopwatchActivityController.shared.update(elapsed: stopwatchElapsed, isRunning: true)
                }
            }

            // Minute tick: every 60 seconds, update marker and check auto verse refresh
            if unifiedTick % 60 == 0 {
                timeMarker = (timeMarker + 1) % 60
                checkAutoVerseRefresh()
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            switch newPhase {
            case .active:
                // App became active: start logging if available
                startMindfulLoggingIfNeeded()
                handlePrayerTimerPendingAction()
                handleStopwatchPendingAction()
            case .inactive, .background:
                // Stop logging only if the timer is not running and stopwatch is not running; keep logging while either runs
                if !isTimerRunning && !stopwatchRunning {
                    stopMindfulLogging()
                }
            @unknown default:
                break
            }
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
    }

    private func checkAutoVerseRefresh() {
        guard !verseOfDayPaused else { return }
        let now = Date()
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        guard let hour = comps.hour, let minute = comps.minute,
              let year = comps.year, let month = comps.month, let day = comps.day else { return }

        func tokenFor(slot: Int) -> String {
            return "\(year)-\(month)-\(day)-\(slot)-\(minute)"
        }

        // Only refresh exactly when the current time matches either configured refresh time
        if hour == votdRefresh1Hour && minute == votdRefresh1Minute {
            let token = tokenFor(slot: 1)
            if token != lastVerseAutoRefreshToken {
                lastVerseAutoRefreshToken = token
                loadRandomVerse()
            }
            return
        }
        if hour == votdRefresh2Hour && minute == votdRefresh2Minute {
            let token = tokenFor(slot: 2)
            if token != lastVerseAutoRefreshToken {
                lastVerseAutoRefreshToken = token
                loadRandomVerse()
            }
            return
        }
    }

    private func startTimer(minutes: Int) {
        // Defer and request permissions on first use
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

        // Persist
        storedRunning = true
        storedPaused = false
        storedStartDate = start.timeIntervalSince1970
        storedEndDate = end.timeIntervalSince1970
        storedRemainingWhenPaused = 0

        startMindfulLoggingIfNeeded()

        scheduleNotification(at: end)

        // Cancel any running stopwatch activity to enforce single active Live Activity
        StopwatchActivityController.shared.cancel()

        // Live Activity: start Prayer/Study timer activity
        PrayerTimerActivityController.shared.start(
            sessionName: "Prayer/Study",
            totalSeconds: storedTotalSeconds,
            remainingSeconds: remainingSeconds,
            isPaused: false
        )
    }

    private func togglePause() {
        guard isTimerRunning else { return }
        isPaused.toggle()
        storedPaused = isPaused
        if isPaused {
            // Freeze remaining based on stored end date for robustness
            let now = Date().timeIntervalSince1970
            storedRemainingWhenPaused = Int(max(0, storedEndDate - now))
            // Keep UI in sync
            remainingSeconds = storedRemainingWhenPaused
            cancelNotification()
        } else {
            // Resume: compute new end date from remaining
            let newEnd = Date().addingTimeInterval(TimeInterval(remainingSeconds))
            storedEndDate = newEnd.timeIntervalSince1970
            storedRemainingWhenPaused = 0
            scheduleNotification(at: Date(timeIntervalSince1970: storedEndDate))
        }

        // Live Activity: reflect pause/resume
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
            // Extend paused remaining and total
            remainingSeconds += delta
            storedRemainingWhenPaused += delta
            storedTotalSeconds += delta
            // Update Live Activity
            PrayerTimerActivityController.shared.update(
                remainingSeconds: remainingSeconds,
                totalSeconds: storedTotalSeconds,
                isPaused: isPaused
            )
        } else {
            // Extend end date and total
            storedEndDate += TimeInterval(delta)
            storedTotalSeconds += delta
            // Refresh remaining now for immediate UI feedback
            let newRemaining = Int(max(0, storedEndDate - Date().timeIntervalSince1970))
            remainingSeconds = newRemaining
            // Reschedule notification at new end time
            scheduleNotification(at: Date(timeIntervalSince1970: storedEndDate))
            // Update Live Activity
            PrayerTimerActivityController.shared.update(
                remainingSeconds: remainingSeconds,
                totalSeconds: storedTotalSeconds,
                isPaused: isPaused
            )
        }
        // Optional: light haptic to confirm action
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
        // End global mindful logging if app is not active; if active, continue logging app-open time
        if scenePhase != .active {
            stopMindfulLogging()
        }

        resetTimerState()

        cancelNotification()
        stopFinishAlerts()

        // Live Activity: cancel
        PrayerTimerActivityController.shared.cancel()
        showFinishedAlert = false
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
        // Remove any existing pending timer notification
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
        // Ensure we only fire once
        if !isTimerRunning { return }

        // End global mindful logging if app is not active; if active, continue logging app-open time
        if scenePhase != .active {
            stopMindfulLogging()
        }

        // Ensure no pending local notification fires now that we're handling the finish in the foreground
        cancelNotification()

        resetTimerState()

        // Live Activity: finish
        PrayerTimerActivityController.shared.finish()

        // Start foreground alert with repeating vibration if alert is shown
        showFinishedAlert = true
        startFinishAlerts()
    }

    private func startFinishAlerts() {
        stopFinishAlerts()
        // Cache the selected sound ID to avoid capturing self in the timer closure
        let soundID = selectedFinishSoundID
        // Repeating sound + vibration every 1.5 seconds while alert is shown
        finishHapticTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
            // Play audible system sound
            AudioServicesPlaySystemSound(soundID)
            // Vibrate
            AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
        }
        // Also play immediately
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
                // Fallback to whole if not chosen
                books = allBooks
            }
        }

        guard let book = books.randomElement(), let chapter = book.chapters.randomElement(), !chapter.verses.isEmpty, let verse = chapter.verses.randomElement() else { return }
        verseOfDay = HomeVerseRef(bookName: book.name, chapterNumber: chapter.number, verseNumber: verse.number, verseText: verse.text)
        storedVerseBook = book.name
        storedVerseChapter = chapter.number
        storedVerseNumber = verse.number
        storedVerseText = verse.text
        // Mirror to App Group for widget sync
        mirrorVerseToAppGroup(book: book.name, chapter: chapter.number, verse: verse.number, text: verse.text)
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
        // Request HealthKit on first use (deferred)
        if isHealthKitAvailable && !healthKitPrompted {
            Task { await requestHealthKitIfNeeded() }
        }

        let now = Date().timeIntervalSince1970
        if stopwatchStartDate == 0 { stopwatchStartDate = now }
        stopwatchRunning = true
        startMindfulLoggingIfNeeded()
        // Cancel Prayer/Study timer/focus Live Activity to enforce single active activity
        PrayerTimerActivityController.shared.cancel()
        // Live Activity: start stopwatch
        StopwatchActivityController.shared.start(sessionName: "Stopwatch", initialElapsed: stopwatchElapsed)
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
        // Live Activity: update paused state
        StopwatchActivityController.shared.update(elapsed: stopwatchElapsed, isRunning: false)
    }

    private func stopStopwatch() {
        // End global mindful logging if app is not active; if active, continue logging app-open time
        if scenePhase != .active {
            stopMindfulLogging()
        }
        stopwatchRunning = false
        stopwatchStartDate = 0
        stopwatchAccumulated = 0
        stopwatchElapsed = 0
        // Live Activity: finish stopwatch
        StopwatchActivityController.shared.finish(finalStatus: "Stopped")
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
        // Clear immediately to avoid reprocessing
        shared.removeObject(forKey: "prayerTimerPendingAction")
        switch action {
        case "togglePause":
            if isTimerRunning {
                togglePause()
            }
        case "add5":
            if isTimerRunning {
                addFiveMinutes()
            }
        case "stop":
            if isTimerRunning {
                stopTimer()
            }
        default:
            break
        }
    }

    private func handleStopwatchPendingAction() {
        guard let shared = sharedDefaults else { return }
        guard let action = shared.string(forKey: "stopwatchPendingAction") else { return }
        // Clear immediately to avoid reprocessing
        shared.removeObject(forKey: "stopwatchPendingAction")
        switch action {
        case "togglePause":
            if stopwatchRunning {
                pauseStopwatch()
            } else {
                startStopwatch()
            }
        case "stop":
            if stopwatchRunning || stopwatchElapsed > 0 {
                stopStopwatch()
            }
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
private struct HeroCard<Content: View, TrailingAccessory: View = EmptyView>: View {
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

    // Init without trailing accessory (infers TrailingAccessory == EmptyView)
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

    // Init with trailing accessory
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
// Note: HealthKit logging is handled in HomeView, prompts are now deferred until first use.
