import SwiftUI
import SwiftData
import Combine
import UserNotifications
import AudioToolbox
import UIKit
import HealthKit
import Foundation

private enum VerseScope: String { case old, new, whole, book }

struct HomeView: View {
    private enum PrayerMode: String { case timer, stopwatch }

    @Query private var progressList: [ReadingProgress]
    @State private var showPrayerStudySheet: Bool = false

    @State private var isTimerRunning: Bool = false
    @State private var isPaused: Bool = false
    @State private var remainingSeconds: Int = 0
    private let prayerTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

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
    @State private var stopwatchElapsed: Int = 0
    private let stopwatchTicker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    @State private var showFinishedAlert: Bool = false
    @State private var finishHapticTimer: Timer? = nil

    @Environment(\.modelContext) private var modelContext
    @Query private var favorites: [Favorite]
    @EnvironmentObject private var coordinator: NavigationCoordinator
    @State private var verseOfDay: VerseRef? = nil

    @State private var showCopyToast: Bool = false
    @State private var startIconBounce: Bool = false
    @State private var timeMarker: Int = 0
    @State private var isHealthKitAvailable: Bool = HealthKitManager.shared.isAvailable()

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var hSize

    private let minuteTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private static let sharedGridColumns: [GridItem] = [GridItem(.flexible())]
    private static let notificationID = "PrayerStudyTimerFinished"
    private static let notificationTitle = "Prayer/Study Finished"
    private static let notificationBody = "Your prayer/study timer has completed."

    private var selectedFinishSoundID: SystemSoundID {
        (TimerSound(rawValue: timerSoundSelection) ?? .default).systemSoundID
    }

    private var remainingFraction: Double {
        guard storedTotalSeconds > 0 else { return 1.0 }
        return max(0.0, min(1.0, Double(remainingSeconds) / Double(storedTotalSeconds)))
    }

    private var timerTintColor: Color {
        switch remainingFraction {
        case 0.5...1.0:
            return .green
        case 0.1..<0.5:
            return .yellow
        default:
            return .red
        }
    }

