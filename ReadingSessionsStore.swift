import Foundation

/// The sole owner of the reading-session JSON payload. Actor isolation keeps decoding
/// and encoding off the main actor while preserving write order.
private actor ReadingSessionsRepository {
    private let key: String
    private let defaults: UserDefaults
    private var lastPersistedRevision = 0

    init(key: String, defaults: UserDefaults = .standard) {
        self.key = key
        self.defaults = defaults
    }

    func load() -> [ReadingSessionsStore.Session] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([ReadingSessionsStore.Session].self, from: data)) ?? []
    }

    func save(_ sessions: [ReadingSessionsStore.Session], revision: Int) {
        guard revision >= lastPersistedRevision else { return }
        guard let data = try? JSONEncoder().encode(sessions) else { return }
        defaults.set(data, forKey: key)
        lastPersistedRevision = revision
    }

    func clear(revision: Int) {
        guard revision >= lastPersistedRevision else { return }
        defaults.removeObject(forKey: key)
        lastPersistedRevision = revision
    }
}

/// Stores lightweight reading sessions with a main-actor cache for SwiftUI callers.
/// The archive itself is decoded and encoded by `ReadingSessionsRepository`.
@MainActor
final class ReadingSessionsStore {
    static let shared = ReadingSessionsStore()
    static let minimumValidSessionSeconds = 60
    private init() {
        // Invalidate cache when external merges happen (iCloud KVS or other writers)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleExternalUpdate),
            name: .bibleStatsExternallyUpdated,
            object: nil
        )
    }

    @objc
    private func handleExternalUpdate() {
        // We are already on the main actor due to @MainActor type.
        revision += 1
        loadTask?.cancel()
        loadTask = nil
        cacheAllSessions = nil
    }

    struct Session: Codable, Equatable, Sendable {
        let readingSessionID: UUID?
        let start: Date
        let end: Date
        let book: String
        let chapter: Int?

        init(readingSessionID: UUID? = nil, start: Date, end: Date, book: String, chapter: Int?) {
            self.readingSessionID = readingSessionID
            self.start = start
            self.end = end
            self.book = book
            self.chapter = chapter
        }
    }

    private struct Defaults {
        static let key = "readingSessions"
        static var provider: UserDefaults { UserDefaults.standard }
    }

    private let repository = ReadingSessionsRepository(key: Defaults.key)

    // In-memory cache. A load begins eagerly when a consumer first asks for sessions.
    private var cacheAllSessions: [Session]?
    private var pendingAppends: [Session] = []
    private var loadTask: Task<Void, Never>?
    private var revision = 0
    private var persistenceRevision = 0

    // MARK: - Public API

    func appendSession(_ session: Session) {
        appendSessions([session])
    }

    func appendSessions(_ sessions: [Session]) {
        let validSessions = sessions.filter(Self.isValid)
        guard !validSessions.isEmpty else { return }

        ensureLoaded()
        guard var all = cacheAllSessions else {
            pendingAppends.append(contentsOf: validSessions)
            return
        }
        all.append(contentsOf: validSessions)
        saveAll(all)
    }

    static func duration(of session: Session) -> Int {
        Int(max(0, session.end.timeIntervalSince(session.start)))
    }

    static func isValid(_ session: Session) -> Bool {
        duration(of: session) >= minimumValidSessionSeconds
    }

    func allSessions() -> [Session] {
        ensureLoaded()
        return loadAll()
    }

    // Normalize to local start-of-day boundaries for rolling day windows.
    func sessions(inLastDays days: Int, now: Date = Date(), calendar: Calendar = .autoupdatingCurrent) -> [Session] {
        guard days > 0 else { return [] }
        let cutoff = Self.startDate(forLastDays: days, now: now, calendar: calendar)
        return loadAll().filter { $0.end >= cutoff }
    }

    static func startDate(forLastDays days: Int, now: Date, calendar: Calendar = .autoupdatingCurrent) -> Date {
        guard days > 0 else { return .distantFuture }
        let cal = calendar
        // Include today and the preceding days - 1 local calendar dates.
        let startOfToday = cal.startOfDay(for: now)
        return cal.date(byAdding: .day, value: -(days - 1), to: startOfToday) ?? .distantPast
    }

    func sessions(inMonthContaining date: Date, calendar: Calendar = .autoupdatingCurrent) -> [Session] {
        var cal = calendar
        cal.timeZone = TimeZone.autoupdatingCurrent
        let comps = cal.dateComponents([.year, .month], from: date)
        guard let start = cal.date(from: comps),
              let range = cal.range(of: .day, in: .month, for: start),
              let monthEnd = cal.date(byAdding: .day, value: range.count, to: start) else {
            return []
        }
        return loadAll().filter { $0.end >= start && $0.end < monthEnd }
    }

    // Clear all stored sessions (used by debug tools)
    func clearAll() {
        revision += 1
        loadTask?.cancel()
        loadTask = nil
        cacheAllSessions = []
        pendingAppends = []
        let repository = repository
        persistenceRevision += 1
        let persistenceRevision = persistenceRevision
        Task {
            await repository.clear(revision: persistenceRevision)
            iCloudSyncCoordinator.shared.pushKey(Defaults.key)
        }
        // Push sessions key removal to iCloud KVS for cross-device sync and notify listeners
        NotificationCenter.default.post(name: .bibleStatsExternallyUpdated, object: nil)
    }

    // MARK: - Persistence + cache

    /// Starts background hydration without requiring callers to await it.
    func prewarm() {
        ensureLoaded()
    }

    private func loadAll() -> [Session] {
        cacheAllSessions ?? []
    }

    private func ensureLoaded() {
        guard cacheAllSessions == nil, loadTask == nil else { return }

        let repository = repository
        let revision = revision
        loadTask = Task { [weak self] in
            let loaded = await repository.load()
            guard let self, !Task.isCancelled, self.revision == revision else { return }

            let all = loaded + self.pendingAppends
            let hadPendingAppends = !self.pendingAppends.isEmpty
            self.pendingAppends = []
            self.cacheAllSessions = all
            self.loadTask = nil

            if hadPendingAppends {
                self.saveAll(all)
            }
            NotificationCenter.default.post(name: .bibleStatsExternallyUpdated, object: nil)
        }
    }

    private func saveAll(_ arr: [Session]) {
        cacheAllSessions = arr
        let repository = repository
        persistenceRevision += 1
        let persistenceRevision = persistenceRevision
        Task {
            await repository.save(arr, revision: persistenceRevision)
            iCloudSyncCoordinator.shared.pushKey(Defaults.key)
        }

        // Views read the cache immediately; other local consumers refresh without
        // waiting for the background encoder to finish.
        NotificationCenter.default.post(name: .bibleStatsExternallyUpdated, object: nil)
    }
}
