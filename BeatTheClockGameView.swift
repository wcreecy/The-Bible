import SwiftUI
import UIKit
import Combine

struct BeatTheClockGameView: View {
    enum Difficulty: String, CaseIterable, Identifiable { case easy, normal, hard; var id: String { rawValue } }
    enum Category: String, CaseIterable, Identifiable { case people = "People", places = "Places", both = "Both"; var id: String { rawValue } }

    @State private var started: Bool = false
    @State private var howToExpanded: Bool = false
    @State private var difficultyExpanded: Bool = false
    @AppStorage("beatTheClockDifficulty") private var difficulty: Difficulty = .normal
    @AppStorage("beatTheClockCategory") private var category: Category = .people

    // Global Auto‑Win debug toggle
    @AppStorage("debugAutoWinEnabled") private var debugAutoWinEnabled: Bool = false

    // Data
    @State private var loadedPeople: [BibleName] = []
    @State private var loadedPlaces: [BibleLocation] = []

    // Current round
    @State private var targetLabel: String = ""
    @State private var referenceBookName: String? = nil
    @State private var currentEntryIsPerson: Bool = true

    // Timer
    @State private var remainingSeconds: Int = 0
    @State private var roundResultIsCorrect: Bool?
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // Scoring
    @State private var score: Int = 0
    @State private var answered: Int = 0

    @State private var currentStreak: Int = 0
    @State private var currentBestStreak: Int = 0

    // Read combined all-time stats (shared across difficulties)
    private var allTimeCorrect: Int { UserDefaults.standard.integer(forKey: "beatclockAllTimeCorrect_all") }
    private var allTimeAnswered: Int { UserDefaults.standard.integer(forKey: "beatclockAllTimeAnswered_all") }
    private var allTimeBestStreak: Int { UserDefaults.standard.integer(forKey: "beatclockAllTimeBestStreak_all") }

    // Search
    @State private var searchText: String = ""
    @State private var selectionLocked: Bool = false
    @FocusState private var searchFieldFocused: Bool
    @State private var acceptableBooks: Set<String> = []
    @State private var showAnswers: Bool = false
    @State private var pulse: Bool = false
    @State private var timerOnLeft: Bool = false
    @State private var usesMutedTimerStyle: Bool = false

    private var allBookNames: [String] { BibleData.books.map { $0.name } }

