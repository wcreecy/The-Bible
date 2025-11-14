//
//  The_Bible__iOS_App.swift
//  The Bible (iOS)
//
//  Created by William Creecy on 11/7/25.
//

import SwiftUI
import SwiftData
import Combine
import OSLog

@MainActor
final class LaunchDiagnostics: ObservableObject {
    static let shared = LaunchDiagnostics()

    // Logging & signposts
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TheBible", category: "Launch")
    private let signposter = OSSignposter()
    private var prewarmInterval: OSSignpostIntervalState? = nil
    private var containerInterval: OSSignpostIntervalState? = nil

    // Debug overlay override
    private let overlayDebugKey = "debugShowLaunchOverlay"

    // First-launch gating
    private(set) var isFirstLaunch: Bool

    // Timestamps
    private let appStart = Date()
    @Published var splashFirstFrame: Date? = nil
    @Published var prewarmStart: Date? = nil
    @Published var prewarmEnd: Date? = nil
    @Published var containerBuildStart: Date? = nil
    @Published var containerReady: Date? = nil

    // Whether to draw overlay (DEBUG only)
    var showOverlay: Bool {
        #if DEBUG
        return isFirstLaunch || UserDefaults.standard.bool(forKey: overlayDebugKey)
        #else
        return false
        #endif
    }

    private init() {
        let key = "hasLaunchedBefore"
        let hasLaunched = UserDefaults.standard.bool(forKey: key)
        self.isFirstLaunch = !hasLaunched
        if !hasLaunched {
            UserDefaults.standard.set(true, forKey: key)
        }
    }

    func setDebugOverlay(_ enabled: Bool) {
        #if DEBUG
        UserDefaults.standard.set(enabled, forKey: overlayDebugKey)
        objectWillChange.send()
        #endif
    }

    func toggleDebugOverlay() {
        #if DEBUG
        let current = UserDefaults.standard.bool(forKey: overlayDebugKey)
        setDebugOverlay(!current)
        #endif
    }

    enum Event {
        case splashFirstFrame
        case prewarmStart
        case prewarmEnd
        case containerBuildStart
        case containerReady
    }

    func mark(_ event: Event) {
        switch event {
        case .splashFirstFrame:
            if splashFirstFrame == nil {
                splashFirstFrame = Date()
                signposter.emitEvent("FirstFrame")
            }
        case .prewarmStart:
            prewarmStart = Date()
            prewarmInterval = signposter.beginInterval("Prewarm")
        case .prewarmEnd:
            prewarmEnd = Date()
            if let interval = prewarmInterval { signposter.endInterval("Prewarm", interval) }
            logger.log("Prewarm completed in: \(self.tPrewarm ?? 0, format: .fixed(precision: 2)) s")
            logSummary()
        case .containerBuildStart:
            containerBuildStart = Date()
            containerInterval = signposter.beginInterval("ContainerBuild")
        case .containerReady:
            containerReady = Date()
            if let interval = containerInterval { signposter.endInterval("ContainerBuild", interval) }
            logger.log("Container build completed in: \(self.tContainerBuild ?? 0, format: .fixed(precision: 2)) s")
            logSummary()
        }
    }

    // Computed durations
    var ttfFirstFrame: TimeInterval? { splashFirstFrame?.timeIntervalSince(appStart) }
    var tPrewarm: TimeInterval? {
        guard let s = prewarmStart, let e = prewarmEnd else { return nil }
        return e.timeIntervalSince(s)
    }
    var tContainerBuild: TimeInterval? {
        guard let s = containerBuildStart, let e = containerReady else { return nil }
        return e.timeIntervalSince(s)
    }

    private func fmt(_ t: TimeInterval?) -> String {
        guard let t else { return "–" }
        return String(format: "%.2f s", t)
    }

    private func logSummary() {
        #if DEBUG
        print("📊 Launch diagnostics summary (first launch: \(isFirstLaunch))")
        print("  • Time to first frame: \(fmt(ttfFirstFrame))")
        print("  • Prewarm duration:   \(fmt(tPrewarm))")
        print("  • Container build:    \(fmt(tContainerBuild))")
        #endif
    }
}

