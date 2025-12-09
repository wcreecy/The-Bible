import Foundation
import Combine
import SwiftUI

@MainActor
final class StopwatchController: ObservableObject {

    // MARK: - Published UI State
    @Published private(set) var isRunning: Bool = false
    @Published private(set) var elapsed: Int = 0

    // MARK: - Persistence (UserDefaults / AppStorage keys)
    @AppStorage("stopwatchRunning") private var storedRunning: Bool = false
    @AppStorage("stopwatchStartDate") private var storedStartDate: Double = 0
    @AppStorage("stopwatchAccumulated") private var storedAccumulated: Int = 0

    // Mindful/Health
    @AppStorage("mindfulSessionStartDate") private var mindfulStartDate: Double = 0
    @AppStorage("healthKitPrompted") private var healthKitPrompted: Bool = false

    // Pending action dedupe
    @AppStorage("stopwatchLastActionToken") private var lastActionToken: String = ""

    // MARK: - External collaborators
    private var sharedDefaults: UserDefaults? { UserDefaults(suiteName: "group.bible.app") }

    // MARK: - Internal ticking
    private var tickerCancellable: AnyCancellable?

    // MARK: - Init / Restore
    init() {
        // Restore persisted state
        isRunning = storedRunning
        if storedRunning {
            let now = Date().timeIntervalSince1970
            let base = storedAccumulated + Int(max(0, now - storedStartDate))
            elapsed = base
        } else {
            elapsed = storedAccumulated
        }
        updateTickerSubscription()
    }

    // MARK: - Lifecycle hooks
    func onAppear() {
        updateTickerSubscription()
    }

    func onSceneBecameActive() {
        // Consume any pending action and recompute elapsed from persisted values
        _ = handlePendingActionIfAny()
        if isRunning {
            let now = Date().timeIntervalSince1970
            let base = storedAccumulated + Int(max(0, now - storedStartDate))
            elapsed = base
        } else {
            elapsed = storedAccumulated
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

    // MARK: - Control API
    func start() {
        if HealthKitManager.shared.isAvailable() && !healthKitPrompted {
            requestHealthKitIfNeeded()
        }
        let now = Date().timeIntervalSince1970
        if storedStartDate == 0 {
            storedStartDate = now
        }
        storedRunning = true
        isRunning = true

        // Ensure Prayer Timer activity is not active
        PrayerTimerActivityController.shared.cancel()

        startMindfulLoggingIfNeeded()
        StopwatchActivityController.shared.start(sessionName: "Stopwatch", initialElapsed: elapsed)

        updateTickerSubscription()
    }

    func pause() {
        guard isRunning else { return }
        let now = Date().timeIntervalSince1970
        if storedStartDate > 0 {
            let delta = Int(max(0, now - storedStartDate))
            storedAccumulated += delta
            storedStartDate = 0
        }
        storedRunning = false
        isRunning = false

        // Update Live Activity to paused state
        StopwatchActivityController.shared.update(elapsed: elapsed, isRunning: false)

        updateTickerSubscription()
    }

    func stop() {
        if UIApplication.shared.applicationState != .active {
            stopMindfulLogging()
        }
        storedRunning = false
        isRunning = false
        storedStartDate = 0
        storedAccumulated = 0
        elapsed = 0

        StopwatchActivityController.shared.finish(finalStatus: "Stopped")

        updateTickerSubscription()
    }

    // MARK: - Pending action handling (from widgets/Dynamic Island)
    // Returns true if consumed an action
    @discardableResult
    func handlePendingActionIfAny() -> Bool {
        guard let shared = sharedDefaults else { return false }
        guard let action = shared.string(forKey: "stopwatchPendingAction") else { return false }

        let token = shared.string(forKey: "stopwatchActionToken") ?? ""
        if !token.isEmpty && token == lastActionToken {
            shared.removeObject(forKey: "stopwatchPendingAction")
            shared.removeObject(forKey: "stopwatchActionToken")
            return false
        }

        shared.removeObject(forKey: "stopwatchPendingAction")
        shared.removeObject(forKey: "stopwatchActionToken")

        switch action {
        case "togglePause":
            if isRunning { pause() } else { start() }
        case "stop":
            if isRunning || elapsed > 0 { stop() }
        default:
            break
        }
        if !token.isEmpty {
            lastActionToken = token
        }
        return true
    }

    // MARK: - Ticker
    private func updateTickerSubscription() {
        if isRunning {
            if tickerCancellable == nil {
                tickerCancellable = Timer.publish(every: 1, on: .main, in: .common)
                    .autoconnect()
                    .sink { [weak self] _ in
                        self?.tick()
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
        guard isRunning else { return }
        let now = Date().timeIntervalSince1970
        let base = storedAccumulated + Int(max(0, now - storedStartDate))
        elapsed = base
        StopwatchActivityController.shared.update(elapsed: elapsed, isRunning: true)
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

    private func requestHealthKitIfNeeded() {
        guard HealthKitManager.shared.isAvailable() && !healthKitPrompted else { return }
        HealthKitManager.shared.requestAuthorizationIfNeeded { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.healthKitPrompted = true
            }
        }
    }
}

