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
import CloudKit
import OSLog

final class BibleAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    static let pendingVerseOfDayNotificationKey = "pendingVerseOfDayNotification"

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        // Before any screen reads saved verse text, remove markup saved by older versions.
        StoredVerseTextCleaner.cleanSavedTextIfNeeded()
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let request = response.notification.request
        let destination = request.content.userInfo["destination"] as? String
        let isVerseOfDay = destination == "verseOfDay"
            || request.identifier.hasPrefix("verse-of-day-refresh-")

        if isVerseOfDay {
            UserDefaults.standard.set(true, forKey: Self.pendingVerseOfDayNotificationKey)
            Task { @MainActor in
                AppRouter.shared.open(.verseOfDayNotification)
            }
        } else if destination == StreakReminderScheduler.destination {
            // Streak reminders open Home, where the Reading Streak card lives.
            Task { @MainActor in
                AppRouter.shared.open(.tab(.home))
            }
        }

        completionHandler()
    }
}

@main
struct The_Bible__iOS_App: App {
    @UIApplicationDelegateAdaptor(BibleAppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    private static let persistenceLogger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "The Bible",
        category: "PersistenceStore"
    )

    private let sharedModelContainer: ModelContainer
    /// Shown in Settings so a fallback store is never mistaken for working sync.
    private let persistenceStoreMode: PersistenceStoreMode

    init() {
        UITestSupport.configureIfNeeded()
        let store = Self.makeModelContainer()
        sharedModelContainer = store.container
        persistenceStoreMode = store.mode
    }

    // MARK: - SwiftData (CloudKit-backed with local fallback) + diagnostics
    private static func makeModelContainer() -> (container: ModelContainer, mode: PersistenceStoreMode) {
        let containerID = "iCloud.creecy.bible"
        let bundleID = Bundle.main.bundleIdentifier ?? "<unknown bundle id>"
        let teamID = Bundle.main.object(forInfoDictionaryKey: "AppIdentifierPrefix") as? String ?? "<unknown team id>"
        let buildCfg = ProcessInfo.processInfo.environment["CONFIGURATION"] ?? "<unknown config>"
        // Deprecated on iOS 18; keep a coarse hint without StoreKit.
        let envHint: String = {
            #if DEBUG
            return "Development (Debug/AdHoc)"
            #else
            return "Production (TestFlight/App Store)"
            #endif
        }()
        print("🔎 SwiftData+CloudKit diagnostics:")
        print("   • Bundle ID: \(bundleID)")
        print("   • Team/AppIdentifierPrefix: \(teamID)")
        print("   • Build configuration: \(buildCfg)")
        print("   • CloudKit environment hint: \(envHint)")
        print("   • Target container: \(containerID)")

        func logError(_ prefix: String, error: Error) {
            let nsError = error as NSError
            Self.persistenceLogger.error("\(prefix, privacy: .public); domain=\(nsError.domain, privacy: .public), code=\(nsError.code, privacy: .public).")
            print("❌ \(prefix): \(nsError.domain) (\(nsError.code)) \(nsError.localizedDescription)")
            if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
                print("   ↳ underlying: \(underlying.domain) (\(underlying.code)) \(underlying.localizedDescription)")
                if let serverMessage = underlying.userInfo["ServerErrorDescription"] as? String {
                    print("   ↳ server message: \(serverMessage)")
                }
            }
        }