    private var filteredBooks: [String] {
        let text = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return [] }
        return allBookNames.filter { $0.localizedCaseInsensitiveContains(text) }.sorted()
    }

    private var roundTime: Int {
        switch difficulty {
        case .easy: return 25
        case .normal: return 15
        case .hard: return 8
        }
    }

    private var canSubmit: Bool {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !selectionLocked && !trimmed.isEmpty
    }

    // MARK: - Persistent streak helpers (per difficulty)
    private func persistentSuffix() -> String {
        switch difficulty {
        case .easy: return "easy"
        case .normal: return "normal"
        case .hard: return "hard"
        }
    }
    private func persistentStreakKey() -> String { "beatclockPersistentStreak_\(persistentSuffix())" }
    private func persistentBestKey() -> String { "beatclockPersistentBestStreak_\(persistentSuffix())" }

    private func readPersistentStreak() -> Int {
        max(0, UserDefaults.standard.integer(forKey: persistentStreakKey()))
    }
    private func writePersistentStreak(_ value: Int) {
        let v = max(0, value)
        let key = persistentStreakKey()
        UserDefaults.standard.set(v, forKey: key)
        iCloudSyncCoordinator.shared.pushKey(key)
    }
    private func readPersistentBest() -> Int {
        max(0, UserDefaults.standard.integer(forKey: persistentBestKey()))
    }
    private func writePersistentBest(_ value: Int) {
        let v = max(0, value)
        let key = persistentBestKey()
        UserDefaults.standard.set(v, forKey: key)
        iCloudSyncCoordinator.shared.pushKey(key)
    }
    private func seedStreakFromPersistence() {
        let persisted = readPersistentStreak()
        currentStreak = persisted
        let persistedBest = readPersistentBest()
        currentBestStreak = max(currentBestStreak, persistedBest)
    }

    var body: some View {
        GeometryReader { geometry in
            let usesSplitLayout = started && geometry.size.width >= 700

            ZStack {
                ScrollView {
                    VStack(spacing: 16) {
                if !started {
                    Spacer(minLength: 32)
                    Text("Type a Bible book that mentions the shown person or place before the timer runs out.")
                        .gameStartDescriptionStyle(title: "Beat the Clock", systemImage: "hourglass", tint: .indigo)

                    GameStartInfoLayout {
                        GroupBox {
                            DisclosureGroup(isExpanded: $howToExpanded) {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("• Choose a category and difficulty, then tap Start.")
                                    Text("• You'll see a person or place; type a Bible book that mentions it.")
                                    Text("• Submit before the timer hits zero. Suggestions appear as you type.")
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            } label: {
                                Text("How to Play").font(.headline)
                            }
                        }

                        GroupBox {
                            DisclosureGroup(isExpanded: $difficultyExpanded) {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("• Easy: 25 seconds per round.")
                                    Text("• Normal: 15 seconds per round.")
                                    Text("• Hard: 8 seconds per round.")
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            } label: {
                                Text("Difficulty Settings").font(.headline)
                            }
                        }

                        GameStartCurrentGameCard {
                            GameStartCurrentGameRow(label: "Category", value: category.rawValue)
                            GameStartCurrentGameRow(
                                label: "Difficulty",
                                value: difficulty.rawValue.capitalized
                            )
                            GameStartCurrentGameRow(
                                label: "Time Limit",
                                value: "\(roundTime) seconds per round"
                            )
                        }
                    }
                    .gameStartOptionsStyle()
                    .padding(.horizontal)

                    GameStartSettingsLayout {
                        GameStartPickerCard(
                            title: "Category",
                            selection: $category,
                            options: Category.allCases
                        ) { category in
                            Text(category.rawValue)
                        }

                        GameStartPickerCard(
                            title: "Difficulty",
                            selection: $difficulty,
                            options: Difficulty.allCases
                        ) { difficulty in
                            Text(difficulty.rawValue.capitalized)
                        }
                    }
                    .padding(.horizontal)

                    GameLobbyPreview(kind: .beatTheClock)

                    GameStartActionBar(action: startGame)
                    GameSetupSummary(
                        summary: "You’ll be shown \(category == .both ? "people and places" : category.rawValue.lowercased()) from the Bible and have \(roundTime) seconds to name a book that mentions each one."
                    )
                    Spacer(minLength: 32)
                } else {
                    if usesSplitLayout {
                        BeatTheClockGameDashboard(
                            score: score,
                            answered: answered,
                            streak: currentStreak,
                            allTimeCorrect: allTimeCorrect,
                            allTimeAnswered: allTimeAnswered,
                            allTimeBestStreak: allTimeBestStreak,
                            targetType: currentEntryIsPerson ? "Person" : "Place",
                            targetLabel: targetLabel,
                            timerColor: timerColor,
                            selectionLocked: selectionLocked,
                            searchText: $searchText,
                            searchFieldFocused: $searchFieldFocused,
                            filteredBooks: Array(filteredBooks.prefix(8)),
                            acceptableBookCount: acceptableBooks.count,
                            canSubmit: canSubmit,
                            showsDebugWin: debugAutoWinEnabled,
                            availableHeight: geometry.size.height - 32,
                            onClear: {
                                searchText = ""
                                searchFieldFocused = true
                            },
                            onSelectBook: { name in
                                searchText = name
                                submit(bookName: name)
                                searchFieldFocused = false
                            },
                            onSubmit: submitCurrentEntry,
                            onNext: nextRound,
                            onShowAnswers: { showAnswers = true },
                            onDebugWin: { endRound(correct: true) }
                        )
                    } else {
                    GameScoreboardCard(
                        currentCorrect: score,
                        currentAnswered: answered,
                        currentStreak: currentStreak,
                        game: .beatclock
                    )

                    GroupBox {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(currentEntryIsPerson ? "Person" : "Place")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(targetLabel)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .lineLimit(2)
                                .minimumScaleFactor(0.75)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(
                                selectionLocked ? Color.primary.opacity(0.12) : timerColor,
                                lineWidth: selectionLocked ? 1 : 2
                            )
                    )
                    .animation(.easeInOut(duration: 0.25), value: remainingSeconds)

                    if !usesSplitLayout {
                        GameTimerCard(
                            remainingSeconds: remainingSeconds,
                            tint: timerColor,
                            isPulsing: pulse
                        )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Type a Bible book")
                            .font(.headline)
                        HStack(spacing: 8) {
                            TextField("Start typing…", text: $searchText)
                                .textInputAutocapitalization(.words)
                                .disableAutocorrection(true)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit { submitCurrentEntry() }
                                .focused($searchFieldFocused)
                                .disabled(selectionLocked)

                            Button(action: {
                                let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !trimmed.isEmpty else { return }
                                searchText = ""
                                searchFieldFocused = true
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title3)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectionLocked ? Color.secondary : Color.red)
                            .disabled(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectionLocked)
                            .accessibilityLabel("Clear input")
                        }

                        if !filteredBooks.isEmpty {
                            VStack(spacing: 6) {
                                ForEach(filteredBooks.prefix(8), id: \.self) { name in
                                    Button(action: {
                                        searchText = name
                                        submit(bookName: name)
                                        searchFieldFocused = false
                                    }) {
                                        HStack {
                                            Text(name)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                        .contentShape(Rectangle())
                                        .background(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(Color(.secondarySystemBackground))
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(selectionLocked)
                                }
                            }
                        }
                    }

                    if selectionLocked {
                        GameRoundNavigationButtons(
                            canGoPrevious: false,
                            canGoNext: true,
                            onPrevious: {},
                            onNext: nextRound
                        )
                    } else {
                        Button("Submit", systemImage: "paperplane.fill") {
                            submitCurrentEntry()
                        }
                        .buttonStyle(GameProminentButtonStyle(tint: .green))
                        .disabled(!canSubmit)
                    }
                    if selectionLocked {
                        Button("Show answers (\(acceptableBooks.count))") { showAnswers = true }
                            .buttonStyle(ModernPillButtonStyle(tint: .accentColor))
                    }

                    if debugAutoWinEnabled, started, !selectionLocked {
                        Button("WIN") {
                            endRound(correct: true)
                        }
                        .buttonStyle(ModernPillButtonStyle(tint: .red))
                        .controlSize(.large)
                        .padding(.top, 6)
                        .accessibilityLabel("Win this round")
                    }
                    }
                }
                    }
                    .padding()
                }
                .frame(width: usesSplitLayout ? geometry.size.width / 2 : geometry.size.width)
                .frame(
                    maxWidth: .infinity,
                    alignment: usesSplitLayout && timerOnLeft ? .trailing : .leading
                )

                if usesSplitLayout {
                    BeatTheClockLargeTimerView(
                        remainingSeconds: remainingSeconds,
                        tint: timerColor,
                        isPulsing: pulse,
                        resultIsCorrect: roundResultIsCorrect,
                        usesMutedStyle: $usesMutedTimerStyle,
                        onSwapSides: {
                            withAnimation(.snappy) {
                                timerOnLeft.toggle()
                            }
                        }
                    )
                    .frame(width: geometry.size.width / 2)
                    .frame(maxWidth: .infinity, alignment: timerOnLeft ? .leading : .trailing)
                }
            }
        }
        .background(AppBackgroundView(tab: .games))
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                if started {
                    GameNavigationTitle(title: "Beat the Clock", systemImage: "hourglass", tint: .indigo)
                }
            }
        }
        .task {
            if loadedPeople.isEmpty {
                let people = await GameDataLoaders.loadNamesAsync()
                loadedPeople = people
            }
            if loadedPlaces.isEmpty {
                let places = await GameDataLoaders.loadLocationsAsync()
                loadedPlaces = places
            }
        }
        .onAppear {
            // Seed streaks from persisted values so they survive navigation/relaunch
            seedStreakFromPersistence()
        }
        .onChange(of: difficulty) { _, _ in
            // Switch to this difficulty’s persisted streaks
            seedStreakFromPersistence()
        }
        .onReceive(timer) { _ in
            guard started, !selectionLocked else { return }
            if remainingSeconds > 0 {
                pulse = true
                if remainingSeconds <= 5 {
                    let generator = UIImpactFeedbackGenerator(style: .heavy)
                    generator.impactOccurred()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    pulse = false
                }
                remainingSeconds -= 1
            }
            if remainingSeconds == 0 {
                endRound(correct: false)
            }
        }
        .sheet(isPresented: $showAnswers) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 12) {
                    if acceptableBooks.isEmpty {
                        Text("No matches found in the Bible text for this entry.")
                            .foregroundStyle(.secondary)
                    } else {
                        let canon = BibleCanon.canonicalOrder()
                        let order = Dictionary(uniqueKeysWithValues: canon.enumerated().map { ($1, $0) })
                        let books = Array(acceptableBooks).sorted { (lhs, rhs) in (order[lhs] ?? Int.max) < (order[rhs] ?? Int.max) }
                        List(books, id: \.self) { name in
                            Text(name)
                        }
                        .listStyle(.insetGrouped)
                    }
                    Spacer(minLength: 0)
                }
                .padding()
                .navigationTitle("Acceptable Books")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showAnswers = false } } }
            }
        }
    }

    private var timerColor: Color {
        if remainingSeconds <= 5 { return .red }
        if remainingSeconds <= 10 { return .yellow }
        return .green
    }

    private func startGame() {
        score = 0
        answered = 0
        started = true
        // Do NOT reset persistent streaks here; seed from persistence
        seedStreakFromPersistence()
        nextRound()
    }

    private func nextRound() {
        selectionLocked = false
        searchText = ""
        remainingSeconds = roundTime
        acceptableBooks = []
        pulse = false
        roundResultIsCorrect = nil

        switch category {
        case .people:
            guard let entry = loadedPeople.randomElement() else { targetLabel = ""; referenceBookName = nil; return }
            currentEntryIsPerson = true
            targetLabel = entry.name
            referenceBookName = parseBookName(from: entry.firstReference)
        case .places:
            guard let entry = loadedPlaces.randomElement() else { targetLabel = ""; referenceBookName = nil; return }
            currentEntryIsPerson = false
            targetLabel = entry.location
            referenceBookName = parseBookName(from: entry.firstReference)
        case .both:
            let usePerson: Bool
            if loadedPeople.isEmpty && loadedPlaces.isEmpty {
                targetLabel = ""; referenceBookName = nil; return
            } else if loadedPeople.isEmpty {
                usePerson = false
            } else if loadedPlaces.isEmpty {
                usePerson = true
            } else {
                usePerson = Bool.random()
            }
            if usePerson, let entry = loadedPeople.randomElement() {
                currentEntryIsPerson = true
                targetLabel = entry.name
                referenceBookName = parseBookName(from: entry.firstReference)
            } else if let entry = loadedPlaces.randomElement() {
                currentEntryIsPerson = false
                targetLabel = entry.location
                referenceBookName = parseBookName(from: entry.firstReference)
            } else {
                targetLabel = ""; referenceBookName = nil; return
            }
        }
        acceptableBooks = booksMentioning(targetLabel)
        if let ref = referenceBookName { acceptableBooks.insert(ref) }
        DispatchQueue.main.async {
            self.searchFieldFocused = true
        }
    }

    private func submitCurrentEntry() {
        let name = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        submit(bookName: name)
    }

    private func submit(bookName: String) {
        guard !selectionLocked else { return }
        selectionLocked = true
        answered += 1
        let normalized = normalize(bookName)
        let accepted = acceptableBooks.contains { normalize($0) == normalized }
        if accepted {
            score += 1

            // Persistent streak: increment on correct
            let persisted = readPersistentStreak() + 1
            writePersistentStreak(persisted)
            currentStreak = persisted

            // Update persistent best if needed
            let bestPersisted = readPersistentBest()
            if persisted > bestPersisted {
                writePersistentBest(persisted)
            }
            currentBestStreak = max(currentBestStreak, persisted, readPersistentBest())

            GameStats.shared.recordRound(
                game: .beatclock,
                difficulty: mapDifficulty(difficulty),
                correct: 1,
                answered: 1,
                currentBestStreak: currentBestStreak
            )

            // NEW: Per-type stat write (People/Places)
            let typeName = currentEntryIsPerson ? "People" : "Places"
            GameStats.shared.recordBeatClockType(type: typeName, answered: 1, correct: 1)

            let generator = UINotificationFeedbackGenerator(); generator.notificationOccurred(.success)
        } else {
            // Persistent streak: reset on incorrect
            writePersistentStreak(0)
            currentStreak = 0

            GameStats.shared.recordRound(
                game: .beatclock,
                difficulty: mapDifficulty(difficulty),
                correct: 0,
                answered: 1,
                currentBestStreak: currentBestStreak
            )

            // NEW: Per-type stat write (People/Places)
            let typeName = currentEntryIsPerson ? "People" : "Places"
            GameStats.shared.recordBeatClockType(type: typeName, answered: 1, correct: 0)

            let generator = UINotificationFeedbackGenerator(); generator.notificationOccurred(.error)
        }
    }

    private func endRound(correct: Bool) {
        guard !selectionLocked else { return }
        selectionLocked = true
        roundResultIsCorrect = correct
        answered += 1
        if correct {
            score += 1

            // Persistent streak: increment on correct
            let persisted = readPersistentStreak() + 1
            writePersistentStreak(persisted)
            currentStreak = persisted

            // Update persistent best if needed
            let bestPersisted = readPersistentBest()
            if persisted > bestPersisted {
                writePersistentBest(persisted)
            }
            currentBestStreak = max(currentBestStreak, persisted, readPersistentBest())

            GameStats.shared.recordRound(
                game: .beatclock,
                difficulty: mapDifficulty(difficulty),
                correct: 1,
                answered: 1,
                currentBestStreak: currentBestStreak
            )

            // NEW: Per-type stat write (People/Places)
            let typeName = currentEntryIsPerson ? "People" : "Places"
            GameStats.shared.recordBeatClockType(type: typeName, answered: 1, correct: 1)
        } else {
            // Persistent streak: reset on incorrect
            writePersistentStreak(0)
            currentStreak = 0

            GameStats.shared.recordRound(
                game: .beatclock,
                difficulty: mapDifficulty(difficulty),
                correct: 0,
                answered: 1,
                currentBestStreak: currentBestStreak
            )

            // NEW: Per-type stat write (People/Places)
            let typeName = currentEntryIsPerson ? "People" : "Places"
            GameStats.shared.recordBeatClockType(type: typeName, answered: 1, correct: 0)
        }
    }

    private func parseBookName(from reference: String?) -> String? {
        guard let ref = reference, !ref.isEmpty else { return nil }
        let parts = ref.split { $0.isWhitespace }
        guard parts.count >= 2 else { return nil }
        let book = parts.dropLast().joined(separator: " ")
        return book
    }

    private func normalize(_ s: String) -> String {
        s.lowercased().replacingOccurrences(of: " ", with: "")
    }

    private func booksMentioning(_ term: String) -> Set<String> {
        let needle = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return [] }
        let lowerNeedle = needle.lowercased()
        var set: Set<String> = []
        for book in BibleData.books {
            outer: for chapter in book.chapters {
                for verse in chapter.verses {
                    if verse.text.lowercased().contains(lowerNeedle) {
                        set.insert(book.name)
                        break outer
                    }
                }
            }
        }
        return set
    }

    private func percentString(correct: Int, answered: Int) -> String {
        guard answered > 0 else { return "0%" }
        let pct = Int(round((Double(correct) / Double(answered)) * 100.0))
        return "\(pct)%"
    }

    private func mapDifficulty(_ d: Difficulty) -> GameStats.Difficulty {
        switch d {
        case .easy: return .easy
        case .normal: return .normal
        case .hard: return .hard
        }
    }
}

