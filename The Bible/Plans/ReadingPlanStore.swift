import Foundation
import Observation
import OSLog

private let readingPlanLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "The Bible",
    category: "ReadingPlans"
)

/// Reading plans: the bundled catalog, plans the reader built, and progress through each.
///
/// Progress and custom plans are saved as one `ReadingPlansDocument` and synced through
/// iCloud key-value storage (see `iCloudSyncCoordinator+ReadingPlans`). The catalog itself
/// is read-only and comes from `ReadingPlans.json`.
@MainActor
@Observable
final class ReadingPlanStore {
    static let shared = ReadingPlanStore()
    static let storageKey = "readingPlansV1"

    /// A plan reading opened in the reader, so the reader can show where it fits in the plan
    /// and offer the next one. Kept on this device only, across launches.
    struct Session: Codable, Equatable {
        let planID: String
        let day: Int
        let readingIndex: Int
    }

    /// Where the reader is within the session's reading, for the chapter on screen.
    struct SessionContext {
        let session: Session
        let plan: ReadingPlan
        let day: PlanDay
        let reading: PlanReading
        /// 1-based position of this chapter within the reading, and how many chapters it spans.
        let chapterPosition: Int
        let chapterCount: Int
        /// Set when the reading stops partway through this chapter, after this verse.
        let endsAfterVerse: Int?

        var isLastChapter: Bool { chapterPosition == chapterCount }
    }

    /// Something worth a brief note in the reader, such as a reading checked off.
    struct Event: Equatable, Identifiable {
        enum Kind: Equatable {
            case readingCompleted(String)
            case dayCompleted(day: Int, planTitle: String)
            case planFinished(String)
        }

        let id = UUID()
        let kind: Kind
    }

    /// A day just finished, shown briefly by whatever screen is open.
    struct Completion: Equatable, Identifiable {
        let id = UUID()
        let planID: String
        let day: Int
        let finishedPlan: Bool
    }

    private(set) var catalog: [ReadingPlan] = []
    private(set) var document = ReadingPlansDocument()
    private(set) var session: Session? {
        didSet { saveSession() }
    }
    var latestCompletion: Completion?
    private(set) var latestEvent: Event?

    /// At most this many plans run at once; it keeps the synced progress small and the Home
    /// card readable.
    static let maximumActivePlans = 3
    /// Custom plans keep every day's readings, so only this many are kept.
    static let maximumCustomPlans = 10
    private static let sessionKey = "readingPlanSessionV1"

    /// A reading counts as read once this share of its verses has been on screen, including
    /// its last verse. Verses skimmed past quickly aren't recorded, so it isn't all of them.
    static let readThreshold = 0.8

    /// Verses seen for each plan reading this launch, keyed by `readingKey`.
    @ObservationIgnored private var viewedVerses: [String: Set<String>] = [:]
    @ObservationIgnored private var cachedTerms: [BibleTerm]?
    @ObservationIgnored private var cachedHighlights: [String: [CustomPlanGenerator.Highlight]] = [:]
    @ObservationIgnored private let defaults: UserDefaults
    /// Off in tests, which shouldn't sync, reload widgets, or schedule notifications.
    @ObservationIgnored private let publishesChanges: Bool
    /// Each chapter's verse count for a book. Tests supply their own instead of the corpus.
    @ObservationIgnored var verseCountsForBook: (String) -> [Int] = { ReadingPlanStore.verseCounts(forBook: $0) }

    init(defaults: UserDefaults = .standard, catalog: [ReadingPlan]? = nil, publishesChanges: Bool = true) {
        self.defaults = defaults
        self.publishesChanges = publishesChanges
        self.catalog = catalog ?? Self.loadCatalog()
        document = Self.decode(defaults.data(forKey: Self.storageKey)) ?? ReadingPlansDocument()
        session = defaults.data(forKey: Self.sessionKey)
            .flatMap { try? JSONDecoder().decode(Session.self, from: $0) }
    }

    // MARK: - Plans

