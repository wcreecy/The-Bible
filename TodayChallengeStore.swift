import SwiftUI
import Foundation
import Combine

enum TodayChallengeKind: String, Codable {
    case readChapter
    case playGame
    case prayerTimer
    case reflection
}

struct TodayChallenge: Identifiable, Codable, Equatable {
    let id: UUID
    let kind: TodayChallengeKind
    let title: String
    let detail: String
    let bookName: String?
    let chapterNumber: Int?
    let gameName: String?
    let minimumMinutes: Int?
    var isCompleted: Bool
}

private struct TodayChallengeSnapshot: Codable {
    let dayKey: String
    var challenges: [TodayChallenge]
}


private struct TodayChallengeCatalog: Decodable {
    struct PrayerMinutes: Decodable {
        let minimum: Int
        let maximum: Int

        var range: ClosedRange<Int> {
            min(minimum, maximum)...max(minimum, maximum)
        }
    }

    struct ReflectionTask: Decodable {
        let title: String
        let detail: String
    }

    let gameNames: [String]
    let prayerMinutes: PrayerMinutes
    let prayerFocuses: [String]
    let reflectionTasks: [ReflectionTask]

    static func load() -> Self {
        guard let url = Bundle.main.url(forResource: "TodayChallengeCatalog", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let catalog = try? JSONDecoder().decode(Self.self, from: data),
              !catalog.gameNames.isEmpty,
              !catalog.prayerFocuses.isEmpty,
              !catalog.reflectionTasks.isEmpty else {
            assertionFailure("TodayChallengeCatalog.json is missing or invalid.")
            return fallback
        }

        return catalog
    }

    private static let fallback = Self(
        gameNames: ["Bible Quiz"],
        prayerMinutes: PrayerMinutes(minimum: 2, maximum: 20),
        prayerFocuses: ["peace"],
        reflectionTasks: [
            ReflectionTask(
                title: "Reflect on your blessings",
                detail: "Name three things you are grateful for."
            )
        ]
    )
}

@MainActor
final class TodayChallengeStore: ObservableObject {
    static let shared = TodayChallengeStore()

    @Published private(set) var challenges: [TodayChallenge] = []

    private let storageKey = "todayChallengesSnapshotV1"
    private let catalog = TodayChallengeCatalog.load()

    private init() {
        loadOrCreateForToday()
    }

    func refresh(readingProgress: ReadingProgress?) {
        loadOrCreateForToday()
        syncReadingProgress(readingProgress)
        syncGameProgress()
    }

    func recordReadingProgress(bookName: String, chapterNumber: Int) {
        loadOrCreateForToday()

        updateChallenges { challenge in
            challenge.kind == .readChapter &&
            challenge.bookName == bookName &&
            challenge.chapterNumber == chapterNumber
        }
    }

    func recordPrayerTimerCompletion(minutes: Int) {
        loadOrCreateForToday()

        updateChallenges { challenge in
            challenge.kind == .prayerTimer &&
            minutes >= (challenge.minimumMinutes ?? .max)
        }
    }

    func toggleManualChallenge(id: UUID) {
        loadOrCreateForToday()

        guard let index = challenges.firstIndex(where: { $0.id == id && $0.kind == .reflection }) else {
            return
        }

        challenges[index].isCompleted.toggle()
        save()
    }

    #if DEBUG
    func regenerateForDebug() {
        challenges = makeChallenges()
        save()
    }
    #endif

    private func syncReadingProgress(_ readingProgress: ReadingProgress?) {
        // ReadingProgress is only the saved resume location. A chapter task is
        // complete when every verse is recorded as read, regardless of whether
        // the person set a Continue Reading bookmark.
        guard let readingProgress else {
            syncCompletedReadingChallenges()
            return
        }

        recordReadingProgress(
            bookName: readingProgress.bookName,
            chapterNumber: readingProgress.chapterNumber
        )
        syncCompletedReadingChallenges()
    }

    private func syncCompletedReadingChallenges() {
        updateChallenges { challenge in
            guard challenge.kind == .readChapter,
                  let bookName = challenge.bookName,
                  let chapterNumber = challenge.chapterNumber,
                  let book = BibleData.books.first(where: { $0.name == bookName })
                    ?? BibleData.fallbackBooks.first(where: { $0.name == bookName }),
                  let chapter = book.chapters.first(where: { $0.number == chapterNumber }) else {
                return false
            }

            return BibleStatsStore.shared.isChapterComplete(
                bookName: bookName,
                chapter: chapterNumber,
                totalVerses: chapter.verses.count
            )
        }
    }

