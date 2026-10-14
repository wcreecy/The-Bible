import SwiftUI
import Foundation
import Observation

enum TodayChallengeKind: String, Codable {
    case readChapter
    case studyChapter
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
    var lastModified: Date
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
@Observable
final class TodayChallengeStore {
    static let shared = TodayChallengeStore()

    private(set) var challenges: [TodayChallenge] = []

    private let storageKey = "todayChallengesSnapshotV1"
    private let cloudStorageKey = "todayChallengesSnapshotV2"
    private let catalog = TodayChallengeCatalog.load()
    private let cloudStore = NSUbiquitousKeyValueStore.default
    @ObservationIgnored private var corpusWaitTask: Task<Void, Never>?

    private init() {
        cloudStore.synchronize()
        loadOrCreateForToday()
    }

    func refresh() {
        loadOrCreateForToday()
        // A chapter task is complete when every verse in it is recorded as read.
        syncCompletedReadingChallenges()
        syncGameProgress()
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

    func completeStudyChallenge(id: UUID) {
        loadOrCreateForToday()

        guard let index = challenges.firstIndex(where: { $0.id == id && $0.kind == .studyChapter }),
              !challenges[index].isCompleted else {
            return
        }

        challenges[index].isCompleted = true
        save()
    }

    #if DEBUG
    func regenerateForDebug() {
        challenges = makeChallenges()
        save()
    }
    #endif

    private func syncCompletedReadingChallenges() {
        updateChallenges { challenge in
            guard challenge.kind == .readChapter,
                  let bookName = challenge.bookName,
                  let chapterNumber = challenge.chapterNumber,
                  let book = BibleData.books.first(where: { $0.name == bookName }),
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

        let localSnapshot = snapshot(from: UserDefaults.standard.data(forKey: storageKey))
        let cloudSnapshot = snapshot(from: cloudStore.data(forKey: cloudStorageKey))

        if let cloudSnapshot,
           cloudSnapshot.dayKey == today,
           cloudSnapshot.challenges.count == 3 {
            let cloudChallenges = cloudSnapshot.challenges.map(repairedChallenge)
            challenges = cloudChallenges
            persistLocally(lastModified: cloudSnapshot.lastModified)

            if cloudChallenges != cloudSnapshot.challenges {
                save()
            }
        } else if let localSnapshot,
                  localSnapshot.dayKey == today,
                  localSnapshot.challenges.count == 3 {
            challenges = localSnapshot.challenges.map(repairedChallenge)
            if challenges != localSnapshot.challenges {
                save()
            } else {
                publishToCloud(localSnapshot)
            }
        } else if BibleData.books.isEmpty {
            // Reading challenges are drawn from the corpus, which loads asynchronously.
            // Creating them now would pick only from the small fallback corpus.
            createChallengesWhenCorpusLoads()
        } else {
            challenges = makeChallenges()
            save()
        }
    }

    private func createChallengesWhenCorpusLoads() {
        guard corpusWaitTask == nil else { return }
        corpusWaitTask = Task { [weak self] in
            _ = await BibleRepository.shared.loadAllBooks()
            guard let self else { return }
            corpusWaitTask = nil
            loadOrCreateForToday()
            syncCompletedReadingChallenges()
            syncGameProgress()
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
        let snapshot = TodayChallengeSnapshot(
            dayKey: dayKey(for: Date()),
            challenges: challenges,
            lastModified: Date()
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
        publishToCloud(snapshot)
    }

    private func snapshot(from data: Data?) -> TodayChallengeSnapshot? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(TodayChallengeSnapshot.self, from: data)
    }

    private func persistLocally(lastModified: Date) {
        let snapshot = TodayChallengeSnapshot(
            dayKey: dayKey(for: Date()),
            challenges: challenges,
            lastModified: lastModified
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func publishToCloud(_ snapshot: TodayChallengeSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        cloudStore.set(data, forKey: cloudStorageKey)

        Task.detached {
            NSUbiquitousKeyValueStore.default.synchronize()
        }
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
            switch Int.random(in: 0...2) {
            case 0:
                challenges.append(makeGameChallenge())
            case 1:
                challenges.append(makePrayerChallenge())
            default:
                challenges.append(makeStudyChallenge())
            }
        }

        return challenges.shuffled()
    }

    private func makeReadingChallenge(excluding readingTargets: Set<String>) -> TodayChallenge {
        // Challenges are only created once the corpus has loaded (see loadOrCreateForToday).
        let availableBooks = BibleData.books
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

    private func makeStudyChallenge() -> TodayChallenge {
        let readingChallenge = makeReadingChallenge(excluding: [])
        let bookName = readingChallenge.bookName ?? "Genesis"
        let chapterNumber = readingChallenge.chapterNumber ?? 1

        return TodayChallenge(
            id: UUID(),
            kind: .studyChapter,
            title: "Study \(bookName) \(chapterNumber)",
            detail: "Explore the chapter’s themes and background.",
            bookName: bookName,
            chapterNumber: chapterNumber,
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
        let bookName = BibleData.books.randomElement()?.name ?? "Genesis"
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
    private var store = TodayChallengeStore.shared
    @State private var studyChallenge: TodayChallenge?

    /// Starts the Home prayer timer for the given number of minutes.
    let onStartPrayerTimer: (Int) -> Void

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
                        perform(challenge)
                    }
                }
            }
        }
        .sheet(item: $studyChallenge) { challenge in
            NavigationStack {
                if let bookName = challenge.bookName, let chapterNumber = challenge.chapterNumber {
                    ChapterInsightsView(bookName: bookName, chapterNumber: chapterNumber)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") {
                                    studyChallenge = nil
                                }
                            }
                        }
                } else {
                    ContentUnavailableView("Study unavailable", systemImage: "text.book.closed")
                }
            }
        }
        .onAppear {
            store.refresh()
        }
        .onNotification(.bibleStatsExternallyUpdated) {
            store.refresh()
        }
        // Only the default key-value store posts this, so no object filter is needed.
        .onNotification(NSUbiquitousKeyValueStore.didChangeExternallyNotification) {
            store.refresh()
        }
    }