private struct BeatTheClockGameDashboard: View {
    let score: Int
    let answered: Int
    let streak: Int
    let allTimeCorrect: Int
    let allTimeAnswered: Int
    let allTimeBestStreak: Int
    let targetType: String
    let targetLabel: String
    let timerColor: Color
    let selectionLocked: Bool
    @Binding var searchText: String
    let searchFieldFocused: FocusState<Bool>.Binding
    let filteredBooks: [String]
    let acceptableBookCount: Int
    let canSubmit: Bool
    let showsDebugWin: Bool
    let availableHeight: CGFloat
    let onClear: () -> Void
    let onSelectBook: (String) -> Void
    let onSubmit: () -> Void
    let onNext: () -> Void
    let onShowAnswers: () -> Void
    let onDebugWin: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            BeatTheClockDashboardScoreboard(
                score: score,
                answered: answered,
                streak: streak,
                allTimeCorrect: allTimeCorrect,
                allTimeAnswered: allTimeAnswered,
                allTimeBestStreak: allTimeBestStreak
            )

            BeatTheClockDashboardPrompt(
                targetType: targetType,
                targetLabel: targetLabel,
                tint: timerColor,
                isLocked: selectionLocked
            )

            BeatTheClockDashboardAnswer(
                searchText: $searchText,
                searchFieldFocused: searchFieldFocused,
                filteredBooks: filteredBooks,
                isLocked: selectionLocked,
                onClear: onClear,
                onSelectBook: onSelectBook
            )