    private var isEvening: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        // Evening/Night from 6 PM (18) through 4:59 AM (i.e., hours 0...4)
        return hour >= 18 || hour < 5
    }

    private var verseCardTitle: String { isEvening ? "Word of the Night" : "Verse of the Day" }
    private var verseCardIcon: String { isEvening ? "moon.stars" : "sun.max.fill" }

    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
    private var iPadCardHeight: CGFloat { 200 }

    private var gridColumns: [GridItem] { Self.sharedGridColumns }

    var progress: ReadingProgress? {
        progressList.first
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

    // MARK: - Split cards to reduce type-checking complexity
    @ViewBuilder
    private var titleCard: some View {
        HeroCard(title: "Word of God", subtitle: "Welcome back", icon: "book.fill", tint: .blue, titleFont: .largeTitle, titleFontWeight: .black) {
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
        .padding(.top)
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
            trailingAccessory: AnyView(
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
            )
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
                } else {
                    Text("Tap refresh to get today's verse.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button(action: { loadRandomVerse() }) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                    .disabled(verseOfDayPaused)
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
                        subtitle: isTimerRunning ? (isPaused ? "Paused" : "In progress") : "Start a focused timer with an alert when time is up.",
                        icon: "timer",
                        tint: timerTintColor,
                        backgroundColor: isTimerRunning ? timerTintColor.opacity(0.20) : nil,
                        strokeColor: isTimerRunning ? timerTintColor.opacity(0.35) : nil
                    ) {
                        VStack(spacing: 10) {
                            // Mode picker
                            Picker("Mode", selection: $prayerMode) {
                                Text("Timer").tag(PrayerMode.timer)
                                Text("Stopwatch").tag(PrayerMode.stopwatch)
                            }
                            .pickerStyle(.segmented)
                            .controlSize(.small)
                            .disabled(isTimerRunning || stopwatchRunning)

                            Text(formattedTime(remainingSeconds))
                                .font(.system(size: 36, weight: .semibold, design: .monospaced))
                                .foregroundStyle(timerTintColor)
                            HStack(spacing: 12) {
                                Button(action: { togglePause() }) {
                                    Label(isPaused ? "Resume" : "Pause", systemImage: isPaused ? "play" : "pause.fill")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .tint(timerTintColor)

                                Button(role: .destructive, action: stopTimer) {
                                    Label("Stop", systemImage: "stop.fill")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .frame(height: isPad ? iPadCardHeight : nil)
                } else {
                    HeroCard(
                        title: "Prayer/Study Timer",
                        subtitle: "Start a focused timer with an alert when time is up.",
                        icon: "timer",
                        tint: .blue
                    ) {
                        VStack(spacing: 10) {
                            // Mode picker
                            Picker("Mode", selection: $prayerMode) {
                                Text("Timer").tag(PrayerMode.timer)
                                Text("Stopwatch").tag(PrayerMode.stopwatch)
                            }
                            .pickerStyle(.segmented)
                            .controlSize(.small)
                            .disabled(isTimerRunning || stopwatchRunning)

                            HStack(spacing: 12) {
                                Image(systemName: "play")
                                    .imageScale(.large)
                                    .foregroundStyle(.blue)
                                    .scaleEffect(startIconBounce ? 1.15 : 1.0)
                                    .animation(.spring(response: 0.25, dampingFraction: 0.6, blendDuration: 0.0), value: startIconBounce)
                                Text("Start")
                                    .font(.headline)
                                    .bold()
                                Spacer()
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(.primary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .frame(height: isPad ? iPadCardHeight : nil)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if isHealthKitAvailable && !healthKitPrompted {
                            HealthKitManager.shared.requestAuthorizationIfNeeded { _ in
                                Task { @MainActor in
                                    self.healthKitPrompted = true
                                }
                            }
                        }
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                            startIconBounce = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                            startIconBounce = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                            showPrayerStudySheet = true
                        }
                    }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel("Start")
                }
            } else { // Stopwatch mode
                HeroCard(
                    title: "Stopwatch",
                    subtitle: stopwatchRunning ? "Running" : (stopwatchElapsed > 0 ? "Paused" : "Ready"),
                    icon: "stopwatch",
                    tint: .blue
                ) {
                    VStack(spacing: 10) {
                        // Mode picker
                        Picker("Mode", selection: $prayerMode) {
                            Text("Timer").tag(PrayerMode.timer)
                            Text("Stopwatch").tag(PrayerMode.stopwatch)
                        }
                        .pickerStyle(.segmented)
                        .controlSize(.small)
                        .disabled(isTimerRunning || stopwatchRunning)

                        Text(formattedHMS(stopwatchElapsed))
                            .font(.system(size: 36, weight: .semibold, design: .monospaced))
                        HStack(spacing: 12) {
                            if stopwatchRunning {
                                Button("Pause") { pauseStopwatch() }
                                    .buttonStyle(.bordered)
                                Button("Stop") { stopStopwatch() }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.red)
                            } else {
                                Button(stopwatchElapsed == 0 ? "Start" : "Resume") { startStopwatch() }
                                    .buttonStyle(.borderedProminent)
                                if stopwatchElapsed > 0 {
                                    Button("Reset") { resetStopwatch() }
                                        .buttonStyle(.bordered)
                                        .tint(.secondary)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .frame(height: isPad ? iPadCardHeight : nil)
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
            LazyVGrid(columns: gridColumns, spacing: 16) {
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
        .onAppear {
            // Request notification permission once
            if !didRequestNotifications {
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
                didRequestNotifications = true
            }

            // Restore persisted state
            isTimerRunning = storedRunning
            isPaused = storedPaused
            // Cache HealthKit availability
            isHealthKitAvailable = HealthKitManager.shared.isAvailable()
            // Request HealthKit authorization and start mindful logging on app open
            if isHealthKitAvailable && !healthKitPrompted {
                HealthKitManager.shared.requestAuthorizationIfNeeded { _ in
                    Task { @MainActor in
                        self.healthKitPrompted = true
                        startMindfulLoggingIfNeeded()
                    }
                }
            } else {
                startMindfulLoggingIfNeeded()
            }
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
                    verseOfDay = VerseRef(bookName: storedVerseBook, chapterNumber: storedVerseChapter, verseNumber: storedVerseNumber, verseText: storedVerseText)
                }
            } else {
                loadRandomVerse()
            }
            // Initialize stopwatch elapsed from stored state
            if stopwatchRunning {
                let now = Date().timeIntervalSince1970
                let base = stopwatchAccumulated + Int(max(0, now - stopwatchStartDate))
                stopwatchElapsed = base
            } else {
                stopwatchElapsed = stopwatchAccumulated
            }
        }
        .onReceive(prayerTimer) { _ in
            guard isTimerRunning else { return }
            if isPaused { return }
            if storedEndDate > 0 {
                let remaining = Int(max(0, storedEndDate - Date().timeIntervalSince1970))
                remainingSeconds = remaining
                if remaining == 0 {
                    handleTimerFinished()
                }
            }
        }
        .onReceive(stopwatchTicker) { _ in
            guard stopwatchRunning else { return }
            let now = Date().timeIntervalSince1970
            let base = stopwatchAccumulated + Int(max(0, now - stopwatchStartDate))
            stopwatchElapsed = base
        }
        .onReceive(minuteTimer) { _ in
            // Update a marker to trigger view refresh for time-based changes (e.g., after 6 PM)
            timeMarker = (timeMarker + 1) % 60
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            switch newPhase {
            case .active:
                // App became active: start logging if available
                startMindfulLoggingIfNeeded()
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

    private func startTimer(minutes: Int) {
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

        // HealthKit: request authorization on first use
        if isHealthKitAvailable && !healthKitPrompted {
            HealthKitManager.shared.requestAuthorizationIfNeeded { _ in
                Task { @MainActor in
                    self.healthKitPrompted = true
                }
            }
        }

        startMindfulLoggingIfNeeded()

        scheduleNotification(at: end)
    }

    private func togglePause() {
        guard isTimerRunning else { return }
        isPaused.toggle()
        storedPaused = isPaused
        if isPaused {
            // Freeze remaining
            storedRemainingWhenPaused = remainingSeconds
            cancelNotification()
        } else {
            // Resume: compute new end date from remaining
            let newEnd = Date().addingTimeInterval(TimeInterval(remainingSeconds))
            storedEndDate = newEnd.timeIntervalSince1970
            storedRemainingWhenPaused = 0
            scheduleNotification(at: Date(timeIntervalSince1970: storedEndDate))
        }
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

        resetTimerState()

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
        verseOfDay = VerseRef(bookName: book.name, chapterNumber: chapter.number, verseNumber: verse.number, verseText: verse.text)
        storedVerseBook = book.name
        storedVerseChapter = chapter.number
        storedVerseNumber = verse.number
        storedVerseText = verse.text
    }

    private func copyVerse(_ v: VerseRef) {
        UIPasteboard.general.string = shareText(bookName: v.bookName, chapter: v.chapterNumber, verse: v.verseNumber, text: v.verseText)
        withAnimation(.spring()) { showCopyToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut) { showCopyToast = false }
        }
    }

    private func isFavorited(_ v: VerseRef) -> Bool {
        favorites.contains { fav in
            fav.bookName == v.bookName && fav.chapterNumber == v.chapterNumber && fav.verseNumber == v.verseNumber
        }
    }

    private func toggleFavorite(for v: VerseRef) {
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
        let now = Date().timeIntervalSince1970
        if stopwatchStartDate == 0 { stopwatchStartDate = now }
        stopwatchRunning = true
        startMindfulLoggingIfNeeded()
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
    }

    private func resetStopwatch() {
        stopwatchRunning = false
        stopwatchStartDate = 0
        stopwatchAccumulated = 0
        stopwatchElapsed = 0
    }

    private func formattedHMS(_ totalSeconds: Int) -> String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
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

private struct HeroCard<Content: View>: View {
    let title: String
    let subtitle: String?
    let icon: String?
    let tint: Color
    let backgroundColor: Color?
    let strokeColor: Color?
    let trailingAccessory: AnyView?
    let titleFont: Font
    let titleFontWeight: Font.Weight
    @ViewBuilder var content: Content

    init(
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        tint: Color = .accentColor,
        backgroundColor: Color? = nil,
        strokeColor: Color? = nil,
        trailingAccessory: AnyView? = nil,
        titleFont: Font = .headline,
        titleFontWeight: Font.Weight = .bold,
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
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !(title.isEmpty && subtitle == nil && icon == nil) {
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
                        trailingAccessory
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
        )
        .overlay(
            Group {
                if let strokeColor {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(strokeColor, lineWidth: 1)
                } else {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.black.opacity(0.06), lineWidth: 1)
                }
            }
        )
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
    }
}

private struct VerseRef {
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
// Note: HealthKit logging is handled in HomeView, no changes needed here.

