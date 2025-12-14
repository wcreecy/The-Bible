import Foundation
import Combine
import CloudKit

// MARK: - Simple CloudKit manager for availability and basic access
@MainActor
public final class CloudKitManager: ObservableObject {
    public enum AccountState: CustomStringConvertible {
        case unknown
        case available
        case noAccount
        case restricted
        case couldNotDetermine

        public var description: String {
            switch self {
            case .unknown: return "unknown"
            case .available: return "available"
            case .noAccount: return "noAccount"
            case .restricted: return "restricted"
            case .couldNotDetermine: return "couldNotDetermine"
            }
        }
    }

    @Published public private(set) var accountState: AccountState = .unknown
    @Published public private(set) var userRecordID: CKRecord.ID?

    private let container: CKContainer
    private let privateDB: CKDatabase
    private let sharedDB: CKDatabase
    private let publicDB: CKDatabase

    public init(containerIdentifier: String) {
        self.container = CKContainer(identifier: containerIdentifier)
        self.privateDB = container.privateCloudDatabase
        self.sharedDB = container.sharedCloudDatabase
        self.publicDB = container.publicCloudDatabase

        let bundleID = Bundle.main.bundleIdentifier ?? "<unknown bundle id>"
        // Deprecated receipt URL removed; we log a coarse hint here and the precise one asynchronously.
        let isDebug = (ProcessInfo.processInfo.environment["CONFIGURATION"] ?? "").lowercased().contains("debug")
        let envHint = isDebug ? "Development (Debug/AdHoc)" : "Production (TestFlight/App Store)"
        print("🔎 CloudKit diagnostics:")
        print("   • Container: \(containerIdentifier)")
        print("   • Bundle ID: \(bundleID)")
        print("   • Environment hint: \(envHint)")
    }

    public func prepare() async {
        await refreshAccountStatus()
        await fetchUserRecordIDIfAvailable()
    }

    public func refresh() async {
        print("ℹ️ CloudKitManager.refresh() called")
        await refreshAccountStatus()
        await fetchUserRecordIDIfAvailable()
    }

    public func flushPending() async {
        print("ℹ️ CloudKitManager.flushPending() called")
    }

    private func refreshAccountStatus() async {
        do {
            let status = try await container.accountStatus()
            switch status {
            case .available:
                accountState = .available
            case .noAccount:
                accountState = .noAccount
            case .restricted:
                accountState = .restricted
            case .couldNotDetermine, .temporarilyUnavailable:
                accountState = .couldNotDetermine
            @unknown default:
                accountState = .couldNotDetermine
            }
            print("🔎 CloudKit account status: \(accountState.description)")
        } catch {
            accountState = .couldNotDetermine
            print("❌ Failed to fetch CloudKit account status: \(error.localizedDescription)")
        }
    }

    private func fetchUserRecordIDIfAvailable() async {
        guard accountState == .available else {
            userRecordID = nil
            print("ℹ️ Skipping userRecordID fetch; account state = \(accountState.description)")
            return
        }
        do {
            let id = try await container.userRecordID()
            userRecordID = id
            print("✅ Fetched CloudKit userRecordID: \(id.recordName)")
        } catch {
            userRecordID = nil
            print("❌ Failed to fetch userRecordID: \(error.localizedDescription)")
        }
    }

    // Expose databases if needed by callers
    public func privateDatabase() -> CKDatabase { privateDB }
    public func sharedDatabase() -> CKDatabase { sharedDB }
    public func publicDatabase() -> CKDatabase { publicDB }

    public static func logEntitlementHints(containerIdentifier: String) {
        // We no longer use appStoreReceiptURL here. Provide general build hints.
        let bundleID = Bundle.main.bundleIdentifier ?? "<unknown>"
        let appIDPrefix = Bundle.main.object(forInfoDictionaryKey: "AppIdentifierPrefix") as? String ?? "<unknown>"
        let cfg = ProcessInfo.processInfo.environment["CONFIGURATION"] ?? "<unknown>"
        print("🔎 Entitlement hints:")
        print("   • Bundle ID: \(bundleID)")
        print("   • AppIdentifierPrefix (TeamID.): \(appIDPrefix)")
        print("   • Build configuration: \(cfg)")
        print("   • Expect CloudKit container entitlement for: \(containerIdentifier)")
        print("   • Ensure iCloud capability with CloudKit is ON and container is checked for this target/configuration.")
    }
}
