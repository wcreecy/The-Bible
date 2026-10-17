import Foundation
import Observation
import CloudKit
import SwiftUI
import OSLog

// MARK: - Which SwiftData store the app ended up using at launch

/// The SwiftData store created at launch. CloudKit is preferred; the other modes are
/// fallbacks used only when the store before them fails to open.
enum PersistenceStoreMode {
    /// Notes, favorites, and bookmarks are saved and sync through iCloud.
    case cloudKit
    /// Saved on this device only; nothing syncs.
    case localOnly
    /// Nothing is written to disk; all changes are lost when the app quits.
    case inMemory
}

extension EnvironmentValues {
    @Entry var persistenceStoreMode: PersistenceStoreMode = .cloudKit
}

// MARK: - Simple CloudKit manager for availability and basic access
@MainActor
@Observable
public final class CloudKitManager {
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

    public private(set) var accountState: AccountState = .unknown
    public private(set) var userRecordID: CKRecord.ID?

    private let container: CKContainer
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "The Bible",
        category: "CloudKit"
    )

    // Throttling/coalescing
    @ObservationIgnored private var lastRefreshAt: Date?
    private let minRefreshInterval: TimeInterval = 60 // seconds
    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    @ObservationIgnored private var accountChangedObserver: NSObjectProtocol?

    public init(containerIdentifier: String) {
        self.container = CKContainer(identifier: containerIdentifier)

        let bundleID = Bundle.main.bundleIdentifier ?? "<unknown bundle id>"
        // Deprecated receipt URL removed; we log a coarse hint here and the precise one asynchronously.
        let isDebug = (ProcessInfo.processInfo.environment["CONFIGURATION"] ?? "").lowercased().contains("debug")
        let envHint = isDebug ? "Development (Debug/AdHoc)" : "Production (TestFlight/App Store)"
        print("🔎 CloudKit diagnostics:")
        print("   • Container: \(containerIdentifier)")
        print("   • Bundle ID: \(bundleID)")
        print("   • Environment hint: \(envHint)")

        // Refresh reactively when the account changes (sign in/out, switch accounts)
        accountChangedObserver = NotificationCenter.default.addObserver(
            forName: .CKAccountChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Hop onto the main actor explicitly before touching main-actor isolated state.
            Task { @MainActor [weak self] in
                guard let self else { return }
                // Invalidate throttling so we fetch immediately
                self.lastRefreshAt = nil
                await self.refresh(force: true)
            }
        }
    }

    deinit {
        if let obs = accountChangedObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }

    public func prepare() async {
        await refresh(force: true)
    }

    public func refresh() async {
        await refresh(force: false)
    }

    // MARK: - Throttled/forced refresh

    private func refresh(force: Bool) async {
        // Coalesce if a refresh is already running
        if let task = refreshTask {
            await task.value
            return
        }

        // Throttle unless forced
        if !force, let last = lastRefreshAt, Date().timeIntervalSince(last) < minRefreshInterval {
            return
        }

        let task = Task { [weak self] in
            guard let self else { return }
            await self.refreshAccountStatus()
            await self.fetchUserRecordIDIfAvailable()
            self.lastRefreshAt = Date()
        }
        refreshTask = task
        await task.value
        refreshTask = nil
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
            logger.notice("CloudKit account status changed to \(self.accountState.description, privacy: .public).")
        } catch {
            accountState = .couldNotDetermine
            let nsError = error as NSError
            logger.error("CloudKit account status lookup failed; domain=\(nsError.domain, privacy: .public), code=\(nsError.code, privacy: .public).")
        }
    }

    private func fetchUserRecordIDIfAvailable() async {
        guard accountState == .available else {
            userRecordID = nil
            logger.debug("Skipped CloudKit user record lookup; account state=\(self.accountState.description, privacy: .public).")
            return
        }
        do {
            let id = try await container.userRecordID()
            userRecordID = id
            logger.debug("Fetched the CloudKit user record identifier.")
        } catch {
            userRecordID = nil
            let nsError = error as NSError
            logger.error("CloudKit user record lookup failed; domain=\(nsError.domain, privacy: .public), code=\(nsError.code, privacy: .public).")
        }
    }

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
