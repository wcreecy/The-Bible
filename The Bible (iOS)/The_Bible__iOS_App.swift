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
        // Deprecated on iOS 18; keep a coarse hint without StoreKit.
        let envHint = The_Bible__iOS_App.buildEnvHintFallback()
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

                    // Run the GMT→local daily key migration once before any stats/streaks are read.
                    BibleStatsStore.shared.migrateDailyKeysFromGMTToLocalIfNeeded()

                    // Removed StoreKit environment hint to avoid Simulator auth logs when not using StoreKit.
                }
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .active:
                        // Ensure KVS merges are applied immediately when app becomes active.
                        NSUbiquitousKeyValueStore.default.synchronize()
                        UNUserNotificationCenter.current().setBadgeCount(0, withCompletionHandler: nil)
                        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
                        Task { await cloudKitManager.refresh() }
                    case .background:
                        Task {
                            await cloudKitManager.flushPending()
                            // Opportunistically push all known KVS keys on background
                            iCloudSyncCoordinator.shared.pushAllNow()
                        }
                    default:
                        break
                    }
                }
                .onAppear {
                    CloudKitManager.logEntitlementHints(containerIdentifier: "iCloud.creecy.bible")
                }
                // Handle widget deep links here too, and broadcast a tab switch.
                .onOpenURL { url in
                    guard url.scheme?.lowercased() == "thebible" else { return }
                    let host = url.host?.lowercased() ?? ""
                    if host == "home" {
                        // Tell ContentView to switch to Home (tag 0)
                        NotificationCenter.default.post(name: .switchToTab, object: nil, userInfo: ["tab": 0])
                        return
                    }
                    // Let ContentView handle other deep links (like thebible://open?...).
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