            Spacer(minLength: 0)

            BeatTheClockDashboardActions(
                isLocked: selectionLocked,
                canSubmit: canSubmit,
                acceptableBookCount: acceptableBookCount,
                showsDebugWin: showsDebugWin,
                onSubmit: onSubmit,
                onNext: onNext,
                onShowAnswers: onShowAnswers,
                onDebugWin: onDebugWin
            )
        }
        .padding(.horizontal, AppDesignMetrics.cardPadding)
        .padding(.bottom, AppDesignMetrics.cardPadding)
        .padding(.top, AppDesignMetrics.cardPadding + 12)
        .frame(maxWidth: .infinity, minHeight: availableHeight, alignment: .top)
        .heroCardSurface()
    }
}

private struct BeatTheClockDashboardScoreboard: View {
    let score: Int
    let answered: Int
    let streak: Int
    let allTimeCorrect: Int
    let allTimeAnswered: Int
    let allTimeBestStreak: Int

    private var accuracy: Int {
        guard answered > 0 else { return 0 }
        return Int((Double(score) / Double(answered) * 100).rounded())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("This Game", systemImage: "chart.bar.fill")
                    .font(.headline.weight(.bold))

                Spacer()

                Text("All time: \(allTimeCorrect)/\(allTimeAnswered)  •  Best streak \(allTimeBestStreak)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                BeatTheClockScoreMetric(title: "Correct", value: "\(score)", systemImage: "checkmark.circle.fill", tint: .green)
                BeatTheClockScoreMetric(title: "Attempts", value: "\(answered)", systemImage: "scope", tint: .blue)
                BeatTheClockScoreMetric(title: "Accuracy", value: "\(accuracy)%", systemImage: "percent", tint: .purple)
                BeatTheClockScoreMetric(title: "Streak", value: "\(streak)", systemImage: "flame.fill", tint: .orange)
            }
        }
        .padding(16)
        .background(.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: AppDesignMetrics.cardCornerRadius, style: .continuous))
    }
}