    /// Catalog categories in the order the catalog lists them.
    var categories: [String] {
        var seen = Set<String>()
        return catalog.map(\.category).filter { seen.insert($0).inserted }
    }

    var customPlans: [ReadingPlan] {
        document.customPlans.values
            .filter { !$0.isDeleted }
            .sorted { $0.createdAt > $1.createdAt }
            .map(\.plan)
    }

    /// Catalog plans that read mostly `bookName`, such as The Gospel of John for John.
    func plans(readingMostly bookName: String, share: Double = 0.75) -> [ReadingPlan] {
        catalog.filter { plan in
            var inBook = 0
            var total = 0
            for reading in plan.days.flatMap(\.readings) {
                let count = reading.verses(verseCounts: verseCountsForBook(reading.book)).count
                total += count
                if reading.book == bookName { inBook += count }
            }
            return total > 0 && Double(inBook) / Double(total) >= share
        }
    }

    /// Catalog plans to suggest starting: not finished and not running. A series offers only
    /// its first unfinished part, so parts are read in order. Empty once everything is done.
    var plansToSuggest: [ReadingPlan] {
        func isFinished(_ plan: ReadingPlan) -> Bool { document.enrollments[plan.id]?.finishedAt != nil }
        var seriesOffered = Set<String>()
        return catalog.filter { plan in
            guard !isFinished(plan), enrollment(for: plan.id)?.isActive != true else { return false }
            guard let series = plan.series else { return true }
            // Only the earliest unfinished part of a series, and only once.
            let firstUnfinished = plans(inSeries: series).first { !isFinished($0) }
            return firstUnfinished?.id == plan.id && seriesOffered.insert(series).inserted
        }
    }

    /// A series' plans, in catalog order.
    func plans(inSeries series: String) -> [ReadingPlan] {
        catalog.filter { $0.series == series }
    }

    /// Where a plan falls in its series: 1-based position and the series length.
    func seriesPosition(of plan: ReadingPlan) -> (position: Int, count: Int)? {
        guard let series = plan.series else { return nil }
        let parts = plans(inSeries: series)
        guard let index = parts.firstIndex(where: { $0.id == plan.id }) else { return nil }
        return (index + 1, parts.count)
    }

    /// The plan after this one in its series.
    func nextInSeries(after plan: ReadingPlan) -> ReadingPlan? {
        guard let series = plan.series else { return nil }
        let parts = plans(inSeries: series)
        guard let index = parts.firstIndex(where: { $0.id == plan.id }) else { return nil }
        return parts[safe: index + 1]
    }

    func plan(id: String) -> ReadingPlan? {
        if let record = document.customPlans[id] {
            return record.isDeleted ? nil : record.plan
        }
        return catalog.first { $0.id == id }
    }

    // MARK: - Progress

    /// Progress for a plan that has been started and not stopped.
    func enrollment(for planID: String) -> PlanEnrollment? {
        guard let enrollment = document.enrollments[planID], !enrollment.isStopped else { return nil }
        return enrollment
    }

    /// Plans in progress, most recently read first.
    var activePlans: [(plan: ReadingPlan, enrollment: PlanEnrollment)] {
        document.enrollments.values
            .filter(\.isActive)
            .sorted { $0.lastActivityAt > $1.lastActivityAt }
            .compactMap { enrollment in plan(id: enrollment.planID).map { ($0, enrollment) } }
    }

    /// Plans finished and not restarted, most recent first.
    var finishedPlans: [(plan: ReadingPlan, enrollment: PlanEnrollment)] {
        document.enrollments.values
            .filter { !$0.isStopped && $0.finishedAt != nil }
            .sorted { ($0.finishedAt ?? .distantPast) > ($1.finishedAt ?? .distantPast) }
            .compactMap { enrollment in plan(id: enrollment.planID).map { ($0, enrollment) } }
    }

    /// The first day not yet read. Plans are self-paced, so this is "today's" reading no
    /// matter how many calendar days have passed.
    func currentDay(of plan: ReadingPlan) -> PlanDay? {
        let completed = enrollment(for: plan.id)?.completedDays ?? []
        return plan.days.first { !completed.contains($0.day) }
    }

