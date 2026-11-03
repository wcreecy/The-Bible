import Foundation
import Observation
import UserNotifications
import ActivityKit
import AudioToolbox
import SwiftUI

/// The app's single prayer timer. Shared because restoring a timer has side effects
/// (resuming the ticker, finishing an expired session), which must happen only once.
@MainActor
@Observable
final class PrayerTimerController {
    static let shared = PrayerTimerController()

    // MARK: - UI State

    private(set) var isRunning: Bool = false
    private(set) var isPaused: Bool = false
    private(set) var remainingSeconds: Int = 0
    private(set) var totalSeconds: Int = 0
    /// What the running timer is for. After a session ends it stays set, so the finished
    /// alert still names the session that just completed.
    private(set) var kind: PrayerTimerKind = .prayer
    var showFinishedAlert: Bool = false
    /// Set for a few seconds after Stop, so an accidental stop can be undone.
    private(set) var undoableStop: StoppedSession?

    /// Timer state captured when the timer is stopped, for Undo.
    struct StoppedSession: Equatable {
        let remainingSeconds: Int
        let totalSeconds: Int
        let wasPaused: Bool
        let sessionSeconds: Int
    }

    /// How long Undo stays available after Stop.
    private static let undoWindow: Duration = .seconds(6)

    // MARK: - Persistence (UserDefaults keys)

