import Foundation
import Combine
import UserNotifications
import ActivityKit
import AudioToolbox
import SwiftUI

@MainActor
final class PrayerTimerController: ObservableObject {

    // MARK: - Published UI State

    @Published private(set) var isRunning: Bool = false
    @Published private(set) var isPaused: Bool = false
    @Published private(set) var remainingSeconds: Int = 0
    @Published private(set) var totalSeconds: Int = 0
    @Published var showFinishedAlert: Bool = false

    // MARK: - Persistence (UserDefaults / AppStorage keys)

    // Keep the same keys HomeView used so behavior remains compatible across launches
    @AppStorage("prayerTimerEndDate") private var storedEndDate: Double = 0
    @AppStorage("prayerTimerRunning") private var storedRunning: Bool = false
    @AppStorage("prayerTimerPaused") private var storedPaused: Bool = false
    @AppStorage("prayerTimerRemainingWhenPaused") private var storedRemainingWhenPaused: Int = 0
    @AppStorage("prayerTimerTotalSeconds") private var storedTotalSeconds: Int = 0
    @AppStorage("prayerTimerStartDate") private var storedStartDate: Double = 0
    @AppStorage("mindfulSessionStartDate") private var mindfulStartDate: Double = 0
    @AppStorage("timerSoundSelection") private var timerSoundSelection: String = TimerSound.default.rawValue
    @AppStorage("didRequestNotifications") private var didRequestNotifications: Bool = false
    @AppStorage("healthKitPrompted") private var healthKitPrompted: Bool = false

    // One-shot token to ignore stale pending actions
    @AppStorage("prayerTimerLastActionToken") private var lastActionToken: String = ""

    // MARK: - External collaborators

    private var sharedDefaults: UserDefaults? { UserDefaults(suiteName: "group.bible.app") }

    // MARK: - Internal ticking

    private var tickerCancellable: AnyCancellable?

    // Suppression windows to avoid recompute churn right after adjustments
    private var suppressTimerActivityUpdatesUntil: Date = .distantPast
    private var suppressTimerRecomputeUntil: Date = .distantPast

    // Authoritative in-memory end date used briefly after adjustments to avoid @AppStorage staleness
    private var liveEndDate: TimeInterval = 0

    // Finish sound/haptic loop
    private var finishHapticTimer: Timer?

    // MARK: - Derived

    private var selectedFinishSoundID: SystemSoundID {
        (TimerSound(rawValue: timerSoundSelection) ?? .default).systemSoundID
    }

    // MARK: - Public lifecycle

    init() {
        // Restore persisted state
        isRunning = storedRunning
        isPaused = storedPaused
        totalSeconds = storedTotalSeconds

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
        updateTickerSubscription()
    }

    func onAppear() {
        // placeholder for future needs
    }

    func onSceneBecameActive() {
        // Re-evaluate remaining and pending actions
        _ = handlePendingActionIfAny()
        if isRunning && !isPaused && storedEndDate > 0 {
            let remaining = Int(max(0, storedEndDate - Date().timeIntervalSince1970))
            remainingSeconds = remaining
            if remaining == 0 {
                handleTimerFinished()
            }
        }
        startMindfulLoggingIfNeeded()
        updateTickerSubscription()
    }

    func onSceneBecameInactiveOrBackground() {
        if !isRunning {
            stopMindfulLogging()
        }
        updateTickerSubscription()
    }

    // MARK: - Public control API

    func start(minutes: Int) {
        Task { await requestNotificationsIfNeeded() }
        if HealthKitManager.shared.isAvailable() && !healthKitPrompted {
            Task { await requestHealthKitIfNeeded() }
        }

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

        startMindfulLoggingIfNeeded()
        scheduleNotification(at: end)

        // Ensure Stopwatch Live Activity is not active
        StopwatchActivityController.shared.cancel()
        PrayerTimerActivityController.shared.start(
            sessionName: "Prayer/Study",
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
        } else {
            let newEnd = Date().addingTimeInterval(TimeInterval(remainingSeconds))
            storedEndDate = newEnd.timeIntervalSince1970
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

    func addOne() { addMinutes(1) }
    func addFive() { addMinutes(5) }
    func addTen() { addMinutes(10) }

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

            scheduleNotification(at: Date(timeIntervalSince1970: storedEndDate))
            PrayerTimerActivityController.shared.update(
                remainingSeconds: remainingSeconds,
                totalSeconds: storedTotalSeconds,
                isPaused: isPaused
            )
        }
    }

