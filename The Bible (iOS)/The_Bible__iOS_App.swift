//
//  The_Bible__iOS_App.swift
//  The Bible (iOS)
//
//  Created by William Creecy on 11/7/25.
//

import SwiftUI
import SwiftData
import UIKit
import UserNotifications
internal import CloudKit
import Combine

@main
struct The_Bible__iOS_App: App {
    @Environment(\.scenePhase) private var scenePhase

    // MARK: - SwiftData (CloudKit-backed with local fallback) + diagnostics
    var sharedModelContainer: ModelContainer = {
        let containerID = "iCloud.creecy.bible"
        let bundleID = Bundle.main.bundleIdentifier ?? "<unknown bundle id>"
        let teamID = Bundle.main.object(forInfoDictionaryKey: "AppIdentifierPrefix") as? String ?? "<unknown team id>"
        let buildCfg = ProcessInfo.processInfo.environment["CONFIGURATION"] ?? "<unknown config>"
        let isTestFlight = Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        let envHint = isTestFlight ? "Production (TestFlight/App Store)" : "Development (Debug/AdHoc)"
        print("🔎 SwiftData+CloudKit diagnostics:")
        print("   • Bundle ID: \(bundleID)")
        print("   • Team/AppIdentifierPrefix: \(teamID)")
        print("   • Build configuration: \(buildCfg)")
        print("   • CloudKit environment hint: \(envHint)")
        print("   • Target container: \(containerID)")

        func logError(_ prefix: String, error: Error) {
            let nsError = error as NSError
            print("❌ \(prefix): \(nsError.domain) (\(nsError.code)) \(nsError.localizedDescription)")
            if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
                print("   ↳ underlying: \(underlying.domain) (\(underlying.code)) \(underlying.localizedDescription)")
                if let serverMessage = underlying.userInfo["ServerErrorDescription"] as? String {
                    print("   ↳ server message: \(serverMessage)")
                }
            }
        }

        // Primary: CloudKit-backed configuration
        do {
            let cloudKitConfig = ModelConfiguration(
                // Use your iCloud container identifier
                cloudKitDatabase: .private(containerID)
            )
            let container = try ModelContainer(
                for: ReaderSettings.self,
                    ReadingProgress.self,
                    Favorite.self,
                    Bookmark.self,
                    VerseNote.self,
                    JournalEntry.self,
                configurations: cloudKitConfig
            )
            print("✅ CloudKit-backed ModelContainer initialized successfully.")
            // Flag for Settings "Sync Status" UI
            UserDefaults.standard.set(true, forKey: "swiftdataCloudKitEnabled")
            return container
        } catch {
            logError("Failed to create CloudKit-backed ModelContainer", error: error)
            print("⚠️ Falling back to local on-disk SwiftData store.")
            UserDefaults.standard.set(false, forKey: "swiftdataCloudKitEnabled")
        }

        // Fallback: default local store (on-disk)
        do {
            let localContainer = try ModelContainer(
                for: ReaderSettings.self,
                    ReadingProgress.self,
                    Favorite.self,
                    Bookmark.self,
                    VerseNote.self,
                    JournalEntry.self
            )
            print("ℹ️ Using local on-disk SwiftData store (no CloudKit). Data will NOT sync between devices.")
            UserDefaults.standard.set(false, forKey: "swiftdataCloudKitEnabled")
            return localContainer
        } catch {
            logError("Failed to create local on-disk ModelContainer", error: error)
            print("⚠️ Attempting in-memory fallback.")
            UserDefaults.standard.set(false, forKey: "swiftdataCloudKitEnabled")
        }

