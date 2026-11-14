import Foundation

/// One passage to read on a plan day. Chapter-only readings cover whole chapters;
/// `endChapter`, `startVerse`, and `endVerse` are inclusive, matching `ReadingPlans.json`.
nonisolated struct PlanReading: Codable, Hashable, Sendable {
    let book: String
    let chapter: Int
    var endChapter: Int?
    var startVerse: Int?
    var endVerse: Int?

    var lastChapter: Int { endChapter ?? chapter }

    /// The reading as it's shown everywhere, such as "Genesis 1–2" or "Genesis 12:1–9".
    /// Built here rather than with `PassageReference` so the widget and notifications,
    /// which can't reach the corpus, word it the same way.
    var title: String {
        switch (startVerse, endVerse) {
        case let (start?, end?) where chapter == lastChapter:
            return start == end ? "\(book) \(chapter):\(start)" : "\(book) \(chapter):\(start)–\(end)"
        case let (start?, end?):
            return "\(book) \(chapter):\(start)–\(lastChapter):\(end)"
        default:
            return chapter == lastChapter ? "\(book) \(chapter)" : "\(book) \(chapter)–\(lastChapter)"
        }
    }

    /// The verse the reader opens at.
    var firstVerse: Int { startVerse ?? 1 }

    /// Every verse the reading covers, given each chapter's verse count. Chapters the book
    /// doesn't have are left out.
    func verses(verseCounts: [Int]) -> [(chapter: Int, verse: Int)] {
        var result: [(chapter: Int, verse: Int)] = []
        for chapterNumber in chapter...max(chapter, lastChapter) {
            guard verseCounts.indices.contains(chapterNumber - 1) else { continue }
            let count = verseCounts[chapterNumber - 1]
            let first = chapterNumber == chapter ? (startVerse ?? 1) : 1
            let last = chapterNumber == lastChapter ? min(endVerse ?? count, count) : count
            guard first <= last else { continue }
            for verse in first...last {
                result.append((chapterNumber, verse))
            }
        }
        return result
    }

    /// Whether the reading includes any part of `chapterNumber`.
    func contains(chapter chapterNumber: Int) -> Bool {
        (chapter...max(chapter, lastChapter)).contains(chapterNumber)
    }
}

nonisolated struct PlanDay: Codable, Hashable, Sendable, Identifiable {
    let day: Int
    let title: String
    let readings: [PlanReading]
    var introduction: String?
    var reflectionQuestions: [String]?
    var takeaway: String?

    var id: Int { day }

    /// The day's readings on one line, such as "Genesis 12:1–9 · Genesis 15:1–6".
    var readingSummary: String {
        readings.map(\.title).joined(separator: " · ")
    }

    /// Whether the day has study notes to show (guided plans), or readings only.
    var hasGuide: Bool {
        introduction != nil || !(reflectionQuestions ?? []).isEmpty || takeaway != nil
    }
}

/// A reading plan from the bundled catalog or one the reader built.
nonisolated struct ReadingPlan: Codable, Hashable, Sendable, Identifiable {
    let id: String
    let title: String
    let description: String
    let category: String
    /// Plans meant to be read together in order, such as "Fruit of the Spirit". The library
    /// shows a series as one entry.
    var series: String?
    /// An SF Symbol for the plan's artwork; the category's is used when missing or unknown.
    var symbol: String?
    /// An image in the asset catalog to show instead of the drawn artwork, when there is one.
    var image: String?
    var difficulty: String?
    /// "guided" (with notes for each day) or "reading_schedule" (readings only).
    let planType: String
    let durationDays: Int
    let days: [PlanDay]

    static let customIDPrefix = "custom-"
    static let customCategory = "My Plans"

    var isCustom: Bool { id.hasPrefix(Self.customIDPrefix) }

    /// A long schedule (such as the Bible in a year) where pace is worth showing.
    var isSchedule: Bool { planType == "reading_schedule" }

    func day(_ number: Int) -> PlanDay? {
        days.first { $0.day == number }
    }

    /// "7 days", "1 day".
    var durationText: String {
        durationDays == 1 ? "1 day" : "\(durationDays) days"
    }
}

/// How a custom plan orders a book.
nonisolated enum CustomPlanStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Every chapter, front to back.
    case inOrder
    /// Only the book's key passages.
    case majorPoints
    /// The key passages first for an overview, then the rest of the book in order.
    case skipAround

    var id: String { rawValue }

    var title: String {
        switch self {
        case .inOrder: "In Order"
        case .majorPoints: "Major Points"
        case .skipAround: "Skip Around"
        }
    }

    var summary: String {
        switch self {
        case .inOrder: "Read every chapter from beginning to end."
        case .majorPoints: "Read only the book's key events and teachings."
        case .skipAround: "Start with the key passages for an overview, then read the rest of the book in order."
        }
    }

    var systemImage: String {
        switch self {
        case .inOrder: "list.number"
        case .majorPoints: "star"
        case .skipAround: "arrow.triangle.branch"
        }
    }

    /// Whether the style needs the book's key passages.
    var needsHighlights: Bool { self != .inOrder }
}