    /// Takes the person straight to the activity a challenge describes.
    private func perform(_ challenge: TodayChallenge) {
        switch challenge.kind {
        case .readChapter:
            guard let bookName = challenge.bookName, let chapter = challenge.chapterNumber else { return }
            Haptics.selection()
            AppRouter.shared.openBibleReference(book: bookName, chapter: chapter, verse: 1)
        case .studyChapter:
            guard challenge.bookName != nil, challenge.chapterNumber != nil else { return }
            Haptics.selection()
            store.completeStudyChallenge(id: challenge.id)
            studyChallenge = challenge
        case .playGame:
            guard let gameName = challenge.gameName else { return }
            Haptics.selection()
            GameLaunchRequest.open(gameName: gameName)
        case .prayerTimer:
            guard !challenge.isCompleted, let minutes = challenge.minimumMinutes else { return }
            Haptics.selection()
            onStartPrayerTimer(minutes)
        case .reflection:
            store.toggleManualChallenge(id: challenge.id)
        }
    }
}

private struct TodayChallengeRow: View {
    let challenge: TodayChallenge
    let action: () -> Void

    /// Completed prayer challenges have nothing left to start.
    private var isActionable: Bool {
        !(challenge.kind == .prayerTimer && challenge.isCompleted)
    }

    var body: some View {
        Button(action: action) {
            rowContent
        }
        .buttonStyle(.plain)
        .disabled(!isActionable)
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

            if let actionLabel {
                Label(actionLabel.title, systemImage: actionLabel.systemImage)
                    .labelStyle(.iconOnly)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .padding(.top, 2)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
    }

    /// The trailing affordance for rows that open another part of the app.
    private var actionLabel: (title: String, systemImage: String)? {
        switch challenge.kind {
        case .readChapter: ("Read", "book")
        case .studyChapter: ("Study", "text.book.closed")
        case .playGame: ("Play", "gamecontroller")
        case .prayerTimer: challenge.isCompleted ? nil : ("Start", "timer")
        case .reflection: nil
        }
    }

    private var accessibilityLabel: String {
        challenge.isCompleted ? "\(challenge.title), completed" : challenge.title
    }

    private var accessibilityHint: String {
        switch challenge.kind {
        case .readChapter:
            "Opens the chapter."
        case .studyChapter:
            "Opens chapter insights and marks this study complete."
        case .playGame:
            "Opens the game."
        case .prayerTimer:
            challenge.isCompleted ? "" : "Starts a prayer timer."
        case .reflection:
            challenge.isCompleted ? "Double tap to mark incomplete." : "Double tap to mark complete."
        }
    }
}