        // Extra diagnostics: probe common locations for stale/default stores
        func logLikelyStoreLocations() {
            // App documents and application support
            let fm = FileManager.default
            let urls: [URL?] = [
                fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
                fm.urls(for: .documentDirectory, in: .userDomainMask).first
            ]
            for u in urls.compactMap({ $0 }) {
                print("   • App path: \(u.path)")
                let defaultStore = u.appendingPathComponent("default.store")
                if fm.fileExists(atPath: defaultStore.path) {
                    print("     ↳ Found app default.store at: \(defaultStore.path)")
                }
                let wal = u.appendingPathComponent("default.store-wal")
                let shm = u.appendingPathComponent("default.store-shm")
                if fm.fileExists(atPath: wal.path) { print("     ↳ Found app default.store-wal at: \(wal.path)") }
                if fm.fileExists(atPath: shm.path) { print("     ↳ Found app default.store-shm at: \(shm.path)") }
            }

            // App Group container (used elsewhere in the app for widgets, etc.)
            if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.bible.app") {
                let support = groupURL.appendingPathComponent("Library").appendingPathComponent("Application Support")
                print("   • App Group path: \(support.path)")
                let defaultStore = support.appendingPathComponent("default.store")
                if fm.fileExists(atPath: defaultStore.path) {
                    print("     ↳ Found group default.store at: \(defaultStore.path)")
                }
                let wal = support.appendingPathComponent("default.store-wal")
                let shm = support.appendingPathComponent("default.store-shm")
                if fm.fileExists(atPath: wal.path) { print("     ↳ Found group default.store-wal at: \(wal.path)") }
                if fm.fileExists(atPath: shm.path) { print("     ↳ Found group default.store-shm at: \(shm.path)") }
            } else {
                print("   • App Group path: <nil> (group.bible.app not available for this run/build?)")
            }
        }

        print("🔎 Probing likely store locations (before ModelContainer init)…")
        logLikelyStoreLocations()

        // Primary: CloudKit-backed configuration
        do {
            print("➡️ Creating CloudKit-backed ModelContainer…")
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
                    UserNote.self,
                configurations: cloudKitConfig
            )
            Self.persistenceLogger.notice("Initialized the CloudKit-backed SwiftData store.")
            print("✅ CloudKit-backed ModelContainer initialized successfully.")

            // Attempt to log the underlying store location(s) if available
            print("🔎 CloudKit ModelContainer ready. (Local cache path is managed by the system.)")
            return (container, .cloudKit)
        } catch {
            logError("Failed to create CloudKit-backed ModelContainer", error: error)
            print("⚠️ Falling back to local on-disk SwiftData store.")
        }

        // Fallback: default local store (on-disk)
        do {
            print("➡️ Creating local on-disk ModelContainer (default location)…")
            let localContainer = try ModelContainer(
                for: ReaderSettings.self,
                    ReadingProgress.self,
                    Favorite.self,
                    Bookmark.self,
                    VerseNote.self,
                    UserNote.self
            )
            Self.persistenceLogger.notice("Using the local-only SwiftData fallback; iCloud sync is unavailable.")
            print("ℹ️ Using local on-disk SwiftData store (no CloudKit). Data will NOT sync between devices.")

            print("🔎 Probing likely store locations (after local container init)…")
            logLikelyStoreLocations()

            return (localContainer, .localOnly)
        } catch {
            logError("Failed to create local on-disk ModelContainer", error: error)
            print("⚠️ Attempting in-memory fallback.")
        }

        // Final fallback: in-memory so the app can still run
        do {
            print("➡️ Creating in-memory ModelContainer…")
            let memoryConfig = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(
                for: ReaderSettings.self,
                    ReadingProgress.self,
                    Favorite.self,
                    Bookmark.self,
                    VerseNote.self,
                    UserNote.self,
                configurations: memoryConfig
            )
            Self.persistenceLogger.fault("Using the in-memory SwiftData fallback; changes will not persist.")
            print("ℹ️ Using in-memory SwiftData store. Data will NOT persist or sync.")
            return (container, .inMemory)
        } catch {
            fatalError("Could not create any ModelContainer (including in-memory): \(error)")
        }
    }

    // MARK: - CloudKit
    @State private var cloudKitManager = CloudKitManager(containerIdentifier: "iCloud.creecy.bible")

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(cloudKitManager)
                .environment(\.persistenceStoreMode, persistenceStoreMode)
                .task {
                    await cloudKitManager.prepare()
                    // iCloud key-value sync is started by ContentView.

                    // Run the GMT→local daily key migration once before any stats/streaks are read.
                    BibleStatsStore.shared.migrateDailyKeysFromGMTToLocalIfNeeded()

                    // Removed StoreKit environment hint to avoid Simulator auth logs when not using StoreKit.
                }
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .active:
                        UNUserNotificationCenter.current().setBadgeCount(0, withCompletionHandler: nil)
                        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
                        Task { await cloudKitManager.refresh() }
                        Task { await StreakReminderScheduler.refresh() }
                    case .background:
                        // iCloudSyncCoordinator pushes its own keys when the app enters the background.
                        // Drops today's reminder if reading in this session met the goal.
                        Task { await StreakReminderScheduler.refresh() }
                    default:
                        break
                    }
                }
                .onAppear {
                    CloudKitManager.logEntitlementHints(containerIdentifier: "iCloud.creecy.bible")
                }
                // Handle widget deep links here too, and broadcast a tab switch.
                .onOpenURL { url in
                    if BibleReferenceLinker.parse(url: url) != nil {
                        AppRouter.shared.open(.scripturePreview(url))
                        return
                    }
                    guard url.scheme?.lowercased() == "thebible" else { return }
                    let host = url.host?.lowercased() ?? ""
                    if host == "home" {
                        AppRouter.shared.open(.tab(.home))
                        return
                    }
                    // Let ContentView handle other deep links (like thebible://open?...).
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