    private func syncGameProgress() {
        updateChallenges { challenge in
            guard challenge.kind == .playGame, let gameName = challenge.gameName else {
                return false
            }

            return (GameStats.shared.dailySeriesLast(days: 1, forDisplayName: gameName).last?.answered ?? 0) > 0
        }
    }

    private func loadOrCreateForToday() {
        let today = dayKey(for: Date())

        if let data = UserDefaults.standard.data(forKey: storageKey),
           let snapshot = try? JSONDecoder().decode(TodayChallengeSnapshot.self, from: data),
           snapshot.dayKey == today,
           snapshot.challenges.count == 3 {
            challenges = snapshot.challenges.map(repairedChallenge)
            if challenges != snapshot.challenges {
                save()
            }
        } else {
            challenges = makeChallenges()
            save()
        }
    }

    private func updateChallenges(where shouldComplete: (TodayChallenge) -> Bool) {
        var didChange = false

        for index in challenges.indices where !challenges[index].isCompleted && shouldComplete(challenges[index]) {
            challenges[index].isCompleted = true
            didChange = true
        }

        if didChange {
            save()
        }
    }

    private func save() {
        let snapshot = TodayChallengeSnapshot(dayKey: dayKey(for: Date()), challenges: challenges)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func dayKey(for date: Date) -> String {
        GameStats.localDayKey(for: date)
    }

    private func repairedChallenge(_ challenge: TodayChallenge) -> TodayChallenge {
        var challenge = challenge

        switch challenge.kind {
        case .readChapter where challenge.title == "Read (book.name) (chapter)":
            if let bookName = challenge.bookName, let chapterNumber = challenge.chapterNumber {
                challenge = TodayChallenge(
                    id: challenge.id,
                    kind: challenge.kind,
                    title: "Read \(bookName) \(chapterNumber)",
                    detail: challenge.detail,
                    bookName: challenge.bookName,
                    chapterNumber: challenge.chapterNumber,
                    gameName: challenge.gameName,
                    minimumMinutes: challenge.minimumMinutes,
                    isCompleted: challenge.isCompleted
                )
            }
        case .playGame where challenge.title == "Play (gameName)":
            if let gameName = challenge.gameName {
                challenge = TodayChallenge(
                    id: challenge.id,
                    kind: challenge.kind,
                    title: "Play \(gameName)",
                    detail: challenge.detail,
                    bookName: challenge.bookName,
                    chapterNumber: challenge.chapterNumber,
                    gameName: challenge.gameName,
                    minimumMinutes: challenge.minimumMinutes,
                    isCompleted: challenge.isCompleted
                )
            }
        case .prayerTimer where challenge.title == "Pray for (prayerMinutes) minutes":
            if let minimumMinutes = challenge.minimumMinutes {
                challenge = TodayChallenge(
                    id: challenge.id,
                    kind: challenge.kind,
                    title: "Pray for \(minimumMinutes) minutes",
                    detail: challenge.detail,
                    bookName: challenge.bookName,
                    chapterNumber: challenge.chapterNumber,
                    gameName: challenge.gameName,
                    minimumMinutes: challenge.minimumMinutes,
                    isCompleted: challenge.isCompleted
                )
            }
        default:
            break
        }

        return challenge
    }

    private func makeChallenges() -> [TodayChallenge] {
        let readingCount = Int.random(in: 1...2)
        var challenges: [TodayChallenge] = []
        var readingTargets = Set<String>()

        for _ in 0..<readingCount {
            let readingChallenge = makeReadingChallenge(excluding: readingTargets)
            if let bookName = readingChallenge.bookName,
               let chapterNumber = readingChallenge.chapterNumber {
                readingTargets.insert("\(bookName)-\(chapterNumber)")
            }
            challenges.append(readingChallenge)
        }

        challenges.append(makeReflectionChallenge())

        while challenges.count < 3 {
            challenges.append(Bool.random() ? makeGameChallenge() : makePrayerChallenge())
        }

        return challenges.shuffled()
    }

    private func makeReadingChallenge(excluding readingTargets: Set<String>) -> TodayChallenge {
        // The corpus loads asynchronously, so the cache can be empty during app launch.
        // Use the bundled fallback corpus until the full corpus is available.
        let availableBooks = BibleData.books.isEmpty ? BibleData.fallbackBooks : BibleData.books
        guard let initialBook = availableBooks.randomElement() else {
            assertionFailure("Bible fallback corpus must contain at least one book.")
            return TodayChallenge(
                id: UUID(),
                kind: .readChapter,
                title: "Read Genesis 1",
                detail: "Open the chapter to complete this.",
                bookName: "Genesis",
                chapterNumber: 1,
                gameName: nil,
                minimumMinutes: nil,
                isCompleted: false
            )
        }

        var book = initialBook
        var chapter = book.chapters.randomElement()?.number ?? 1

        for _ in 0..<10 {
            let target = "\(book.name)-\(chapter)"
            if !readingTargets.contains(target) {
                break
            }
            guard let nextBook = availableBooks.randomElement() else { break }
            book = nextBook
            chapter = book.chapters.randomElement()?.number ?? 1
        }

        return TodayChallenge(
            id: UUID(),
            kind: .readChapter,
            title: "Read \(book.name) \(chapter)",
            detail: "Open the chapter to complete this.",
            bookName: book.name,
            chapterNumber: chapter,
            gameName: nil,
            minimumMinutes: nil,
            isCompleted: false
        )
    }

    private func makeGameChallenge() -> TodayChallenge {
        let gameName = catalog.gameNames.randomElement() ?? "Bible Quiz"

        return TodayChallenge(
            id: UUID(),
            kind: .playGame,
            title: "Play \(gameName)",
            detail: "Finish a round to complete this.",
            bookName: nil,
            chapterNumber: nil,
            gameName: gameName,
            minimumMinutes: nil,
            isCompleted: false
        )
    }

    private func makePrayerChallenge() -> TodayChallenge {
        let prayerMinutes = Int.random(in: catalog.prayerMinutes.range)

        return TodayChallenge(
            id: UUID(),
            kind: .prayerTimer,
            title: "Pray for \(prayerMinutes) minutes",
            detail: "Complete a prayer timer to finish this.",
            bookName: nil,
            chapterNumber: nil,
            gameName: nil,
            minimumMinutes: prayerMinutes,
            isCompleted: false
        )
    }

    private func makeReflectionChallenge() -> TodayChallenge {
        let task = catalog.reflectionTasks.randomElement()
            ?? TodayChallengeCatalog.ReflectionTask(
                title: "Reflect on your blessings",
                detail: "Name three things you are grateful for."
            )
        let bookName = BibleData.books.randomElement()?.name
            ?? BibleData.fallbackBooks.randomElement()?.name
            ?? "Genesis"
        let prayerFocus = catalog.prayerFocuses.randomElement() ?? "peace"
        let title = task.title
            .replacingOccurrences(of: "{{bookName}}", with: bookName)
            .replacingOccurrences(of: "{{prayerFocus}}", with: prayerFocus)

        return TodayChallenge(
            id: UUID(),
            kind: .reflection,
            title: title,
            detail: task.detail,
            bookName: nil,
            chapterNumber: nil,
            gameName: nil,
            minimumMinutes: nil,
            isCompleted: false
        )
    }
}

struct HomeTodayCard: View {
    @ObservedObject private var store = TodayChallengeStore.shared