    func isDayComplete(_ day: Int, planID: String) -> Bool {
        enrollment(for: planID)?.completedDays.contains(day) ?? false
    }

    func isReadingComplete(_ index: Int, day: Int, planID: String) -> Bool {
        guard let enrollment = enrollment(for: planID) else { return false }
        return enrollment.completedDays.contains(day)
            || enrollment.completedReadings[day]?.contains(index) == true
    }

    func progress(of plan: ReadingPlan) -> Double {
        guard let enrollment = enrollment(for: plan.id), !plan.days.isEmpty else { return 0 }
        return Double(enrollment.completedDays.count) / Double(plan.days.count)
    }

    /// For long schedules: how the reader is doing against a day per calendar day, or nil
    /// when it isn't worth mentioning.
    func paceDescription(for plan: ReadingPlan, now: Date = Date(), calendar: Calendar = .current) -> String? {
        guard plan.isSchedule, let enrollment = enrollment(for: plan.id), enrollment.isActive else { return nil }
        let start = calendar.startOfDay(for: enrollment.startedAt)
        let elapsed = (calendar.dateComponents([.day], from: start, to: calendar.startOfDay(for: now)).day ?? 0) + 1
        let expected = min(elapsed, plan.days.count)
        let difference = enrollment.completedDays.count - expected
        switch difference {
        case ..<(-1): return "\(-difference) days behind schedule"
        case -1: return "1 day behind schedule"
        case 0: return "On schedule"
        case 1: return "1 day ahead"
        default: return "\(difference) days ahead"
        }
    }

    // MARK: - Limits

    /// Whether another plan can be started now.
    var canStartAnotherPlan: Bool { activePlans.count < Self.maximumActivePlans }

    /// Whether `planID` can be started or restarted: it's already running, or there's room.
    func canStart(_ planID: String) -> Bool {
        enrollment(for: planID)?.isActive == true || canStartAnotherPlan
    }

    var canCreateCustomPlan: Bool {
        canStartAnotherPlan && customPlans.count < Self.maximumCustomPlans
    }

    /// Why a plan can't be started or created, for the screens that offer it.
    var limitMessage: String {
        if !canStartAnotherPlan {
            return "You can follow up to \(Self.maximumActivePlans) plans at a time. Finish or stop one to start another."
        }
        return "You can keep up to \(Self.maximumCustomPlans) plans of your own. Delete one to make another."
    }

    // MARK: - Changing progress

    /// Starts `planID` from day 1. Returns false when the active plan limit is reached.
    @discardableResult
    func start(_ planID: String, now: Date = Date()) -> Bool {
        guard canStart(planID) else { return false }
        document.enrollments[planID] = PlanEnrollment(planID: planID, startedAt: now)
        save()
        return true
    }

    /// Starts over from day 1.
    @discardableResult
    func restart(_ planID: String, now: Date = Date()) -> Bool {
        start(planID, now: now)
    }

    func stop(_ planID: String, now: Date = Date()) {
        guard var enrollment = document.enrollments[planID] else { return }
        enrollment.isStopped = true
        enrollment.updatedAt = now
        document.enrollments[planID] = enrollment
        if session?.planID == planID { session = nil }
        save()
    }

    func setDay(_ day: Int, of planID: String, complete: Bool, now: Date = Date()) {
        guard var enrollment = enrollment(for: planID), let plan = plan(id: planID) else { return }
        if complete {
            guard enrollment.completedDays.insert(day).inserted else { return }
            enrollment.completedReadings[day] = nil
            enrollment.lastDayCompletedAt = now
        } else {
            guard enrollment.completedDays.remove(day) != nil else { return }
            enrollment.finishedAt = nil
        }
        enrollment.lastActivityAt = now
        enrollment.updatedAt = now

        var finishedPlan = false
        if complete, enrollment.finishedAt == nil, plan.days.allSatisfy({ enrollment.completedDays.contains($0.day) }) {
            enrollment.finishedAt = now
            finishedPlan = true
        }
        document.enrollments[planID] = enrollment
        if complete {
            latestCompletion = Completion(planID: planID, day: day, finishedPlan: finishedPlan)
            latestEvent = Event(kind: finishedPlan
                ? .planFinished(plan.title)
                : .dayCompleted(day: day, planTitle: plan.title))
        }
        save()
    }