struct DiagnosticsOverlay: View {
    @ObservedObject private var diag = LaunchDiagnostics.shared

    var body: some View {
        Group {
            if diag.showOverlay {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Launch Diagnostics")
                        .font(.caption).bold()
                    HStack { Text("TTFF:").font(.caption2).bold(); Text(time(diag.ttfFirstFrame)) .font(.caption2) }
                    HStack { Text("Prewarm:").font(.caption2).bold(); Text(time(diag.tPrewarm)) .font(.caption2) }
                    HStack { Text("Container:").font(.caption2).bold(); Text(time(diag.tContainerBuild)) .font(.caption2) }
                }
                .padding(8)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(.secondary.opacity(0.2), lineWidth: 1)
                )
                .onTapGesture(count: 2) { LaunchDiagnostics.shared.toggleDebugOverlay() }
            }
        }
    }

    private func time(_ t: TimeInterval?) -> String {
        guard let t else { return "–" }
        return String(format: "%.2f s", t)
    }
}

@MainActor
final class AppBootstrap: ObservableObject {
    @Published var container: ModelContainer? = nil

    private var started = false

    func startIfNeeded() async {
        guard !started else { return }
        started = true

        // Kick off container build
        Task { await buildContainer() }

        // Prewarm heavy data off the main thread after first frame
        Task.detached(priority: .utility) {
            await LaunchDiagnostics.shared.mark(.prewarmStart)
            _ = BibleData.books
            await LaunchDiagnostics.shared.mark(.prewarmEnd)
        }
    }

    private func buildContainer() async {
        do {
            LaunchDiagnostics.shared.mark(.containerBuildStart)
            // Build the container off the main actor to avoid blocking first frame
            let c = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<ModelContainer, Error>) in
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        let container = try ModelContainer(for:
                            ReaderSettings.self,
                            ReadingProgress.self,
                            Favorite.self,
                            Bookmark.self,
                            VerseNote.self,
                            JournalEntry.self
                        )
                        cont.resume(returning: container)
                    } catch {
                        cont.resume(throwing: error)
                    }
                }
            }
            self.container = c
            LaunchDiagnostics.shared.mark(.containerReady)
        } catch {
            // Fallback to in-memory so the app remains usable
            do {
                let memoryConfig = ModelConfiguration(isStoredInMemoryOnly: true)
                let c = try ModelContainer(for:
                    ReaderSettings.self,
                    ReadingProgress.self,
                    Favorite.self,
                    Bookmark.self,
                    VerseNote.self,
                    JournalEntry.self,
                    configurations: memoryConfig
                )
                self.container = c
                print("ℹ️ Using in-memory SwiftData store due to initialization failure: \(error)")
            } catch {
                // As a last resort, leave container nil; UI will show a basic error view
                print("❌ Failed to create any SwiftData container: \(error)")
            }
        }
    }
}

struct SplashView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "book.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.tint)
                Text("The Bible")
                    .font(.title2).bold()
                    .foregroundStyle(.primary)
                ProgressView()
                    .progressViewStyle(.circular)
                    .padding(.top, 8)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading")
    }
}

@main
struct The_Bible__iOS_App: App {
    @StateObject private var bootstrap = AppBootstrap()

    var body: some Scene {
        WindowGroup {
            ZStack(alignment: .topLeading) {
                Group {
                    if let container = bootstrap.container {
                        ContentView()
                            .modelContainer(container)
                    } else {
                        SplashView()
                    }
                }
                #if DEBUG
                DiagnosticsOverlay()
                    .padding(8)
                    .allowsHitTesting(false)
                    .opacity(LaunchDiagnostics.shared.showOverlay ? 1 : 0)
                #endif
            }
            .onAppear { LaunchDiagnostics.shared.mark(.splashFirstFrame) }
            .task { await bootstrap.startIfNeeded() }
        }
    }
}

// MARK: - App Group Helper (use this instead of CFPreferences with AnyUser)
struct AppGroup {
    static let identifier = AppGroupID.identifier

    static var userDefaults: UserDefaults? {
        UserDefaults.appGroup
    }

    static func containerURL() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }
}

