import SwiftUI
import Combine
import SwiftData

#if canImport(UIKit)
import UIKit
#endif

struct QuizView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var favorites: [Favorite]
    
    @AppStorage("quizScope") private var quizScopeRaw: String = "whole"
    @AppStorage("quizDifficulty") private var quizDifficulty: String = "easy"
    
    @AppStorage("quizAllTimeCorrect_easy") private var allTimeCorrectEasy: Int = 0
    @AppStorage("quizAllTimeAnswered_easy") private var allTimeAnsweredEasy: Int = 0
    @AppStorage("quizAllTimeBestStreak_easy") private var allTimeBestStreakEasy: Int = 0

    @AppStorage("quizAllTimeCorrect_normal") private var allTimeCorrectNormal: Int = 0
    @AppStorage("quizAllTimeAnswered_normal") private var allTimeAnsweredNormal: Int = 0
    @AppStorage("quizAllTimeBestStreak_normal") private var allTimeBestStreakNormal: Int = 0

    @AppStorage("quizAllTimeCorrect_hard") private var allTimeCorrectHard: Int = 0
    @AppStorage("quizAllTimeAnswered_hard") private var allTimeAnsweredHard: Int = 0
    @AppStorage("quizAllTimeBestStreak_hard") private var allTimeBestStreakHard: Int = 0

    // Global Auto‑Win debug toggle
    @AppStorage("debugAutoWinEnabled") private var debugAutoWinEnabled: Bool = false

    private var allTimeCorrect: Int {
        switch quizDifficulty {
        case "normal": return allTimeCorrectNormal
        case "hard": return allTimeCorrectHard
        default: return allTimeCorrectEasy
        }
    }

    private var allTimeAnswered: Int {
        switch quizDifficulty {
        case "normal": return allTimeAnsweredNormal
        case "hard": return allTimeAnsweredHard
        default: return allTimeAnsweredEasy
        }
    }

    private var allTimeBestStreak: Int {
        switch quizDifficulty {
        case "normal": return allTimeBestStreakNormal
        case "hard": return allTimeBestStreakHard
        default: return allTimeBestStreakEasy
        }
    }
    
    // Centralized write to GameStats (iCloud KVS mirrored)
    private func recordRound(correct: Int, answered: Int, bestStreak: Int) {
        let diff: GameStats.Difficulty
        switch quizDifficulty {
        case "normal": diff = .normal
        case "hard": diff = .hard
        default: diff = .easy
        }
        GameStats.shared.recordRound(
            game: .quiz,
            difficulty: diff,
            correct: correct,
            answered: answered,
            currentBestStreak: bestStreak
        )
    }

    // MARK: - Persistent streak helpers (per difficulty)
    private func streakSuffix() -> String {
        switch quizDifficulty {
        case "normal": return "normal"
        case "hard": return "hard"
        default: return "easy"
        }
    }
    private func persistentStreakKey() -> String { "quizPersistentStreak_\(streakSuffix())" }
    private func persistentBestKey() -> String { "quizPersistentBestStreak_\(streakSuffix())" }

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
        // Keep session best at least as high as persisted best
        let persistedBest = readPersistentBest()
        bestStreak = max(bestStreak, persistedBest)
    }
    
    private struct QuizQuestion: Identifiable {
        let id = UUID()
        let verseText: String
        let correctBook: String
        let chapter: Int
        let verse: Int
        let options: [String]
        var selected: String?
    }

    // MARK: - Canon sets for OT/NT
    private static let oldTestamentSet: Set<String> = [
        "Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy",
        "Joshua", "Judges", "Ruth", "1 Samuel", "2 Samuel", "1 Kings", "2 Kings",
        "1 Chronicles", "2 Chronicles", "Ezra", "Nehemiah", "Esther", "Job",
        "Psalms", "Proverbs", "Ecclesiastes", "Song of Solomon", "Isaiah",
        "Jeremiah", "Lamentations", "Ezekiel", "Daniel", "Hosea", "Joel",
        "Amos", "Obadiah", "Jonah", "Micah", "Nahum", "Habakkuk",
        "Zephaniah", "Haggai", "Zechariah", "Malachi"
    ]
    private static let newTestamentSet: Set<String> = [
        "Matthew", "Mark", "Luke", "John", "Acts", "Romans",
        "1 Corinthians", "2 Corinthians", "Galatians", "Ephesians",
        "Philippians", "Colossians", "1 Thessalonians", "2 Thessalonians",
        "1 Timothy", "2 Timothy", "Titus", "Philemon", "Hebrews",
        "James", "1 Peter", "2 Peter", "1 John", "2 John", "3 John",
        "Jude", "Revelation"
    ]

    // MARK: - Precomputed pools for current scope/difficulty
    private struct Pools {
        let books: [Book]              // filtered by scope
        let allNames: [String]         // names from books
        let oldNames: [String]         // intersection with OT
        let newNames: [String]         // intersection with NT
    }
    @State private var pools: Pools = .init(books: [], allNames: [], oldNames: [], newNames: [])

    private var isViewingPrevious: Bool {
        currentIndex >= 0 && currentIndex < history.count - 1
    }
    
    // Session / UI state
    @State private var started = false
    @State private var currentVerseText = ""
    @State private var correctBookName = ""
    @State private var options: [String] = []
    @State private var selectedOption: String? = nil
    @State private var score = 0
    @State private var questionNumber = 0
    @State private var sessionAnswered = 0
    @State private var currentChapterNumber: Int = 0
    @State private var currentVerseNumber: Int = 0
    
    @State private var currentStreak: Int = 0
    @State private var bestStreak: Int = 0
    @State private var showAnswerReveal: Bool = false

    // Timer
    @State private var remainingSeconds: Int = 0
    @State private var wasInRedZone: Bool = false
    @State private var pulseOn: Bool = false
    private let quizTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // History / navigation
    @State private var history: [QuizQuestion] = []
    @State private var currentIndex: Int = -1
    
    // Start screen disclosures
    @State private var howToExpanded: Bool = false
    @State private var difficultyExpanded: Bool = false

    // MARK: - Question buffer (prefetch)
    @State private var questionBuffer: [QuizQuestion] = []
    private let bufferSize: Int = 5
    private let refillThreshold: Int = 3
    @State private var isRefilling: Bool = false

    private var isPreviousEnabled: Bool {
        guard started, currentIndex > 0 else { return false }
        if currentIndex == history.count - 1, selectedOption == nil, (quizDifficulty == "normal" || quizDifficulty == "hard"), remainingSeconds > 0 {
            return false
        }
        return true
    }

    private var isNextEnabled: Bool {
        started && (selectedOption != nil || currentIndex < history.count - 1)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if !started {
                    Text("Test your knowledge by guessing the book of the Bible from a given verse.")
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        GroupBox {
                            DisclosureGroup(isExpanded: $howToExpanded) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("• Pick a verse source and difficulty, then tap Start.")
                                    Text("• Read the verse, then choose the correct book from the options.")
                                    Text("• In timed modes, answer before the clock runs out.")
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            } label: {
                                Text("How to Play").font(.headline)
                            }
                        }

                        GroupBox {
                            DisclosureGroup(isExpanded: $difficultyExpanded) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("• Easy: No timer; options from the whole scope.")
                                    Text("• Medium: 30 seconds per question.")
                                    Text("• Hard: 20 seconds; wrong options are from the same testament to increase challenge.")
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            } label: {
                                Text("Difficulty Levels").font(.headline)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    VStack(alignment: .center, spacing: 12) {
                        VStack(spacing: 6) {
                            Text("Verse Source")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Picker("Verse Source", selection: Binding<String>(get: { quizScopeRaw }, set: { new in
                                quizScopeRaw = new
                                rebuildPools()
                            })) {
                                Text("OT/NT").tag("whole")
                                Text("OT").tag("old")
                                Text("NT").tag("new")
                            }
                            .pickerStyle(.segmented)
                        }
                        VStack(spacing: 6) {
                            Text("Difficulty")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Picker("Difficulty", selection: Binding<String>(get: { quizDifficulty }, set: { new in
                                quizDifficulty = new
                                rebuildPools()
                            })) {
                                Text("Easy").tag("easy")
                                Text("Medium").tag("normal")
                                Text("Hard").tag("hard")
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                    .padding(.horizontal)
                    
                    Button("Start") {
                        startQuiz()
                    }
                    .buttonStyle(ModernPillButtonStyle(tint: .accentColor))
                    .controlSize(.large)
                    .frame(maxWidth: 240)
                    Spacer(minLength: 48)
                } else {
                    VStack(spacing: 16) {
                        // Scoreboard
                        GameScoreboardCard(
                            currentCorrect: score,
                            currentAnswered: sessionAnswered,
                            currentStreak: currentStreak,
                            allTimeCorrect: allTimeCorrect,
                            allTimeAnswered: allTimeAnswered,
                            allTimeBestStreak: allTimeBestStreak
                        )

                        // Verse card
                        VStack {
                            Text("“\(currentVerseText)”")
                                .italic()
                                .font(.title3)
                                .multilineTextAlignment(.center)
                                .lineLimit(6)
                                .truncationMode(.tail)
                                .foregroundColor(.primary)
                                .padding(24)
                        }
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(UIColor.secondarySystemBackground), Color(UIColor.systemBackground)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.black.opacity(0.06), lineWidth: 1)
                        )
                        .padding(.horizontal)
                        
                        if (quizDifficulty == "normal" || quizDifficulty == "hard") && selectedOption == nil {
                            HStack(spacing: 6) {
                                Image(systemName: "timer")
                                Text("Time left: \(remainingSeconds)s")
                                    .monospacedDigit()
                            }
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(timerColor(for: remainingSeconds))
                            .scaleEffect(pulseOn ? 1.12 : 1.0)
                            .animation(.easeInOut(duration: 0.25), value: pulseOn)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 4)
                        }
                        
                        Text("Which book is this from?")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                        
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                            ForEach(options, id: \.self) { option in
                                Button {
                                    selectOption(option)
                                } label: {
                                    Text(labelForOption(option))
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .foregroundColor(buttonForeground(for: option))
                                }
                                .disabled(selectedOption != nil || isViewingPrevious)
                                .background(buttonBackground(for: option))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(
                                            selectedOption != nil && option == correctBookName ? Color.green : Color.black.opacity(0.15),
                                            lineWidth: selectedOption != nil && option == correctBookName ? 3 : 1
                                        )
                                )
                                .cornerRadius(12)
                                .font(.body)
                            }
                        }
                        .padding(.horizontal)
                        
                        if showAnswerReveal {
                            HStack(spacing: 8) {
                                Text("Correct answer: \(correctBookName) \(currentChapterNumber):\(currentVerseNumber)")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                Button(action: { toggleFavoriteCurrent() }) {
                                    Image(systemName: isCurrentFavorited() ? "heart.fill" : "heart")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(isCurrentFavorited() ? "Remove Favorite" : "Add to Favorites")
                            }
                            .padding(.top, 4)
                        }

                        // DEBUG: WIN button
                        if debugAutoWinEnabled, started, selectedOption == nil {
                            Button("WIN") {
                                // Equivalent to selecting the correct option
                                selectOption(correctBookName)
                            }
                            .buttonStyle(ModernPillButtonStyle(tint: .red))
                            .controlSize(.large)
                            .padding(.top, 4)
                            .accessibilityLabel("Win this round")
                        }
                    }
                    .padding(.vertical)
                }
            }
            .padding(.horizontal)
        }
        .onReceive(quizTimer) { _ in
            guard started else { return }
            guard selectedOption == nil else { return }
            guard quizDifficulty == "normal" || quizDifficulty == "hard" else { return }
            guard remainingSeconds > 0 else { return }
            remainingSeconds -= 1
            if remainingSeconds == 0 {
                timeOutQuestion()
            }
        }
        .onChange(of: remainingSeconds) { _, newValue in
            guard started, selectedOption == nil, (quizDifficulty == "normal" || quizDifficulty == "hard") else { return }
            let inRed = isInRedZone(newValue)
            if inRed && !wasInRedZone {
                startTimerPulse()
            }
            wasInRedZone = inRed
        }
        .navigationTitle("Bible Quiz")
        .toolbar {
            // Only show navigation buttons once the round has started
            if started {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Previous") { showPrevious() }
                        .buttonStyle(ToolbarPillButtonStyle(tint: .accentColor))
                        .controlSize(.regular)
                        .disabled(!isPreviousEnabled)

                    Button("Next") { showNext() }
                        .buttonStyle(ToolbarPillButtonStyle(tint: .accentColor))
                        .controlSize(.regular)
                        .disabled(!isNextEnabled)
                }
            }
        }
        .onAppear {
            rebuildPools()
            // Seed streaks from persisted values so they survive navigation/relaunch
            seedStreakFromPersistence()
        }
        // When difficulty changes, switch to that difficulty’s persisted streaks
        .onChange(of: quizDifficulty) { _, _ in
            seedStreakFromPersistence()
        }
        // Do not reset persistent streaks on disappear; keep only session counters transient
        .onDisappear { resetSessionScores() }
    }
    
    // MARK: - Pools
    private func rebuildPools() {
        let books: [Book]
        switch quizScopeRaw {
        case "old":
            books = BibleData.books.filter { Self.oldTestamentSet.contains($0.name) }
        case "new":
            books = BibleData.books.filter { Self.newTestamentSet.contains($0.name) }
        default:
            books = BibleData.books
        }
        let names = books.map { $0.name }
        let old = names.filter { Self.oldTestamentSet.contains($0) }
        let new = names.filter { Self.newTestamentSet.contains($0) }
        pools = Pools(books: books, allNames: names, oldNames: old, newNames: new)
    }

    // MARK: - Buffer management
    private func ensureBuffer(refillIfBelow threshold: Int) {
        guard started else { return }
        if questionBuffer.count < threshold {
            refillBuffer()
        }
    }

    private func refillBuffer() {
        guard !isRefilling else { return }
        guard !pools.books.isEmpty else { return }
        isRefilling = true
        let need = max(0, bufferSize - questionBuffer.count)
        guard need > 0 else { isRefilling = false; return }

        Task.detached(priority: .userInitiated) { [self] in
            let generated: [QuizQuestion] = await withTaskGroup(of: QuizQuestion?.self) { group in
                for _ in 0..<need {
                    group.addTask {
                        await MainActor.run {
                            self.makeQuestion()
                        }
                    }
                }
                var results: [QuizQuestion] = []
                for await item in group {
                    if let q = item { results.append(q) }
                }
                return results
            }
            await MainActor.run {
                self.questionBuffer.append(contentsOf: generated)
                self.isRefilling = false
            }
        }
    }

    private func popBufferedQuestion() -> QuizQuestion? {
        if !questionBuffer.isEmpty {
            return questionBuffer.removeFirst()
        }
        return makeQuestion()
    }

    // Pure generator using current pools/difficulty; no UI side-effects.
    private func makeQuestion() -> QuizQuestion? {
        guard let randomBook = pools.books.randomElement(),
              let randomChapter = randomBook.chapters.randomElement(),
              let randomVerse = randomChapter.verses.randomElement() else {
            return nil
        }

        let verseText = randomVerse.text
        let bookName = randomBook.name
        let chapterNum = randomChapter.number
        let verseNum = randomVerse.number

        let correctName = bookName
        let isOld = Self.oldTestamentSet.contains(correctName)

        var wrongPool: [String]
        switch quizDifficulty {
        case "hard":
            wrongPool = isOld ? pools.oldNames : pools.newNames
        default:
            wrongPool = pools.allNames
        }
        wrongPool.removeAll { $0 == correctName }

        var wrongBooks = wrongPool.shuffled()
        if wrongBooks.count > 3 { wrongBooks = Array(wrongBooks.prefix(3)) }
        let opts = (wrongBooks + [correctName]).shuffled()

        return QuizQuestion(
            verseText: verseText,
            correctBook: bookName,
            chapter: chapterNum,
            verse: verseNum,
            options: opts,
            selected: nil
        )
    }

    // MARK: - Game flow
    private func startQuiz() {
        // Do NOT reset persistent streaks; seed from persistence instead
        seedStreakFromPersistence()
        started = true
        score = 0
        questionNumber = 0
        sessionAnswered = 0
        history = []
        currentIndex = -1
        selectedOption = nil
        showAnswerReveal = false

        questionBuffer.removeAll()
        refillBuffer()
        if let q = popBufferedQuestion() {
            appendAndLoad(q)
        } else {
            generateQuestion()
        }
        ensureBuffer(refillIfBelow: refillThreshold)
    }
    
    private func generateQuestion() {
        selectedOption = nil
        showAnswerReveal = false
        
        switch quizDifficulty {
        case "normal": remainingSeconds = 30
        case "hard": remainingSeconds = 20
        default: remainingSeconds = 0
        }
        
        wasInRedZone = false
        pulseOn = false
        
        guard let q = makeQuestion() else {
            currentVerseText = "No verse found."
            correctBookName = ""
            options = []
            return
        }
        appendAndLoad(q)
    }

    private func appendAndLoad(_ q: QuizQuestion) {
        history.append(q)
        currentIndex = history.count - 1
        loadQuestion(from: q)
        switch quizDifficulty {
        case "normal": remainingSeconds = 30
        case "hard": remainingSeconds = 20
        default: remainingSeconds = 0
        }
        wasInRedZone = false
        pulseOn = false
    }
    
    private func selectOption(_ name: String) {
        guard selectedOption == nil else { return }
        guard currentIndex >= 0 && currentIndex == history.count - 1 else { return }
        pulseOn = false
        remainingSeconds = 0
        selectedOption = name
        history[currentIndex].selected = name
        sessionAnswered += 1

        let isCorrect = (name == correctBookName)
        if isCorrect {
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
            // Keep session best in sync
            bestStreak = max(bestStreak, persisted, readPersistentBest())

            recordRound(correct: 1, answered: 1, bestStreak: bestStreak)
            // Per-book maps
            GameStats.shared.recordQuizPerBook(bookName: correctBookName, answered: 1, correct: 1)
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
        } else {
            // Persistent streak: reset on incorrect
            writePersistentStreak(0)
            currentStreak = 0

            recordRound(correct: 0, answered: 1, bestStreak: bestStreak)
            // Answered-only for the referenced book
            GameStats.shared.recordQuizPerBook(bookName: correctBookName, answered: 1, correct: 0)
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            #endif
        }
        showAnswerReveal = true
    }
    
    private func nextQuestion() {
        questionNumber += 1
        if let q = popBufferedQuestion() {
            appendAndLoad(q)
            ensureBuffer(refillIfBelow: refillThreshold)
        } else {
            generateQuestion()
            ensureBuffer(refillIfBelow: refillThreshold)
        }
    }
    
    private func showPrevious() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
        let q = history[currentIndex]
        remainingSeconds = 0
        loadQuestion(from: q)
    }

    private func showNext() {
        if currentIndex < history.count - 1 {
            currentIndex += 1
            remainingSeconds = 0
            loadQuestion(from: history[currentIndex])
        } else {
            nextQuestion()
        }
    }
    
    private func loadQuestion(from q: QuizQuestion) {
        currentVerseText = q.verseText
        correctBookName = q.verseText.isEmpty ? "" : q.correctBook
        currentChapterNumber = q.chapter
        currentVerseNumber = q.verse
        options = q.options
        selectedOption = q.selected
        showAnswerReveal = q.selected != nil
    }
    
    private func resetSessionScores() {
        // Do NOT reset persistent streaks on navigation changes.
        score = 0
        sessionAnswered = 0
        // Keep currentStreak/bestStreak as-is (they reflect persisted values)
    }
    
    // MARK: - UI helpers
    private func buttonBackground(for option: String) -> Color {
        guard let selected = selectedOption else {
            return Color.clear
        }
        if selected == option {
            return option == correctBookName ? Color.green.opacity(0.3) : Color.red.opacity(0.3)
        }
        return Color.clear
    }
    
    private func buttonForeground(for option: String) -> Color {
        guard let _ = selectedOption else {
            return .primary
        }
        return .primary
    }
    
    private func labelForOption(_ option: String) -> String {
        if showAnswerReveal && option == correctBookName {
            return "\(correctBookName) \(currentChapterNumber):\(currentVerseNumber)"
        }
        return option
    }

    private func timerColor(for seconds: Int) -> Color {
        switch quizDifficulty {
        case "normal":
            if seconds > 10 { return .green }
            else if seconds >= 5 { return .yellow }
            else { return .red }
        case "hard":
            if seconds > 8 { return .green }
            else if seconds >= 4 { return .yellow }
            else { return .red }
        default:
            return .secondary
        }
    }

    private func isInRedZone(_ seconds: Int) -> Bool {
        switch quizDifficulty {
        case "normal": return seconds < 5
        case "hard": return seconds < 4
        default: return false
        }
    }

    private func startTimerPulse() {
        let pulses = 3
        for i in 0..<(pulses * 2) {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.25) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    self.pulseOn.toggle()
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(pulses * 2) * 0.25 + 0.01) {
            self.pulseOn = false
        }
    }

    private func timeOutQuestion() {
        guard selectedOption == nil else { return }
        selectedOption = "__timeout__"
        sessionAnswered += 1

        // Timeout is incorrect -> reset persistent streak
        writePersistentStreak(0)
        currentStreak = 0

        recordRound(correct: 0, answered: 1, bestStreak: bestStreak)
        // Timeout still counts as answered for the referenced (correct) book
        if !correctBookName.isEmpty {
            GameStats.shared.recordQuizPerBook(bookName: correctBookName, answered: 1, correct: 0)
        }
        showAnswerReveal = true
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        #endif
    }
    
    // MARK: - Favorites
    private func isCurrentFavorited() -> Bool {
        favorites.contains { fav in
            fav.bookName == correctBookName && fav.chapterNumber == currentChapterNumber && fav.verseNumber == currentVerseNumber
        }
    }

    private func toggleFavoriteCurrent() {
        if let existing = favorites.first(where: { $0.bookName == correctBookName && $0.chapterNumber == currentChapterNumber && $0.verseNumber == currentVerseNumber }) {
            modelContext.delete(existing)
            try? modelContext.save()
        } else {
            let fav = Favorite(
                bookName: correctBookName,
                chapterNumber: currentChapterNumber,
                verseNumber: currentVerseNumber,
                verseText: currentVerseText
            )
            modelContext.insert(fav)
            try? modelContext.save()
        }
    }
}

#Preview {
    NavigationStack {
        QuizView()
    }
}