private struct BeatTheClockScoreMetric: View {
    let title: LocalizedStringKey
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(tint)

            Text(value)
                .font(.title2.weight(.bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(tint.opacity(0.09), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }
}

private struct BeatTheClockDashboardPrompt: View {
    let targetType: String
    let targetLabel: String
    let tint: Color
    let isLocked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(targetType, systemImage: targetType == "Person" ? "person.fill" : "mappin.and.ellipse")
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
                .textCase(.uppercase)

            Text(targetLabel)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .lineLimit(2)
                .minimumScaleFactor(0.65)

            Text("Name a Bible book that mentions this \(targetType.lowercased()).")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(tint.opacity(isLocked ? 0.05 : 0.11), in: RoundedRectangle(cornerRadius: AppDesignMetrics.cardCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppDesignMetrics.cardCornerRadius, style: .continuous)
                .strokeBorder(isLocked ? Color.primary.opacity(0.12) : tint.opacity(0.8), lineWidth: isLocked ? 1 : 2)
        }
        .animation(.easeInOut(duration: 0.25), value: tint)
    }
}

private struct BeatTheClockDashboardAnswer: View {
    @Binding var searchText: String
    let searchFieldFocused: FocusState<Bool>.Binding
    let filteredBooks: [String]
    let isLocked: Bool
    let onClear: () -> Void
    let onSelectBook: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Your Answer", systemImage: "square.and.pencil")
                .font(.headline.weight(.bold))

