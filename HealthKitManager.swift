import Foundation
import HealthKit

final class HealthKitManager {
    static let shared = HealthKitManager()
    private let healthStore: HKHealthStore? = HKHealthStore.isHealthDataAvailable() ? HKHealthStore() : nil

    private static let mindfulMinutesEnabledKey = "healthKitMindfulMinutesEnabled"

    private init() {}

    var isMindfulMinutesEnabled: Bool {
        UserDefaults.standard.bool(forKey: Self.mindfulMinutesEnabledKey)
    }

    private var mindfulType: HKCategoryType? {
        HKObjectType.categoryType(forIdentifier: .mindfulSession)
    }

    func isAvailable() -> Bool {
        return healthStore != nil && mindfulType != nil
    }

    func mindfulMinutesAuthorizationStatus() -> HKAuthorizationStatus? {
        guard let healthStore, let mindfulType else { return nil }
        return healthStore.authorizationStatus(for: mindfulType)
    }

    // Request authorization if not already determined. Calls completion with success flag.
    func requestAuthorizationIfNeeded(completion: ((Bool) -> Void)? = nil) {
        guard isMindfulMinutesEnabled, let healthStore, let mindfulType else {
            completion?(false)
            return
        }
        let status = healthStore.authorizationStatus(for: mindfulType)
        switch status {
        case .notDetermined:
            healthStore.requestAuthorization(toShare: [mindfulType], read: []) { success, _ in
                DispatchQueue.main.async { completion?(success) }
            }
        case .sharingDenied:
            completion?(false)
        case .sharingAuthorized:
            completion?(true)
        @unknown default:
            completion?(false)
        }
    }

    // Save a mindful session from start to end. If authorization isn't granted, this is a no-op.
    func saveMindfulSession(start: Date, end: Date, completion: ((Bool) -> Void)? = nil) {
        guard isMindfulMinutesEnabled,
              let healthStore,
              let mindfulType,
              healthStore.authorizationStatus(for: mindfulType) == .sharingAuthorized else {
            completion?(false)
            return
        }
        // Ensure end is after start
        guard end > start else {
            completion?(false)
            return
        }

        let sample = HKCategorySample(
            type: mindfulType,
            value: HKCategoryValue.notApplicable.rawValue,
            start: start,
            end: end
        )
        healthStore.save(sample) { success, _ in
            DispatchQueue.main.async { completion?(success) }
        }
    }
}

enum MindfulMinutesSource: Hashable {
    case prayerTimer
    case bibleTab
    case notesTab
    case game
}

/// Tracks the boundaries of a combined mindful session without any HealthKit side effects.
struct MindfulMinutesSessionCoordinator {
    private var activeSources: Set<MindfulMinutesSource> = []
    private var sessionStart: Date?

    static func shouldTrack(isEnabled: Bool, isAuthorized: Bool) -> Bool {
        isEnabled && isAuthorized
    }

    mutating func start(_ source: MindfulMinutesSource, at date: Date) {
        guard activeSources.insert(source).inserted, sessionStart == nil else { return }
        sessionStart = date
    }

    mutating func stop(_ source: MindfulMinutesSource, at date: Date) -> DateInterval? {
        guard activeSources.remove(source) != nil,
              activeSources.isEmpty,
              let sessionStart else {
            return nil
        }

        self.sessionStart = nil
        guard date > sessionStart else { return nil }
        return DateInterval(start: sessionStart, end: date)
    }
}

/// Combines qualifying activities into one Health mindful session.
/// Overlapping activities remain a single session so time is never counted twice.
@MainActor
final class MindfulMinutesTracker {

    static let shared = MindfulMinutesTracker()

    private var coordinator = MindfulMinutesSessionCoordinator()

    private init() {}

    func start(_ source: MindfulMinutesSource, at date: Date = Date()) {
        let isAuthorized = HealthKitManager.shared.mindfulMinutesAuthorizationStatus() == .sharingAuthorized
        guard MindfulMinutesSessionCoordinator.shouldTrack(
            isEnabled: HealthKitManager.shared.isMindfulMinutesEnabled,
            isAuthorized: isAuthorized
        ) else {
            return
        }
        coordinator.start(source, at: date)
    }

    func stop(_ source: MindfulMinutesSource, at date: Date = Date()) {
        guard let session = coordinator.stop(source, at: date) else { return }
        HealthKitManager.shared.saveMindfulSession(start: session.start, end: session.end)
    }
}