        // Final fallback: in-memory so the app can still run
        do {
            let memoryConfig = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(
                for: ReaderSettings.self,
                    ReadingProgress.self,
                    Favorite.self,
                    Bookmark.self,
                    VerseNote.self,
                    JournalEntry.self,
                configurations: memoryConfig
            )
            print("ℹ️ Using in-memory SwiftData store. Data will NOT persist or sync.")
            UserDefaults.standard.set(false, forKey: "swiftdataCloudKitEnabled")
            return container
        } catch {
            fatalError("Could not create any ModelContainer (including in-memory): \(error)")
        }
    }()

    // MARK: - CloudKit
    @StateObject private var cloudKitManager = CloudKitManager(containerIdentifier: "iCloud.creecy.bible")

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(cloudKitManager)
                .task {
                    await cloudKitManager.prepare()
                    iCloudSyncCoordinator.shared.start()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .active:
                        UNUserNotificationCenter.current().setBadgeCount(0, withCompletionHandler: nil)
                        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
                        Task { await cloudKitManager.refresh() }
                    case .background:
                        Task {
                            await cloudKitManager.flushPending()
                            // NEW: opportunistically push all known KVS keys on background
                            iCloudSyncCoordinator.shared.pushAllNow()
                        }
                    default:
                        break
                    }
                }
                .onAppear {
                    CloudKitManager.logEntitlementHints(containerIdentifier: "iCloud.creecy.bible")
                }
        }
        .modelContainer(sharedModelContainer)
    }
}

// MARK: - Simple CloudKit manager for availability and basic access
@MainActor
final class CloudKitManager: ObservableObject {
    enum AccountState: CustomStringConvertible {
        case unknown
        case available
        case noAccount
        case restricted
        case couldNotDetermine

        var description: String {
            switch self {
            case .unknown: return "unknown"
            case .available: return "available"
            case .noAccount: return "noAccount"
            case .restricted: return "restricted"
            case .couldNotDetermine: return "couldNotDetermine"
            }
        }
    }

    @Published private(set) var accountState: AccountState = .unknown
    @Published private(set) var userRecordID: CKRecord.ID?

    private let container: CKContainer
    private let privateDB: CKDatabase
    private let sharedDB: CKDatabase
    private let publicDB: CKDatabase

    init(containerIdentifier: String) {
        self.container = CKContainer(identifier: containerIdentifier)
        self.privateDB = container.privateCloudDatabase
        self.sharedDB = container.sharedCloudDatabase
        self.publicDB = container.publicCloudDatabase

        let bundleID = Bundle.main.bundleIdentifier ?? "<unknown bundle id>"
        let isTestFlight = Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        let envHint = isTestFlight ? "Production (TestFlight/App Store)" : "Development (Debug/AdHoc)"
        print("🔎 CloudKit diagnostics:")
        print("   • Container: \(containerIdentifier)")
        print("   • Bundle ID: \(bundleID)")
        print("   • Environment hint: \(envHint)")
    }

    func prepare() async {
        await refreshAccountStatus()
        await fetchUserRecordIDIfAvailable()
    }

    func refresh() async {
        print("ℹ️ CloudKitManager.refresh() called")
    }

    func flushPending() async {
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
            case .couldNotDetermine:
                fallthrough
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

    func privateDatabase() -> CKDatabase { privateDB }
    func sharedDatabase() -> CKDatabase { sharedDB }
    func publicDatabase() -> CKDatabase { publicDB }

    static func logEntitlementHints(containerIdentifier: String) {
        let hasSandboxReceipt = Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        let bundleID = Bundle.main.bundleIdentifier ?? "<unknown>"
        let appIDPrefix = Bundle.main.object(forInfoDictionaryKey: "AppIdentifierPrefix") as? String ?? "<unknown>"
        let cfg = ProcessInfo.processInfo.environment["CONFIGURATION"] ?? "<unknown>"
        print("🔎 Entitlement hints:")
        print("   • Bundle ID: \(bundleID)")
        print("   • AppIdentifierPrefix (TeamID.): \(appIDPrefix)")
        print("   • Build configuration: \(cfg)")
        print("   • Receipt is sandbox? \(hasSandboxReceipt ? "YES (TestFlight/App Store Production env)" : "NO (likely Development env)")")
        print("   • Expect CloudKit container entitlement for: \(containerIdentifier)")
        print("   • Ensure iCloud capability with CloudKit is ON and container is checked for this target/configuration.")
    }
}