            HStack(spacing: 10) {
                Image(systemName: "book.closed.fill")
                    .foregroundStyle(.tint)

                TextField("Type a Bible book…", text: $searchText)
                    .font(.title3.weight(.medium))
                    .textInputAutocapitalization(.words)
                    .disableAutocorrection(true)
                    .textFieldStyle(.plain)
                    .focused(searchFieldFocused)
                    .disabled(isLocked)

                if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button("Clear answer", systemImage: "xmark.circle.fill", action: onClear)
                        .labelStyle(.iconOnly)
                        .buttonStyle(.plain)
                        .foregroundStyle(isLocked ? Color.secondary : Color.red)
                        .disabled(isLocked)
                }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 58)
            .glassEffect(.regular, in: .rect(cornerRadius: AppDesignMetrics.compactControlCornerRadius))

            if !filteredBooks.isEmpty {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(filteredBooks, id: \.self) { name in
                        Button {
                            onSelectBook(name)
                        } label: {
                            Text(name)
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 14)
                                .frame(minHeight: 42)
                                .contentShape(Rectangle())
                                .background(
                                    .primary.opacity(0.06),
                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(isLocked)
                    }
                }
            }
        }
    }
}

private struct BeatTheClockDashboardActions: View {
    let isLocked: Bool
    let canSubmit: Bool
    let acceptableBookCount: Int
    let showsDebugWin: Bool
    let onSubmit: () -> Void
    let onNext: () -> Void
    let onShowAnswers: () -> Void
    let onDebugWin: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            if isLocked {
                GameRoundNavigationButtons(
                    canGoPrevious: false,
                    canGoNext: true,
                    onPrevious: {},
                    onNext: onNext
                )
            } else {
                Button("Submit", systemImage: "paperplane.fill", action: onSubmit)
                    .buttonStyle(GameProminentButtonStyle(tint: .green))
                    .disabled(!canSubmit)
            }

