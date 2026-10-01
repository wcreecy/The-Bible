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
    @AppStorage("quizDifficulty") private var quizDifficulty: String = "normal"
    
    // COMBINED all-time stats (shared across difficulties)
    @AppStorage("quizAllTimeCorrect_all") private var allTimeCorrectAll: Int = 0
    @AppStorage("quizAllTimeAnswered_all") private var allTimeAnsweredAll: Int = 0
    @AppStorage("quizAllTimeBestStreak_all") private var allTimeBestStreakAll: Int = 0

    // Global Auto‑Win debug toggle
    @AppStorage("debugAutoWinEnabled") private var debugAutoWinEnabled: Bool = false

    // Display the shared all-time stats regardless of difficulty
    private var allTimeCorrect: Int { allTimeCorrectAll }
    private var allTimeAnswered: Int { allTimeAnsweredAll }
    private var allTimeBestStreak: Int { allTimeBestStreakAll }
    
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

    private struct VerseCandidate {
        let text: String
        let bookName: String
        let chapter: Int
        let verse: Int
    }

    @State private var pools: Pools = .init(books: [], allNames: [], oldNames: [], newNames: [])
    @State private var questionBag: [VerseCandidate] = []

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
    @State private var timerOnLeft: Bool = false
    @State private var usesMutedTimerStyle: Bool = false
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
        GeometryReader { geometry in
            let usesSplitLayout = started && geometry.size.width >= 700

            ZStack {
                ScrollView {
                    VStack(spacing: 16) {
                if !started {
                    Text("Test your knowledge by guessing the book of the Bible from a given verse.")
                        .gameStartDescriptionStyle()
                    
                    GameStartInfoLayout {
                        GroupBox {
                            DisclosureGroup(isExpanded: $howToExpanded) {
                                VStack(alignment: .leading, spacing: 12) {
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
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("• Easy: No timer; two options from each testament.")
                                    Text("• Medium: 15 seconds; options are completely random.")
                                    Text("• Hard: 8 seconds; all options are from the same testament.")
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            } label: {
                                Text("Difficulty Settings").font(.headline)
                            }
                        }

                        GameStartCurrentGameCard {
                            GameStartCurrentGameRow(
                                label: "Source",
                                value: quizScopeRaw == "whole" ? "Old & New Testaments" : quizScopeRaw == "old" ? "Old Testament" : "New Testament"
                            )
                            GameStartCurrentGameRow(
                                label: "Difficulty",
                                value: quizDifficulty == "normal" ? "Medium" : quizDifficulty.capitalized
                            )
                            GameStartCurrentGameRow(
                                label: "Time Limit",
                                value: quizDifficulty == "easy" ? "No timer" : quizDifficulty == "normal" ? "15 seconds per question" : "8 seconds per question"
                            )
                        }
                    }
                    .gameStartOptionsStyle()
                    .expandGameStartCardsOnIPad(
                        howTo: $howToExpanded,
                        difficulty: $difficultyExpanded
                    )
                    .padding(.horizontal, usesSplitLayout ? 0 : 16)
                    
                    GameStartSettingsLayout {
                        GameStartPickerCard(
                            title: "Verse Source",
                            selection: Binding<String>(get: { quizScopeRaw }, set: { new in
                                quizScopeRaw = new
                                rebuildPools()
                            }),
                            options: ["whole", "old", "new"]
                        ) { source in
                            Text(source == "whole" ? "OT & NT" : source == "old" ? "OT" : "NT")
                        }

                        GameStartPickerCard(
                            title: "Difficulty",
                            selection: Binding<String>(get: { quizDifficulty }, set: { new in
                                quizDifficulty = new
                                rebuildPools()
                            }),
                            options: ["easy", "normal", "hard"]
                        ) { difficulty in
                            Text(difficulty == "normal" ? "Medium" : difficulty.capitalized)
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
                } else if usesSplitLayout {
                    QuizGameDashboard(
                        score: score,
                        answered: sessionAnswered,
                        streak: currentStreak,
                        allTimeCorrect: allTimeCorrect,
                        allTimeAnswered: allTimeAnswered,
                        allTimeBestStreak: allTimeBestStreak,
                        verseText: currentVerseText,
                        options: options,
                        selectedOption: selectedOption,
                        correctBookName: correctBookName,
                        chapterNumber: currentChapterNumber,
                        verseNumber: currentVerseNumber,
                        showAnswerReveal: showAnswerReveal,
                        isViewingPrevious: isViewingPrevious,
                        canGoPrevious: isPreviousEnabled,
                        canGoNext: isNextEnabled,
                        showsDebugWin: debugAutoWinEnabled && selectedOption == nil,
                        availableHeight: geometry.size.height - 32,
                        onSelectOption: selectOption,
                        onPrevious: showPrevious,
                        onNext: showNext,
                        onDebugWin: { selectOption(correctBookName) }
                    )
                } else {
                    VStack(spacing: 16) {
                        // Scoreboard
                        GameScoreboardCard(
                            currentCorrect: score,
                            currentAnswered: sessionAnswered,
                            currentStreak: currentStreak,
                            game: .quiz
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
                                .strokeBorder(quizQuestionBorderColor, lineWidth: quizQuestionBorderWidth)
                        )
                        .animation(.easeInOut(duration: 0.25), value: remainingSeconds)
                        .padding(.horizontal)
                        
                        if (quizDifficulty == "normal" || quizDifficulty == "hard") && selectedOption == nil {
                            GameTimerCard(
                                remainingSeconds: remainingSeconds,
                                tint: timerColor(for: remainingSeconds),
                                isPulsing: pulseOn
                            )
                            .padding(.horizontal)
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
                                VerseActionMenu(
                                    verse: VerseActionReference(
                                        bookName: correctBookName,
                                        chapterNumber: currentChapterNumber,
                                        verseNumber: currentVerseNumber,
                                        verseText: currentVerseText
                                    )
                                )
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
                .background {
                    if usesSplitLayout {
                        Color.clear
                            .heroCardSurface()
                            .padding(12)
                    }
                }
                .frame(width: usesSplitLayout ? geometry.size.width / 2 : geometry.size.width)
                .frame(
                    maxWidth: .infinity,
                    alignment: usesSplitLayout && timerOnLeft ? .trailing : .leading
                )

                if usesSplitLayout {
                    QuizLargeTimerView(
                        remainingSeconds: remainingSeconds,
                        tint: timerColor(for: remainingSeconds),
                        isPulsing: pulseOn,
                        isTimed: quizDifficulty == "normal" || quizDifficulty == "hard",
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
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                QuizNavigationTitle()
            }

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
        // The selected scope controls which verses can be asked, while difficulty
        // independently controls the composition of the four answer choices.
        let names = BibleData.books.map { $0.name }
        let old = names.filter { Self.oldTestamentSet.contains($0) }
        let new = names.filter { Self.newTestamentSet.contains($0) }
        pools = Pools(books: books, allNames: names, oldNames: old, newNames: new)
        rebuildQuestionBag()
    }

    private func rebuildQuestionBag() {
        questionBag = pools.books.flatMap { book in
            book.chapters.flatMap { chapter in
                chapter.verses.map { verse in
                    VerseCandidate(
                        text: verse.text,
                        bookName: book.name,
                        chapter: chapter.number,
                        verse: verse.number
                    )
                }
            }
        }
        .shuffled()
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

    // Consumes the next unique verse from the shuffled bag and builds its choices.
    private func makeQuestion() -> QuizQuestion? {
        if questionBag.isEmpty {
            rebuildQuestionBag()
        }

        guard let candidate = questionBag.popLast() else { return nil }

        let verseText = candidate.text
        let bookName = candidate.bookName
        let chapterNum = candidate.chapter
        let verseNum = candidate.verse

        let correctName = bookName
        let isOld = Self.oldTestamentSet.contains(correctName)

        var wrongBooks: [String]
        switch quizDifficulty {
        case "easy":
            var sameTestamentNames = isOld ? pools.oldNames : pools.newNames
            sameTestamentNames.removeAll { $0 == correctName }
            let otherTestamentNames = isOld ? pools.newNames : pools.oldNames

            guard let sameTestamentWrong = sameTestamentNames.randomElement() else {
                return nil
            }
            wrongBooks = [sameTestamentWrong] + Array(otherTestamentNames.shuffled().prefix(2))
        case "hard":
            var sameTestamentNames = isOld ? pools.oldNames : pools.newNames
            sameTestamentNames.removeAll { $0 == correctName }
            wrongBooks = Array(sameTestamentNames.shuffled().prefix(3))
        default:
            var allNames = pools.allNames
            allNames.removeAll { $0 == correctName }
            wrongBooks = Array(allNames.shuffled().prefix(3))
        }
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
        rebuildQuestionBag()
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
        case "normal": remainingSeconds = 15
        case "hard": remainingSeconds = 8
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
        case "normal": remainingSeconds = 15
        case "hard": remainingSeconds = 8
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

    private var quizTimerIsActive: Bool {
        started &&
        selectedOption == nil &&
        (quizDifficulty == "normal" || quizDifficulty == "hard")
    }

    private var quizQuestionBorderColor: Color {
        quizTimerIsActive ? timerColor(for: remainingSeconds) : Color.primary.opacity(0.12)
    }

    private var quizQuestionBorderWidth: CGFloat {
        quizTimerIsActive ? 2 : 1
    }

    private func timerColor(for seconds: Int) -> Color {
        switch quizDifficulty {
        case "normal":
            if seconds > 10 { return .green }
            else if seconds >= 5 { return .yellow }
            else { return .red }
        case "hard":
            if seconds > 5 { return .green }
            else if seconds >= 3 { return .yellow }
            else { return .red }
        default:
            return .secondary
        }
    }

    private func isInRedZone(_ seconds: Int) -> Bool {
        switch quizDifficulty {
        case "normal": return seconds < 5
        case "hard": return seconds < 3
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

private struct QuizGameDashboard: View {
    let score: Int
    let answered: Int
    let streak: Int
    let allTimeCorrect: Int
    let allTimeAnswered: Int
    let allTimeBestStreak: Int
    let verseText: String
    let options: [String]
    let selectedOption: String?
    let correctBookName: String
    let chapterNumber: Int
    let verseNumber: Int
    let showAnswerReveal: Bool
    let isViewingPrevious: Bool
    let canGoPrevious: Bool
    let canGoNext: Bool
    let showsDebugWin: Bool
    let availableHeight: CGFloat
    let onSelectOption: (String) -> Void
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onDebugWin: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            QuizDashboardScoreboard(
                score: score,
                answered: answered,
                streak: streak,
                allTimeCorrect: allTimeCorrect,
                allTimeAnswered: allTimeAnswered,
                allTimeBestStreak: allTimeBestStreak
            )

            QuizDashboardQuestion(
                verseText: verseText,
                options: options,
                selectedOption: selectedOption,
                correctBookName: correctBookName,
                chapterNumber: chapterNumber,
                verseNumber: verseNumber,
                showAnswerReveal: showAnswerReveal,
                isViewingPrevious: isViewingPrevious,
                onSelectOption: onSelectOption
            )

            Spacer(minLength: 0)

            QuizDashboardActions(
                canGoPrevious: canGoPrevious,
                canGoNext: canGoNext,
                showsDebugWin: showsDebugWin,
                onPrevious: onPrevious,
                onNext: onNext,
                onDebugWin: onDebugWin
            )
        }
        .padding(AppDesignMetrics.cardPadding)
        .padding(.top, 12)
        .frame(maxWidth: .infinity, minHeight: availableHeight, alignment: .top)
    }
}

private struct QuizDashboardScoreboard: View {
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
                QuizScoreMetric(title: "Correct", value: "\(score)", systemImage: "checkmark.circle.fill", tint: .green)
                QuizScoreMetric(title: "Questions", value: "\(answered)", systemImage: "questionmark.circle.fill", tint: .blue)
                QuizScoreMetric(title: "Accuracy", value: "\(accuracy)%", systemImage: "percent", tint: .purple)
                QuizScoreMetric(title: "Streak", value: "\(streak)", systemImage: "flame.fill", tint: .orange)
            }
        }
        .padding(16)
        .background(.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: AppDesignMetrics.cardCornerRadius, style: .continuous))
    }
}

private struct QuizScoreMetric: View {
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

private struct QuizDashboardQuestion: View {
    let verseText: String
    let options: [String]
    let selectedOption: String?
    let correctBookName: String
    let chapterNumber: Int
    let verseNumber: Int
    let showAnswerReveal: Bool
    let isViewingPrevious: Bool
    let onSelectOption: (String) -> Void

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 10) {
                Label("Which book is this from?", systemImage: "text.book.closed.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tint)

                Text("“\(verseText)”")
                    .italic()
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .lineLimit(6)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: AppDesignMetrics.cardCornerRadius, style: .continuous))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(options, id: \.self) { option in
                    Button {
                        onSelectOption(option)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: optionIcon(for: option))
                            Text(optionLabel(for: option))
                                .lineLimit(2)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 52)
                    }
                    .buttonStyle(.glass(optionGlass(for: option)))
                    .disabled(selectedOption != nil || isViewingPrevious)
                }
            }

            if showAnswerReveal {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.green)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Correct Answer")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)

                        Text("\(correctBookName) \(chapterNumber):\(verseNumber)")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.primary)
                    }

                    Spacer(minLength: 8)

                    VerseActionMenu(
                        verse: VerseActionReference(
                            bookName: correctBookName,
                            chapterNumber: chapterNumber,
                            verseNumber: verseNumber,
                            verseText: verseText
                        )
                    )
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 64)
                .glassEffect(.regular.tint(.green), in: .rect(cornerRadius: AppDesignMetrics.compactControlCornerRadius))
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func optionLabel(for option: String) -> String {
        showAnswerReveal && option == correctBookName
            ? "\(correctBookName) \(chapterNumber):\(verseNumber)"
            : option
    }

    private func optionGlass(for option: String) -> Glass {
        guard let selectedOption else { return .clear }
        if option == correctBookName { return .regular.tint(.green.opacity(0.28)) }
        if option == selectedOption { return .regular.tint(.red.opacity(0.28)) }
        return .clear
    }

    private func optionIcon(for option: String) -> String {
        guard let selectedOption else { return "book.closed.fill" }
        if option == correctBookName { return "checkmark.circle.fill" }
        if option == selectedOption { return "xmark.circle.fill" }
        return "book.closed.fill"
    }
}

private struct QuizDashboardActions: View {
    let canGoPrevious: Bool
    let canGoNext: Bool
    let showsDebugWin: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onDebugWin: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button("Previous", systemImage: "arrow.left", action: onPrevious)
                .buttonStyle(GameProminentButtonStyle(tint: .accentColor))
                .disabled(!canGoPrevious)

            if showsDebugWin {
                Button("Win", systemImage: "checkmark.seal.fill", action: onDebugWin)
                    .buttonStyle(GameProminentButtonStyle(tint: .red))
            }

            Button("Next", systemImage: "arrow.right", action: onNext)
                .buttonStyle(GameProminentButtonStyle(tint: .accentColor))
                .disabled(!canGoNext)
        }
    }
}