    func setReading(_ index: Int, day: Int, of planID: String, complete: Bool, now: Date = Date()) {
        guard var enrollment = enrollment(for: planID),
              let planDay = plan(id: planID)?.day(day) else { return }
        guard !enrollment.completedDays.contains(day) || !complete else { return }

        if !complete && enrollment.completedDays.contains(day) {
            // Unchecking one reading of a finished day leaves the others checked.
            enrollment.completedDays.remove(day)
            enrollment.finishedAt = nil
            enrollment.completedReadings[day] = Set(planDay.readings.indices).subtracting([index])
        } else if complete {
            enrollment.completedReadings[day, default: []].insert(index)
        } else {
            enrollment.completedReadings[day]?.remove(index)
        }
        enrollment.lastActivityAt = now
        enrollment.updatedAt = now
        document.enrollments[planID] = enrollment

        if complete, enrollment.completedReadings[day]?.isSuperset(of: planDay.readings.indices) == true {
            setDay(day, of: planID, complete: true, now: now)
        } else {
            if complete, let reading = planDay.readings[safe: index] {
                latestEvent = Event(kind: .readingCompleted(reading.title))
            }
            save()
        }
    }

    // MARK: - Custom plans

    /// The key passages of a book, for "Major Points" and "Skip Around".
    func highlights(forBook bookName: String) -> [CustomPlanGenerator.Highlight] {
        if let cached = cachedHighlights[bookName] { return cached }
        let verseCounts = verseCountsForBook(bookName)
        // Wait for the corpus; an empty book has no passages to find yet.
        guard !verseCounts.isEmpty else { return [] }

        let terms = cachedTerms ?? BibleTermMatcher.loadTerms()
        cachedTerms = terms
        let prefix = bookName + " "
        let references = terms.flatMap { term in
            term.references
                .filter { $0.type == "primary" && $0.reference.hasPrefix(prefix) }
                .map { (title: term.term, reference: $0.reference) }
        }
        let highlights = CustomPlanGenerator.highlights(from: references, bookName: bookName, verseCounts: verseCounts)
        cachedHighlights[bookName] = highlights
        return highlights
    }

    /// Builds a plan for `bookName`, saves it, and starts it. Returns its ID, or nil when a
    /// limit is reached (see `canCreateCustomPlan`).
    @discardableResult
    func createCustomPlan(bookName: String, dayCount: Int, style: CustomPlanStyle, now: Date = Date()) -> String? {
        guard canCreateCustomPlan else { return nil }
        let days = CustomPlanGenerator.makeDays(
            bookName: bookName,
            verseCounts: verseCountsForBook(bookName),
            highlights: highlights(forBook: bookName),
            style: style,
            dayCount: dayCount
        )
        let id = ReadingPlan.customIDPrefix + UUID().uuidString
        document.customPlans[id] = CustomPlanRecord(
            id: id,
            bookName: bookName,
            dayCount: days.count,
            style: style,
            days: days,
            createdAt: now,
            updatedAt: now
        )
        document.enrollments[id] = PlanEnrollment(planID: id, startedAt: now)
        save()
        return id
    }

    func deleteCustomPlan(_ id: String, now: Date = Date()) {
        guard var record = document.customPlans[id] else { return }
        record.isDeleted = true
        record.days = []
        record.updatedAt = now
        document.customPlans[id] = record
        if var enrollment = document.enrollments[id] {
            enrollment.isStopped = true
            enrollment.updatedAt = now
            document.enrollments[id] = enrollment
        }
        if session?.planID == id { session = nil }
        save()
    }