            if isLocked {
                Button("Show \(acceptableBookCount) acceptable answers", systemImage: "books.vertical.fill", action: onShowAnswers)
                    .buttonStyle(GameProminentButtonStyle(tint: .accentColor))
            }

            if showsDebugWin && !isLocked {
                Button("Win this round", systemImage: "checkmark.seal.fill", action: onDebugWin)
                    .buttonStyle(.glass(.regular.tint(.red)))
            }
        }
    }
}

private struct BeatTheClockLargeTimerView: View {
    let remainingSeconds: Int
    let tint: Color
    let isPulsing: Bool
    let resultIsCorrect: Bool?
    @Binding var usesMutedStyle: Bool
    let onSwapSides: () -> Void

    private var timerTextColor: Color {
        remainingSeconds > 5 && remainingSeconds <= 10 ? .black : .white
    }

    private var isActive: Bool { resultIsCorrect == nil }

    private var displayTint: Color {
        guard let resultIsCorrect else { return tint }
        return resultIsCorrect ? .green : .red
    }

    private var vividTextColor: Color {
        isActive ? timerTextColor : .white
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)

            VStack(spacing: 24) {
                Image(systemName: statusSystemImage)
                    .font(.system(size: 72, weight: .semibold))
                    .foregroundStyle(usesMutedStyle ? displayTint : vividTextColor.opacity(0.85))

                Text(statusTitle)
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(usesMutedStyle ? displayTint : vividTextColor.opacity(0.85))

                if isActive {
                    Text("\(remainingSeconds)s")
                        .font(.system(size: 180, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .foregroundStyle(usesMutedStyle ? displayTint : vividTextColor)
                }
            }
            .scaleEffect(isPulsing ? 1.04 : 1.0)
            .animation(.easeOut(duration: 0.18), value: isPulsing)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(statusTitle)
            .accessibilityValue(isActive ? "\(remainingSeconds) seconds" : "")

            Spacer(minLength: 0)

            HStack(spacing: 12) {
                Button("Swap card sides", systemImage: "arrow.left.arrow.right", action: onSwapSides)

                Button(
                    usesMutedStyle ? "Use vivid timer background" : "Use muted timer background",
                    systemImage: "circle.lefthalf.filled"
                ) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        usesMutedStyle.toggle()
                    }
                }
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.glass(.clear))
            .controlSize(.small)
            .tint(usesMutedStyle ? displayTint : vividTextColor)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
        .background(
            usesMutedStyle ? Color.clear : displayTint,
            in: RoundedRectangle(
                cornerRadius: AppDesignMetrics.cardCornerRadius,
                style: .continuous
            )
        )
        .heroCardSurface()
        .padding(12)
        .animation(.easeInOut(duration: 0.25), value: remainingSeconds)
    }

    private var statusTitle: LocalizedStringKey {
        guard let resultIsCorrect else { return "Time Remaining" }
        return resultIsCorrect ? "Correct" : "Incorrect"
    }

    private var statusSystemImage: String {
        guard let resultIsCorrect else { return "timer" }
        return resultIsCorrect ? "checkmark.circle.fill" : "xmark.circle.fill"
    }
}
