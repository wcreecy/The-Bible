import Foundation
import Observation
import OSLog
import WidgetKit

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

    /// A plan reading opened in the reader, so the reader can offer the next one.
    struct Session: Equatable {
        let planID: String
        let day: Int
        let readingIndex: Int
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
    private(set) var session: Session?
    var latestCompletion: Completion?

    /// A reading counts as read once this share of its verses has been on screen, including
    /// its last verse. Verses skimmed past quickly aren't recorded, so it isn't all of them.
    static let readThreshold = 0.8

    /// Verses seen for each plan reading this launch, keyed by `readingKey`.
    @ObservationIgnored private var viewedVerses: [String: Set<String>] = [:]
    @ObservationIgnored private var cachedTerms: [BibleTerm]?
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard, catalog: [ReadingPlan]? = nil) {
        self.defaults = defaults
        self.catalog = catalog ?? Self.loadCatalog()
        document = Self.decode(defaults.data(forKey: Self.storageKey)) ?? ReadingPlansDocument()
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

    // MARK: - Changing progress

    func start(_ planID: String, now: Date = Date()) {
        document.enrollments[planID] = PlanEnrollment(planID: planID, startedAt: now)
        save()
    }

    /// Starts over from day 1.
    func restart(_ planID: String, now: Date = Date()) {
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
            save()
        }
    }

    // MARK: - Custom plans

    /// The key passages of a book, for "Major Points" and "Skip Around".
    func highlights(forBook bookName: String) -> [CustomPlanGenerator.Highlight] {
        let terms = cachedTerms ?? BibleTermMatcher.loadTerms()
        cachedTerms = terms
        let references = terms.flatMap { term in
            term.references
                .filter { $0.type == "primary" }
                .map { (title: term.term, reference: $0.reference) }
        }
        return CustomPlanGenerator.highlights(
            from: references,
            bookName: bookName,
            verseCounts: Self.verseCounts(forBook: bookName)
        )
    }

    /// Builds a plan for `bookName`, saves it, and starts it. Returns its ID.
    @discardableResult
    func createCustomPlan(bookName: String, dayCount: Int, style: CustomPlanStyle, now: Date = Date()) -> String {
        let days = CustomPlanGenerator.makeDays(
            bookName: bookName,
            verseCounts: Self.verseCounts(forBook: bookName),
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

    /// Opens a plan reading in the reader and remembers it, so the reader can offer the next.
    func openReading(_ index: Int, day: Int, of planID: String) {
        guard let reading = plan(id: planID)?.day(day)?.readings[safe: index] else { return }
        session = Session(planID: planID, day: day, readingIndex: index)
        if var enrollment = enrollment(for: planID) {
            enrollment.lastActivityAt = Date()
            document.enrollments[planID] = enrollment
            saveLocally()
        }
        AppRouter.shared.openBibleReference(book: reading.book, chapter: reading.chapter, verse: reading.firstVerse)
    }

    /// Opens the plan's current day at its first unread reading.
    func continuePlan(_ planID: String) {
        guard let plan = plan(id: planID), let day = currentDay(of: plan) else { return }
        let index = day.readings.indices.first { !isReadingComplete($0, day: day.day, planID: planID) } ?? 0
        openReading(index, day: day.day, of: planID)
    }

    /// The session's reading when the reader is at its last chapter, where the reader offers
    /// what comes next.
    func sessionReading(atBook bookName: String, chapter: Int) -> (session: Session, plan: ReadingPlan, day: PlanDay, reading: PlanReading)? {
        guard let session,
              let plan = plan(id: session.planID),
              enrollment(for: session.planID) != nil,
              let day = plan.day(session.day),
              let reading = day.readings[safe: session.readingIndex],
              reading.book == bookName,
              reading.lastChapter == chapter else { return nil }
        return (session, plan, day, reading)
    }

    /// Marks the session's reading read and opens the day's next reading.
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

                let required = reading.verses(verseCounts: Self.verseCounts(forBook: reading.book))
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

    /// Whether a day of `planID` was finished on `date`'s calendar day.
    func finishedADay(of planID: String, on date: Date, calendar: Calendar = .current) -> Bool {
        guard let enrollment = document.enrollments[planID] else { return false }
        return calendar.isDate(enrollment.lastActivityAt, inSameDayAs: date) && !enrollment.completedDays.isEmpty
            && enrollment.completedReadings.isEmpty
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

    private func save() {
        saveLocally()
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
