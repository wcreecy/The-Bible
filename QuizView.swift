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
    
    private func incrementAllTimeAnswered() {
        switch quizDifficulty {
        case "normal": allTimeAnsweredNormal += 1
        case "hard": allTimeAnsweredHard += 1
        default: allTimeAnsweredEasy += 1
        }
    }
    
    private func incrementAllTimeCorrect() {
        switch quizDifficulty {
        case "normal": allTimeCorrectNormal += 1
        case "hard": allTimeCorrectHard += 1
        default: allTimeCorrectEasy += 1
        }
    }
    
    private func updateAllTimeBestStreak(_ newStreak: Int) {
        switch quizDifficulty {
        case "normal": allTimeBestStreakNormal = max(allTimeBestStreakNormal, newStreak)
        case "hard": allTimeBestStreakHard = max(allTimeBestStreakHard, newStreak)
        default: allTimeBestStreakEasy = max(allTimeBestStreakEasy, newStreak)
        }
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

    // MARK: - Static OT/NT sets (reuse across questions)
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
    
    @State private var started = false
    @State private var currentVerseText = ""
    @State private var correctBook = ""
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
    @State private var remainingSeconds: Int = 0
    @State private var quizTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var wasInRedZone: Bool = false
    @State private var pulseOn: Bool = false
    @State private var history: [QuizQuestion] = []
    @State private var currentIndex: Int = -1
    
    @State private var howToExpanded: Bool = false
    @State private var difficultyExpanded: Bool = false

    // MARK: - Question buffer (prefetch)
    @State private var questionBuffer: [QuizQuestion] = []
    private let bufferSize: Int = 5
    private let refillThreshold: Int = 3
    @State private var isRefilling: Bool = false

    private var isPreviousEnabled: Bool {
        // Allow going back if there is a previous question and we are not mid-countdown on the current unanswered question.
        guard started, currentIndex > 0 else { return false }
        // If we’re on the latest question and it’s unanswered with an active timer, disallow
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
                        // Shared scoreboard
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
                                            selectedOption != nil && option == correctBook ? Color.green : Color.black.opacity(0.15),
                                            lineWidth: selectedOption != nil && option == correctBook ? 3 : 1
                                        )
                                )
                                .cornerRadius(12)
                                .font(.body)
                            }
                        }
                        .padding(.horizontal)
                        
                        if showAnswerReveal {
                            HStack(spacing: 8) {
                                Text("Correct answer: \(correctBook) \(currentChapterNumber):\(currentVerseNumber)")
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
        .onAppear {
            // Build pools initially so Start is instant
            rebuildPools()
        }
        .onDisappear { resetSessionScores() }
    }
    
    // MARK: - Pools
    private func rebuildPools() {
        // Filter books by scope once, then build names and testament subsets
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

        Task.detached(priority: .userInitiated) {
            var generated: [QuizQuestion] = []
            generated.reserveCapacity(need)
            for _ in 0..<need {
                if let q = self.makeQuestion() {
                    generated.append(q)
                }
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
        // Fallback to on-demand generation if buffer is empty
        return makeQuestion()
    }

    // Pure generator using current pools/difficulty; no UI state side-effects.
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

        // Build wrong options pool based on difficulty
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
        currentStreak = 0
        started = true
        score = 0
        questionNumber = 0
        sessionAnswered = 0
        history = []
        currentIndex = -1
        selectedOption = nil
        showAnswerReveal = false

        // Prepare buffer and take first question
        questionBuffer.removeAll()
        refillBuffer()
        if let q = popBufferedQuestion() {
            appendAndLoad(q)
        } else {
            // Fallback if generation fails
            generateQuestion()
        }
        ensureBuffer(refillIfBelow: refillThreshold)
    }
    
    // Legacy single-shot generation (kept for fallback)
    private func generateQuestion() {
        selectedOption = nil
        showAnswerReveal = false
        
        // Set timer duration based on difficulty
        switch quizDifficulty {
        case "normal":
            remainingSeconds = 30
        case "hard":
            remainingSeconds = 20
        default:
            remainingSeconds = 0
        }
        
        wasInRedZone = false
        pulseOn = false
        
        guard let q = makeQuestion() else {
            currentVerseText = "No verse found."
            correctBook = ""
            options = []
            return
        }
        appendAndLoad(q)
    }

    private func appendAndLoad(_ q: QuizQuestion) {
        // Append to history and load UI
        history.append(q)
        currentIndex = history.count - 1
        loadQuestion(from: q)
        // Initialize timer after question becomes visible
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
        // Only allow answering on the latest question
        guard currentIndex >= 0 && currentIndex == history.count - 1 else { return }
        pulseOn = false
        remainingSeconds = 0
        selectedOption = name
        // Update just the selected field in-place to avoid extra churn
        history[currentIndex].selected = name
        sessionAnswered += 1
        incrementAllTimeAnswered()
        if name == correctBook {
            score += 1
            incrementAllTimeCorrect()
            currentStreak += 1
            bestStreak = max(bestStreak, currentStreak)
            updateAllTimeBestStreak(currentStreak)
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
        } else {
            currentStreak = 0
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
        correctBook = q.correctBook
        currentChapterNumber = q.chapter
        currentVerseNumber = q.verse
        options = q.options
        selectedOption = q.selected
        showAnswerReveal = q.selected != nil
    }
    
    private func resetSessionScores() {
        score = 0
        sessionAnswered = 0
        currentStreak = 0
        bestStreak = 0
    }
    
    // MARK: - UI helpers
    private func buttonBackground(for option: String) -> Color {
        guard let selected = selectedOption else {
            return Color.clear
        }
        if selected == option {
            return option == correctBook ? Color.green.opacity(0.3) : Color.red.opacity(0.3)
        }
        return Color.clear
    }
    
    private func buttonForeground(for option: String) -> Color {
        guard let selected = selectedOption else {
            return .primary
        }
        if selected == option {
            return .primary
        }
        return .primary
    }
    
    private func labelForOption(_ option: String) -> String {
        if showAnswerReveal && option == correctBook {
            return "\(correctBook) \(currentChapterNumber):\(currentVerseNumber)"
        }
        return option
    }

    private func timerColor(for seconds: Int) -> Color {
        switch quizDifficulty {
        case "normal":
            if seconds > 10 { return .green }
            else if seconds >= 5 { return .yellow } // 5...10 inclusive
            else { return .red } // <5
        case "hard":
            if seconds > 8 { return .green }
            else if seconds >= 4 { return .yellow } // 4...8 inclusive
            else { return .red } // <4
        default:
            return .secondary
        }
    }

    private func isInRedZone(_ seconds: Int) -> Bool {
        switch quizDifficulty {
        case "normal":
            return seconds < 5
        case "hard":
            return seconds < 4
        default:
            return false
        }
    }

    private func startTimerPulse() {
        // Perform a brief pulse sequence when entering red zone
        let pulses = 3
        for i in 0..<(pulses * 2) {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.25) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    pulseOn.toggle()
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(pulses * 2) * 0.25 + 0.01) {
            pulseOn = false
        }
    }

    private func timeOutQuestion() {
        // Mark as answered incorrectly due to timeout
        guard selectedOption == nil else { return }
        selectedOption = "__timeout__" // disable buttons
        sessionAnswered += 1
        incrementAllTimeAnswered()
        currentStreak = 0
        showAnswerReveal = true
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        #endif
    }
    
    // MARK: - Favorites
    private func isCurrentFavorited() -> Bool {
        favorites.contains { fav in
            fav.bookName == correctBook && fav.chapterNumber == currentChapterNumber && fav.verseNumber == currentVerseNumber
        }
    }

    private func toggleFavoriteCurrent() {
        if let existing = favorites.first(where: { $0.bookName == correctBook && $0.chapterNumber == currentChapterNumber && $0.verseNumber == currentVerseNumber }) {
            modelContext.delete(existing)
            try? modelContext.save()
        } else {
            let fav = Favorite(
                bookName: correctBook,
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