    static func verseCounts(forBook bookName: String) -> [Int] {
        BibleData.books.first { $0.name == bookName }?.chapters.map(\.verses.count) ?? []
    }

    // MARK: - Reading

    /// Remembers a plan reading as the one being read and returns it, for the caller to open.
    @discardableResult
    func beginReading(_ index: Int, day: Int, of planID: String) -> PlanReading? {
        guard let reading = plan(id: planID)?.day(day)?.readings[safe: index] else { return nil }
        session = Session(planID: planID, day: day, readingIndex: index)
        if var enrollment = enrollment(for: planID) {
            enrollment.lastActivityAt = Date()
            document.enrollments[planID] = enrollment
            saveLocally()
        }
        return reading
    }

    /// Opens a plan reading in the Bible tab's reader, with the plan and day behind it so Back
    /// returns to them (see `ContentView.openReadingPlanReading`).
    func openReading(_ index: Int, day: Int, of planID: String) {
        guard let reading = beginReading(index, day: day, of: planID) else { return }
        AppRouter.shared.open(.readingPlanReading(
            planID: planID,
            day: day,
            location: BibleReaderLocation(bookName: reading.book, chapterNumber: reading.chapter, verseNumber: reading.firstVerse)
        ))
    }

    /// The plan's current day and its first unread reading.
    func nextReading(of planID: String) -> (day: Int, index: Int)? {
        guard let plan = plan(id: planID), let day = currentDay(of: plan) else { return nil }
        let index = day.readings.indices.first { !isReadingComplete($0, day: day.day, planID: planID) } ?? 0
        return (day.day, index)
    }

    /// Opens the plan's current day at its first unread reading, from outside the plan screens.
    func continuePlan(_ planID: String) {
        guard let next = nextReading(of: planID) else { return }
        openReading(next.index, day: next.day, of: planID)
    }

    /// Where the chapter on screen sits in the session's reading, or nil when it isn't part of it.
    func sessionContext(atBook bookName: String, chapter: Int) -> SessionContext? {
        guard let session,
              let plan = plan(id: session.planID),
              enrollment(for: session.planID) != nil,
              let day = plan.day(session.day),
              let reading = day.readings[safe: session.readingIndex],
              reading.book == bookName,
              reading.contains(chapter: chapter) else { return nil }

        let verseCount = verseCountsForBook(bookName)[safe: chapter - 1] ?? 0
        var endsAfterVerse: Int?
        if chapter == reading.lastChapter, let end = reading.endVerse, end < verseCount {
            endsAfterVerse = end
        }
        return SessionContext(
            session: session,
            plan: plan,
            day: day,
            reading: reading,
            chapterPosition: chapter - reading.chapter + 1,
            chapterCount: reading.lastChapter - reading.chapter + 1,
            endsAfterVerse: endsAfterVerse
        )
    }

    /// Marks the session's reading read and opens the day's next reading in its place.
    func advanceSession() {
        guard let session, let day = plan(id: session.planID)?.day(session.day) else { return }
        setReading(session.readingIndex, day: session.day, of: session.planID, complete: true)
        let next = session.readingIndex + 1
        if day.readings.indices.contains(next) {
            openReading(next, day: session.day, of: session.planID)
        }
    }

    /// Marks the session's whole day read.
    func finishSessionDay() {
        guard let session else { return }
        setDay(session.day, of: session.planID, complete: true)
    }

    func endSession() {
        session = nil
    }

