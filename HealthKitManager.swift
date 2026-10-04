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

        let sample = HKCategorySample(type: mindfulType, value: 0, start: start, end: end)
        healthStore.save(sample) { success, _ in
            DispatchQueue.main.async { completion?(success) }
        }
    }
}
