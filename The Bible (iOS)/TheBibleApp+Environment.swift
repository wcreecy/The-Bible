import Foundation
#if USE_STOREKIT_DIAGNOSTICS
import StoreKit
#endif

// MARK: - Store environment helpers
extension The_Bible__iOS_App {
    // Synchronous coarse fallback for early logging (no StoreKit)
    static func buildEnvHintFallback() -> String {
        #if DEBUG
        return "Development (Debug/AdHoc)"
        #else
        return "Production (TestFlight/App Store)"
        #endif
    }

    // Async, preferred detection using StoreKit (compiled only if enabled)
    #if USE_STOREKIT_DIAGNOSTICS
    static func computeStoreEnvironmentHint() async -> String? {
        do {
            let result = try await AppTransaction.shared
            switch result {
            case .verified(_):
                return "Production (TestFlight/App Store)"
            case .unverified(_, _):
                return "Development (Debug/AdHoc)"
            }
        } catch {
            return buildEnvHintFallback()
        }
    }
    #else
    // Stub so callers can compile even when diagnostics are disabled.
    static func computeStoreEnvironmentHint() async -> String? { nil }
    #endif
}
