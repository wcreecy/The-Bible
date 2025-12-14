import Foundation
import StoreKit

// MARK: - Store environment helpers (non-deprecated)
extension The_Bible__iOS_App {
    // Synchronous coarse fallback for early logging
    static func buildEnvHintFallback() -> String {
        #if DEBUG
        return "Development (Debug/AdHoc)"
        #else
        return "Production (TestFlight/App Store)"
        #endif
    }

    // Async, preferred detection using StoreKit on iOS 15+
    static func computeStoreEnvironmentHint() async -> String? {
        do {
            // On iOS 15+, AppTransaction.shared returns VerificationResult<AppTransaction>
            let result = try await AppTransaction.shared

            switch result {
            case .verified(_):
                // Verified App Store transaction => Production/TestFlight
                return "Production (TestFlight/App Store)"
            case .unverified(_, _):
                // Present but failed verification; treat as development or unknown
                return "Development (Debug/AdHoc)"
            }
        } catch {
            // If StoreKit fails, return a conservative hint
            return buildEnvHintFallback()
        }
    }
}