    /// Called with verses that have been on screen long enough to count as read, from any
    /// reader. Readings of each plan's current day are checked off once enough of them has
    /// been read, so following a plan needs no extra taps.
    func versesRead(_ updates: Set<SeenVerseUpdate>) {
        guard !updates.isEmpty else { return }
        for (plan, enrollment) in activePlans {
            guard let day = currentDay(of: plan) else { continue }
            for (index, reading) in day.readings.enumerated()
            where enrollment.completedReadings[day.day]?.contains(index) != true {
                let matching = updates.filter { $0.bookName == reading.book && reading.contains(chapter: $0.chapter) }
                guard !matching.isEmpty else { continue }

                let required = reading.verses(verseCounts: verseCountsForBook(reading.book))
                guard let last = required.last else { continue }
                let requiredKeys = Set(required.map { "\($0.chapter):\($0.verse)" })
                let key = Self.readingKey(planID: plan.id, startedAt: enrollment.startedAt, day: day.day, index: index)
                viewedVerses[key, default: []].formUnion(
                    matching.map { "\($0.chapter):\($0.verse)" }.filter(requiredKeys.contains)
                )

                let viewed = viewedVerses[key] ?? []
                if viewed.contains("\(last.chapter):\(last.verse)"),
                   Double(viewed.count) >= Double(requiredKeys.count) * Self.readThreshold {
                    viewedVerses[key] = nil
                    setReading(index, day: day.day, of: plan.id, complete: true)
                }
            }
        }
    }

    private static func readingKey(planID: String, startedAt: Date, day: Int, index: Int) -> String {
        "\(planID)|\(startedAt.timeIntervalSinceReferenceDate)|\(day)|\(index)"
    }

    // MARK: - Today

    /// The reading the Today checklist should suggest: the most recent plan's next reading.
    func todaysReading() -> (plan: ReadingPlan, day: PlanDay, reading: PlanReading)? {
        guard let (plan, _) = activePlans.first, let day = currentDay(of: plan) else { return nil }
        let index = day.readings.indices.first { !isReadingComplete($0, day: day.day, planID: plan.id) } ?? 0
        guard let reading = day.readings[safe: index] else { return nil }
        return (plan, day, reading)
    }

    /// Whether a day of `planID` was checked off on `date`'s calendar day.
    func completedADay(of planID: String, on date: Date, calendar: Calendar = .current) -> Bool {
        guard let completedAt = enrollment(for: planID)?.lastDayCompletedAt else { return false }
        return calendar.isDate(completedAt, inSameDayAs: date)
    }

    // MARK: - Sync

    /// Combines a copy from iCloud with this device's. Returns the merged copy.
    @discardableResult
    func merge(remote: ReadingPlansDocument) -> ReadingPlansDocument {
        let merged = ReadingPlansDocument.merged(document, remote)
        if merged != document {
            document = merged
            saveLocally()
            afterChange()
        }
        return merged
    }

    func encodedDocument() -> Data? {
        try? JSONEncoder().encode(document)
    }

    static func decode(_ data: Data?) -> ReadingPlansDocument? {
        guard let data else { return nil }
        return PersistedDecoding.decode(ReadingPlansDocument.self, from: data, name: storageKey)
    }

    // MARK: - Saving

    private func saveSession() {
        if let session, let data = try? JSONEncoder().encode(session) {
            defaults.set(data, forKey: Self.sessionKey)
        } else {
            defaults.removeObject(forKey: Self.sessionKey)
        }
    }

    private func save() {
        saveLocally()
        guard publishesChanges else { return }
        iCloudSyncCoordinator.shared.pushKey(Self.storageKey)
        afterChange()
    }

    private func saveLocally() {
        guard let data = encodedDocument() else {
            readingPlanLogger.error("Couldn't encode reading plan progress.")
            return
        }
        defaults.set(data, forKey: Self.storageKey)
    }

    private func afterChange() {
        guard publishesChanges else { return }
        ReadingPlanWidgetMirror.update(from: self)
        Task { await ReadingPlanReminderScheduler.refresh() }
    }

    // MARK: - Catalog

    private struct Catalog: Decodable {
        let plans: [ReadingPlan]
    }

    static func loadCatalog(bundle: Bundle = .main) -> [ReadingPlan] {
        guard let url = bundle.url(forResource: "ReadingPlans", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let catalog = PersistedDecoding.decode(Catalog.self, from: data, name: "ReadingPlans.json") else {
            readingPlanLogger.error("ReadingPlans.json is missing or invalid; reading plans are unavailable.")
            assertionFailure("ReadingPlans.json is missing or invalid.")
            return []
        }
        return catalog.plans
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