// MARK: - Progress (synced)

/// Someone's progress through one plan. Synced through iCloud as part of `ReadingPlansDocument`.
nonisolated struct PlanEnrollment: Codable, Equatable, Sendable {
    let planID: String
    /// When this run of the plan began. Restarting begins a new run.
    var startedAt: Date
    var completedDays: Set<Int> = []
    /// Readings finished on days that aren't complete yet, by day.
    var completedReadings: [Int: Set<Int>] = [:]
    var lastActivityAt: Date
    /// When a day was last checked off, so the reminder can skip days already read.
    var lastDayCompletedAt: Date?
    var finishedAt: Date?
    /// Set when the plan is stopped; kept so the stop reaches other devices.
    var isStopped = false
    /// Decides which copy wins when devices disagree about something other than progress.
    var updatedAt: Date

    init(planID: String, startedAt: Date) {
        self.planID = planID
        self.startedAt = startedAt
        lastActivityAt = startedAt
        updatedAt = startedAt
    }

    var isActive: Bool { !isStopped && finishedAt == nil }

    /// Combines two copies of the same plan's progress.
    ///
    /// Copies of the same run (same start) keep every day finished on either device, so
    /// reading on two devices never loses a day. Otherwise the plan was restarted or stopped
    /// on one device, and the most recent change wins.
    static func merged(_ a: PlanEnrollment, _ b: PlanEnrollment) -> PlanEnrollment {
        guard a.startedAt == b.startedAt else {
            return a.updatedAt >= b.updatedAt ? a : b
        }
        var merged = a.updatedAt >= b.updatedAt ? a : b
        merged.completedDays = a.completedDays.union(b.completedDays)
        var readings = a.completedReadings
        for (day, indices) in b.completedReadings {
            readings[day, default: []].formUnion(indices)
        }
        merged.completedReadings = readings.filter { !merged.completedDays.contains($0.key) }
        merged.lastActivityAt = max(a.lastActivityAt, b.lastActivityAt)
        merged.lastDayCompletedAt = [a.lastDayCompletedAt, b.lastDayCompletedAt].compactMap { $0 }.max()
        merged.finishedAt = [a.finishedAt, b.finishedAt].compactMap { $0 }.min()
        merged.updatedAt = max(a.updatedAt, b.updatedAt)
        return merged
    }
}

/// A plan the reader built for one book. The days are kept, not just the choices, so the
/// plan never changes under someone partway through it.
nonisolated struct CustomPlanRecord: Codable, Equatable, Sendable {
    let id: String
    let bookName: String
    let dayCount: Int
    let style: CustomPlanStyle
    /// Emptied when the plan is deleted, so the record that carries the deletion stays small.
    var days: [PlanDay]
    let createdAt: Date
    var updatedAt: Date
    var isDeleted = false

    var plan: ReadingPlan {
        ReadingPlan(
            id: id,
            title: "\(bookName) in \(dayCount == 1 ? "1 Day" : "\(dayCount) Days")",
            description: "\(style.title): \(style.summary)",
            category: ReadingPlan.customCategory,
            series: nil,
            difficulty: nil,
            planType: "custom",
            durationDays: days.count,
            days: days
        )
    }

    static func merged(_ a: CustomPlanRecord, _ b: CustomPlanRecord) -> CustomPlanRecord {
        a.updatedAt >= b.updatedAt ? a : b
    }
}

/// Everything about plans that syncs: progress and custom plans, each keyed by plan ID.
nonisolated struct ReadingPlansDocument: Codable, Equatable, Sendable {
    var enrollments: [String: PlanEnrollment] = [:]
    var customPlans: [String: CustomPlanRecord] = [:]

    /// Combines two copies record by record, so devices editing different plans never
    /// overwrite each other.
    static func merged(_ a: ReadingPlansDocument, _ b: ReadingPlansDocument) -> ReadingPlansDocument {
        var result = a
        for (id, enrollment) in b.enrollments {
            result.enrollments[id] = result.enrollments[id].map { PlanEnrollment.merged($0, enrollment) } ?? enrollment
        }
        for (id, record) in b.customPlans {
            result.customPlans[id] = result.customPlans[id].map { CustomPlanRecord.merged($0, record) } ?? record
        }
        return result
    }
}