    func stop() {
        if UIApplication.shared.applicationState != .active {
            stopMindfulLogging()
        }
        resetTimerState()
        cancelNotification()
        stopFinishAlerts()
        PrayerTimerActivityController.shared.cancel()
        showFinishedAlert = false
        updateTickerSubscription()
    }

    // MARK: - Internal ticking

    private func updateTickerSubscription() {
        let shouldRun = isRunning
        if shouldRun {
            if tickerCancellable == nil {
                tickerCancellable = Timer.publish(every: 1, on: .main, in: .common)
                    .autoconnect()
                    .sink { [weak self] _ in
                        guard let self else { return }
                        self.tick()
                    }
            }
        } else {
            tickerCancellable?.cancel()
            tickerCancellable = nil
        }
    }

    private func tick() {
        if handlePendingActionIfAny() {
            return
        }
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
        if UIApplication.shared.applicationState != .active {
            stopMindfulLogging()
        }
        cancelNotification()
        resetTimerState()
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

    // MARK: - Pending action (Live Activity button taps from widgets/Dynamic Island)

    // Returns true if consumed an action
    @discardableResult
    func handlePendingActionIfAny() -> Bool {
        guard let shared = sharedDefaults else { return false }
        guard let action = shared.string(forKey: "prayerTimerPendingAction") else { return false }

        let token = shared.string(forKey: "prayerTimerActionToken") ?? ""
        if !token.isEmpty && token == lastActionToken {
            shared.removeObject(forKey: "prayerTimerPendingAction")
            shared.removeObject(forKey: "prayerTimerActionToken")
            return false
        }

        shared.removeObject(forKey: "prayerTimerPendingAction")
        shared.removeObject(forKey: "prayerTimerActionToken")

        switch action {
        case "togglePause":
            if isRunning { togglePause() }
        case "add5":
            if isRunning { addMinutes(5) }
        case "stop":
            if isRunning { stop() }
        default:
            break
        }
        if !token.isEmpty {
            lastActionToken = token
        }
        suppressTimerActivityUpdatesUntil = .distantPast
        return true
    }

    // MARK: - HealthKit mindful logging

    private func startMindfulLoggingIfNeeded() {
        guard HealthKitManager.shared.isAvailable() else { return }
        if mindfulStartDate == 0 {
            mindfulStartDate = Date().timeIntervalSince1970
        }
    }

    private func stopMindfulLogging() {
        guard HealthKitManager.shared.isAvailable() else { return }
        if mindfulStartDate > 0 {
            let startDate = Date(timeIntervalSince1970: mindfulStartDate)
            let endDate = Date()
            if endDate > startDate {
                HealthKitManager.shared.saveMindfulSession(start: startDate, end: endDate, completion: nil)
            }
            mindfulStartDate = 0
        }
    }

    // MARK: - Notifications

    private static let notificationID = "PrayerStudyTimerFinished"
    private static let notificationTitle = "Prayer/Study Finished"
    private static let notificationBody = "Your prayer/study timer has completed."

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

    private func requestNotificationsIfNeeded() async {
        guard !didRequestNotifications else { return }
        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        didRequestNotifications = true
    }

    private func requestHealthKitIfNeeded() async {
        guard HealthKitManager.shared.isAvailable() && !healthKitPrompted else { return }
        await withCheckedContinuation { continuation in
            HealthKitManager.shared.requestAuthorizationIfNeeded { _ in
                Task { @MainActor in
                    self.healthKitPrompted = true
                }
                continuation.resume()
            }
        }
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