private struct QuizLargeTimerView: View {
    let remainingSeconds: Int
    let tint: Color
    let isPulsing: Bool
    let isTimed: Bool
    @Binding var usesMutedStyle: Bool
    let onSwapSides: () -> Void

    private var timerTextColor: Color {
        remainingSeconds > 5 && remainingSeconds <= 10 ? .black : .white
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)

            VStack(spacing: 24) {
                Image(systemName: isTimed ? "timer" : "infinity")
                    .font(.system(size: 72, weight: .semibold))
                    .foregroundStyle(usesMutedStyle ? Color.secondary : timerTextColor.opacity(0.85))

                Text(isTimed ? "Time Remaining" : "Untimed Mode")
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(usesMutedStyle ? tint : timerTextColor.opacity(0.85))

                Text(isTimed ? "\(remainingSeconds)s" : "∞")
                    .font(.system(size: 180, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .foregroundStyle(usesMutedStyle ? tint : timerTextColor)
            }
            .scaleEffect(isPulsing ? 1.04 : 1)
            .animation(.easeOut(duration: 0.18), value: isPulsing)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(isTimed ? "Time remaining" : "Untimed mode")
            .accessibilityValue(isTimed ? "\(remainingSeconds) seconds" : "No time limit")

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
            .tint(usesMutedStyle ? tint : timerTextColor)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
        .background {
            if usesMutedStyle {
                Color.clear
                    .heroCardSurface()
            } else {
                RoundedRectangle(cornerRadius: AppDesignMetrics.cardCornerRadius, style: .continuous)
                    .fill(tint)
            }
        }
        .overlay {
            if !usesMutedStyle {
                RoundedRectangle(cornerRadius: AppDesignMetrics.cardCornerRadius, style: .continuous)
                    .strokeBorder(timerTextColor.opacity(0.22), lineWidth: 1)
            }
        }
        .shadow(color: usesMutedStyle ? .clear : tint.opacity(0.25), radius: 12, x: 0, y: 5)
        .padding(12)
        .animation(.easeInOut(duration: 0.25), value: remainingSeconds)
    }
}

private struct QuizNavigationTitle: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "questionmark.bubble.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(.tint, in: Circle())

            Text("Bible Quiz")
                .font(.headline.weight(.bold))
                .fontDesign(.rounded)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Bible Quiz")
    }
}

#Preview {
    NavigationStack {
        QuizView()
    }
}