    // Persistence only; the UI reads the properties above. Keep the same keys HomeView
    // used so behavior remains compatible across launches.
    @ObservationIgnored @AppStorage("prayerTimerEndDate") private var storedEndDate: Double = 0
    @ObservationIgnored @AppStorage("prayerTimerRunning") private var storedRunning: Bool = false
    @ObservationIgnored @AppStorage("prayerTimerPaused") private var storedPaused: Bool = false
    @ObservationIgnored @AppStorage("prayerTimerRemainingWhenPaused") private var storedRemainingWhenPaused: Int = 0
    @ObservationIgnored @AppStorage("prayerTimerTotalSeconds") private var storedTotalSeconds: Int = 0
    @ObservationIgnored @AppStorage("prayerTimerStartDate") private var storedStartDate: Double = 0
    @ObservationIgnored @AppStorage("prayerTimerActiveKind") private var storedActiveKind: String = PrayerTimerKind.prayer.rawValue
    /// The kind chosen for the next session; the Home card and setup sheet change it. Read
    /// from UserDefaults each time, because an `@AppStorage` copy kept here can lag behind
    /// the views that change it.
    private var preferredKind: PrayerTimerKind {
        get {
            UserDefaults.standard.string(forKey: PrayerTimerKind.preferenceKey)
                .flatMap(PrayerTimerKind.init(rawValue:)) ?? .prayer
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: PrayerTimerKind.preferenceKey) }
    }
    @ObservationIgnored @AppStorage("timerSoundSelection") private var timerSoundSelection: String = TimerSound.default.rawValue
    @ObservationIgnored @AppStorage("didRequestNotifications") private var didRequestNotifications: Bool = false
    /// The most recent duration started, offered as a preset on the card.
    @ObservationIgnored @AppStorage(PrayerTimerController.lastMinutesKey) private var lastMinutes: Int = 0
    /// Start of the current counting-down stretch, for prayer stats. 0 while paused or stopped.
    @ObservationIgnored @AppStorage("prayerSegmentStartDate") private var prayerSegmentStartDate: Double = 0
    /// Active seconds so far in this session, across pauses.
    @ObservationIgnored @AppStorage("prayerSessionSeconds") private var prayerSessionSeconds: Int = 0

    static let lastMinutesKey = "prayerTimerLastMinutes"

    @ObservationIgnored private var undoExpiryTask: Task<Void, Never>?

    // MARK: - External collaborators

    private var sharedDefaults: UserDefaults? { UserDefaults(suiteName: "group.bible.app") }

    // MARK: - Internal ticking

    @ObservationIgnored private var tickerTask: Task<Void, Never>?

    // Suppression windows to avoid recompute churn right after adjustments
    @ObservationIgnored private var suppressTimerActivityUpdatesUntil: Date = .distantPast
    @ObservationIgnored private var suppressTimerRecomputeUntil: Date = .distantPast

    // Authoritative in-memory end date used briefly after adjustments to avoid @AppStorage staleness
    @ObservationIgnored private var liveEndDate: TimeInterval = 0

    // Finish sound/haptic loop
    @ObservationIgnored private var finishHapticTimer: Timer?

    // Invalidates older asynchronous AlarmKit scheduling attempts after timer changes.
    @ObservationIgnored private var completionSchedulingToken = UUID()

    // MARK: - Derived

    private var selectedFinishSoundID: SystemSoundID {
        (TimerSound(rawValue: timerSoundSelection) ?? .default).systemSoundID
    }

    // MARK: - Public lifecycle

    private init() {
        // The developer data reset stops the timer even while Home isn't on screen.
        NotificationCenter.observe(.resetPrayerTimer, for: self) { controller in
            // A data reset shouldn't offer to bring the timer back.
            controller.stop(allowsUndo: false)
        }

        // Restore persisted state
        isRunning = storedRunning
        isPaused = storedPaused
        totalSeconds = storedTotalSeconds
        kind = PrayerTimerKind(rawValue: storedActiveKind) ?? .prayer

        if storedRunning {
            if storedPaused {
                remainingSeconds = storedRemainingWhenPaused
            } else if storedEndDate > 0 {
                let remaining = Int(max(0, storedEndDate - Date().timeIntervalSince1970))
                remainingSeconds = remaining
                if remaining == 0 {
                    handleTimerFinished()
                }
            }
        }

        // Resume Mindful Minutes tracking when an active timer is restored.
        if storedRunning, !storedPaused {
            MindfulMinutesTracker.shared.start(.prayerTimer)
        }
        // Same for prayer stats: an open stretch only makes sense while counting down.
        if !storedRunning {
            prayerSegmentStartDate = 0
            prayerSessionSeconds = 0
        } else if storedPaused {
            prayerSegmentStartDate = 0
        }
        updateTickerSubscription()
    }

    func onAppear() {
        // placeholder for future needs
    }

    func onSceneBecameActive() {
        // Re-evaluate remaining time
        if isRunning && !isPaused && storedEndDate > 0 {
            let remaining = Int(max(0, storedEndDate - Date().timeIntervalSince1970))
            remainingSeconds = remaining
            if remaining == 0 {
                handleTimerFinished()
            }
        }
        updateTickerSubscription()
    }

    func onSceneBecameInactiveOrBackground() {
        updateTickerSubscription()
    }

    // MARK: - Public control API

    /// Starts a timer. Without an explicit `kind`, uses the one chosen on the card or setup sheet.
    func start(minutes: Int, kind requestedKind: PrayerTimerKind? = nil) {
        Task { await requestNotificationsIfNeeded() }
        clearUndo()

        kind = requestedKind ?? preferredKind
        storedActiveKind = kind.rawValue
        preferredKind = kind

        lastMinutes = max(1, minutes)
        prayerSessionSeconds = 0
        let secs = max(1, minutes) * 60
        remainingSeconds = secs
        totalSeconds = secs

        let start = Date()
        let end = start.addingTimeInterval(TimeInterval(secs))
        isPaused = false
        isRunning = true

        storedRunning = true
        storedPaused = false
        storedStartDate = start.timeIntervalSince1970
        storedEndDate = end.timeIntervalSince1970
        storedRemainingWhenPaused = 0
        storedTotalSeconds = secs

        liveEndDate = storedEndDate
        suppressTimerActivityUpdatesUntil = Date().addingTimeInterval(1.0)
        suppressTimerRecomputeUntil = Date().addingTimeInterval(1.75)

        beginMindfulSession(at: start)
        beginPrayerSegment(at: start)
        scheduleCompletionAlert(at: end)

        PrayerTimerActivityController.shared.start(
            sessionName: kind.sessionName,
            totalSeconds: storedTotalSeconds,
            remainingSeconds: remainingSeconds,
            isPaused: false
        )

        updateTickerSubscription()
    }

    func togglePause() {
        guard isRunning else { return }
        isPaused.toggle()
        storedPaused = isPaused

        if isPaused {
            let now = Date().timeIntervalSince1970
            let newRemain = Int(max(0, storedEndDate - now))
            remainingSeconds = newRemain
            storedRemainingWhenPaused = newRemain
            cancelNotification()
            cancelAlarm()
            endMindfulSession(at: Date())
            endPrayerSegment(at: Date())
        } else {
            beginMindfulSession(at: Date())
            beginPrayerSegment(at: Date())
            let newEnd = Date().addingTimeInterval(TimeInterval(remainingSeconds))
            storedEndDate = newEnd.timeIntervalSince1970
            liveEndDate = storedEndDate
            suppressTimerActivityUpdatesUntil = Date().addingTimeInterval(1.0)
            suppressTimerRecomputeUntil = Date().addingTimeInterval(1.75)
            storedRemainingWhenPaused = 0
            scheduleCompletionAlert(at: Date(timeIntervalSince1970: storedEndDate))
        }
        PrayerTimerActivityController.shared.update(
            remainingSeconds: remainingSeconds,
            totalSeconds: storedTotalSeconds,
            isPaused: isPaused
        )
    }

    func addOne() { addMinutes(1) }
    func addFive() { addMinutes(5) }

    func addMinutes(_ minutes: Int) {
        guard isRunning else { return }
        let delta = max(1, minutes) * 60
        if isPaused {
            remainingSeconds += delta
            storedRemainingWhenPaused += delta
            storedTotalSeconds += delta
            totalSeconds = storedTotalSeconds
            PrayerTimerActivityController.shared.update(
                remainingSeconds: remainingSeconds,
                totalSeconds: storedTotalSeconds,
                isPaused: isPaused
            )
        } else {
            storedEndDate += TimeInterval(delta)
            storedTotalSeconds += delta
            totalSeconds = storedTotalSeconds

            let newRemaining = Int(max(0, storedEndDate - Date().timeIntervalSince1970))
            remainingSeconds = newRemaining

            liveEndDate = storedEndDate
            suppressTimerActivityUpdatesUntil = Date().addingTimeInterval(1.0)
            suppressTimerRecomputeUntil = Date().addingTimeInterval(1.75)

            scheduleCompletionAlert(at: Date(timeIntervalSince1970: storedEndDate))
            PrayerTimerActivityController.shared.update(
                remainingSeconds: remainingSeconds,
                totalSeconds: storedTotalSeconds,
                isPaused: isPaused
            )
        }
    }

    /// Ends the session. With `allowsUndo`, the session can be brought back for a few seconds.
    func stop(allowsUndo: Bool = true) {
        let wasRunning = isRunning
        let currentRemaining = isPaused
            ? remainingSeconds
            : Int(max(0, storedEndDate - Date().timeIntervalSince1970))

        endMindfulSession(at: Date())
        endPrayerSegment(at: Date())
        let stopped = StoppedSession(
            remainingSeconds: currentRemaining,
            totalSeconds: storedTotalSeconds,
            wasPaused: isPaused,
            sessionSeconds: prayerSessionSeconds
        )
        finishPrayerSession()

        resetTimerState()
        cancelNotification()
        cancelAlarm()
        stopFinishAlerts()
        PrayerTimerActivityController.shared.cancel()
        showFinishedAlert = false
        updateTickerSubscription()

        if allowsUndo && wasRunning && stopped.remainingSeconds > 0 {
            offerUndo(stopped)
        } else {
            clearUndo()
        }
    }

    /// Restores the session that was just stopped, paused or running as it was.
    func undoStop() {
        guard let stopped = undoableStop else { return }
        clearUndo()

        let now = Date()
        remainingSeconds = stopped.remainingSeconds
        totalSeconds = stopped.totalSeconds
        isRunning = true
        isPaused = stopped.wasPaused

        storedRunning = true
        storedPaused = stopped.wasPaused
        storedTotalSeconds = stopped.totalSeconds
        storedStartDate = now.timeIntervalSince1970
        storedEndDate = now.addingTimeInterval(TimeInterval(stopped.remainingSeconds)).timeIntervalSince1970
        storedRemainingWhenPaused = stopped.wasPaused ? stopped.remainingSeconds : 0
        prayerSessionSeconds = stopped.sessionSeconds

        if !stopped.wasPaused {
            liveEndDate = storedEndDate
            suppressTimerActivityUpdatesUntil = now.addingTimeInterval(1.0)
            suppressTimerRecomputeUntil = now.addingTimeInterval(1.75)
            beginMindfulSession(at: now)
            beginPrayerSegment(at: now)
            scheduleCompletionAlert(at: Date(timeIntervalSince1970: storedEndDate))
        }

        PrayerTimerActivityController.shared.start(
            sessionName: kind.sessionName,
            totalSeconds: stopped.totalSeconds,
            remainingSeconds: stopped.remainingSeconds,
            isPaused: stopped.wasPaused
        )
        updateTickerSubscription()
    }

    private func offerUndo(_ stopped: StoppedSession) {
        undoExpiryTask?.cancel()
        undoableStop = stopped
        undoExpiryTask = Task { [weak self] in
            try? await Task.sleep(for: Self.undoWindow)
            guard !Task.isCancelled else { return }
            self?.undoableStop = nil
        }
    }

    private func clearUndo() {
        undoExpiryTask?.cancel()
        undoExpiryTask = nil
        undoableStop = nil
    }

    // MARK: - Internal ticking

    private func updateTickerSubscription() {
        let shouldRun = isRunning
        if shouldRun {
            if tickerTask == nil {
                // Once a second; `tick()` recomputes from the end date, so sleep drift doesn't add up.
                tickerTask = Task { [weak self] in
                    while !Task.isCancelled {
                        try? await Task.sleep(for: .seconds(1))
                        guard !Task.isCancelled, let self else { return }
                        self.tick()
                    }
                }
            }
        } else {
            tickerTask?.cancel()
            tickerTask = nil
        }
    }

    private func tick() {
        guard isRunning, !isPaused else { return }

        let now = Date().timeIntervalSince1970

        if Date() < suppressTimerRecomputeUntil {
            remainingSeconds = max(0, remainingSeconds - 1)
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
            if remaining == 0 {
                handleTimerFinished()
            }
        }

        if Date() >= suppressTimerActivityUpdatesUntil {
            PrayerTimerActivityController.shared.update(
                remainingSeconds: remainingSeconds,
                totalSeconds: storedTotalSeconds,
                isPaused: isPaused
            )
        }
    }

    // MARK: - Finish handling

    private func handleTimerFinished() {
        if !isRunning { return }

        // The timer may finish while the app is suspended; the session ends at the
        // scheduled end date, not when the app next runs.
        let scheduledEnd = storedEndDate > 0
            ? Date(timeIntervalSince1970: storedEndDate)
            : Date()
        endMindfulSession(at: min(Date(), scheduledEnd))
        endPrayerSegment(at: min(Date(), scheduledEnd))
        finishPrayerSession()
        clearUndo()

        let completedMinutes = storedTotalSeconds / 60
        cancelNotification()
        resetTimerState()
        // "Pray for X minutes" challenges count prayer sessions only.
        if kind == .prayer {
            TodayChallengeStore.shared.recordPrayerTimerCompletion(minutes: completedMinutes)
        }
        PrayerTimerActivityController.shared.finish()
        showFinishedAlert = true
        startFinishAlerts()
        updateTickerSubscription()
    }

    func stopFinishAlerts() {
        finishHapticTimer?.invalidate()
        finishHapticTimer = nil
    }

    private func startFinishAlerts() {
        let soundID = selectedFinishSoundID
        finishHapticTimer?.invalidate()
        finishHapticTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
            AudioServicesPlaySystemSound(soundID)
            AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
        }
        AudioServicesPlaySystemSound(soundID)
        AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
    }

    // MARK: - Prayer stats

    // Like mindful sessions, prayer stats count only time spent counting down, but they
    // are kept whether or not Apple Health is connected.
    private func beginPrayerSegment(at date: Date) {
        prayerSegmentStartDate = date.timeIntervalSince1970
    }

    private func endPrayerSegment(at endDate: Date) {
        defer { prayerSegmentStartDate = 0 }
        guard prayerSegmentStartDate > 0 else { return }
        let startDate = Date(timeIntervalSince1970: prayerSegmentStartDate)
        guard endDate > startDate else { return }
        PrayerStatsStore.store(for: kind).record(from: startDate, to: endDate)
        prayerSessionSeconds += Int(endDate.timeIntervalSince(startDate).rounded())
    }

    private func finishPrayerSession() {
        PrayerStatsStore.store(for: kind).recordSessionEnded(seconds: prayerSessionSeconds)
        prayerSessionSeconds = 0
    }

    // MARK: - HealthKit mindful logging

    // Timer activity, prayer or study, is one source of the shared mindful session.
    private func beginMindfulSession(at date: Date) {
        MindfulMinutesTracker.shared.start(.prayerTimer, at: date)
    }

    private func endMindfulSession(at endDate: Date) {
        MindfulMinutesTracker.shared.stop(.prayerTimer, at: endDate)
    }

    // MARK: - Notifications

    private static let notificationID = "PrayerStudyTimerFinished"

    private func scheduleNotification(at date: Date) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.notificationID])

        let content = UNMutableNotificationContent()
        content.title = kind.finishedTitle
        content.body = kind.finishedMessage
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, date.timeIntervalSinceNow), repeats: false)
        let request = UNNotificationRequest(identifier: Self.notificationID, content: content, trigger: trigger)
        center.add(request, withCompletionHandler: nil)
    }

    private func scheduleCompletionAlert(at date: Date) {
        let token = UUID()
        completionSchedulingToken = token

        // Keep the notification in place until AlarmKit scheduling succeeds so
        // denied authorization and older OS versions still get an alert.
        scheduleNotification(at: date)

        Task {
            let scheduledWithAlarmKit = await PrayerTimerAlarmScheduler.schedule(at: date, title: kind.finishedTitle)
            guard completionSchedulingToken == token else { return }
            if scheduledWithAlarmKit {
                cancelNotification()
            }
        }
    }

    private func cancelNotification() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.notificationID])
    }

    private func cancelAlarm() {
        completionSchedulingToken = UUID()
        PrayerTimerAlarmScheduler.cancel()
    }

    private func requestNotificationsIfNeeded() async {
        guard !didRequestNotifications else { return }
        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        didRequestNotifications = true
    }


    // MARK: - Reset

    private func resetTimerState() {
        storedRunning = false
        storedPaused = false
        storedEndDate = 0
        storedRemainingWhenPaused = 0
        storedTotalSeconds = 0
        storedStartDate = 0

        isRunning = false
        isPaused = false
        remainingSeconds = 0
        totalSeconds = 0

        liveEndDate = 0
    }
}
