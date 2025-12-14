import Foundation
import HealthKit

final class HealthKitManager {
    static let shared = HealthKitManager()
    private let healthStore: HKHealthStore? = HKHealthStore.isHealthDataAvailable() ? HKHealthStore() : nil

    private init() {}

    private var mindfulType: HKCategoryType? {
        HKObjectType.categoryType(forIdentifier: .mindfulSession)
    }

    func isAvailable() -> Bool {
        return healthStore != nil && mindfulType != nil
    }

    // Request authorization if not already determined. Calls completion with success flag.
    func requestAuthorizationIfNeeded(completion: ((Bool) -> Void)? = nil) {
        guard let healthStore, let mindfulType else {
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
        guard let healthStore, let mindfulType else {
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