    let readingProgress: ReadingProgress?

    var body: some View {
        HeroCard(title: "Today", icon: "checklist", tint: .teal) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Three small ways to grow today")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 8)

                    #if DEBUG
                    Button {
                        store.regenerateForDebug()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Refresh Today challenges")
                    .accessibilityHint("Available only in debug builds.")
                    #endif
                }

                ForEach(store.challenges) { challenge in
                    TodayChallengeRow(challenge: challenge) {
                        store.toggleManualChallenge(id: challenge.id)
                    }
                }
            }
        }
        .onAppear {
            store.refresh(readingProgress: readingProgress)
        }
        .onReceive(NotificationCenter.default.publisher(for: .bibleStatsExternallyUpdated)) { _ in
            store.refresh(readingProgress: readingProgress)
        }
    }
}

private struct TodayChallengeRow: View {
    let challenge: TodayChallenge
    let toggleManualCompletion: () -> Void

    var body: some View {
        Group {
            if challenge.kind == .reflection {
                Button(action: toggleManualCompletion) {
                    rowContent
                }
                .buttonStyle(.plain)
            } else {
                rowContent
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
    }

    private var rowContent: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: challenge.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(challenge.isCompleted ? Color.green : Color.secondary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(challenge.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(challenge.isCompleted ? .secondary : .primary)
                    .strikethrough(challenge.isCompleted, color: .secondary)

                Text(challenge.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }

    private var accessibilityLabel: String {
        challenge.isCompleted ? "\(challenge.title), completed" : challenge.title
    }

    private var accessibilityHint: String {
        challenge.kind == .reflection && !challenge.isCompleted
            ? "Double tap to mark complete."
            : challenge.detail
    }
}
