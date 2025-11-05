import SwiftUI
import UIKit
import Combine

struct BeatTheClockGameView: View {
    // Button styles consistent with other games
    private struct GameProminentButtonStyle: ButtonStyle {
        var tint: Color = .accentColor
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(tint)
                        .shadow(color: .black.opacity(configuration.isPressed ? 0.05 : 0.12), radius: configuration.isPressed ? 2 : 6, x: 0, y: configuration.isPressed ? 1 : 3)
                )
                .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isPressed)
        }
    }

    private struct ModernPillButtonStyle: ButtonStyle {
        var tint: Color = .accentColor
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(.headline)
                .foregroundStyle(tint)
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(
                    .ultraThinMaterial,
                    in: Capsule(style: .continuous)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(tint.opacity(configuration.isPressed ? 0.6 : 0.35), lineWidth: configuration.isPressed ? 2 : 1)
                )
                .shadow(color: .black.opacity(configuration.isPressed ? 0.04 : 0.08), radius: configuration.isPressed ? 1 : 3, x: 0, y: configuration.isPressed ? 0 : 2)
                .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
                .animation(.spring(response: 0.22, dampingFraction: 0.85), value: configuration.isPressed)
        }
    }

    enum Difficulty: String, CaseIterable, Identifiable { case easy, medium, hard; var id: String { rawValue } }
    enum Category: String, CaseIterable, Identifiable { case people = "People", places = "Places", both = "Both"; var id: String { rawValue } }

    @State private var started: Bool = false
    @State private var difficulty: Difficulty = .medium
    @State private var category: Category = .people

    // Data
    @State private var loadedPeople: [BibleName] = []
    @State private var loadedPlaces: [BibleLocation] = []

    // Current round
    @State private var targetLabel: String = ""
    @State private var referenceBookName: String? = nil // parsed from firstReference
    @State private var currentEntryIsPerson: Bool = true

    // Timer
    @State private var remainingSeconds: Int = 0
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // Scoring
    @State private var score: Int = 0
    @State private var answered: Int = 0

    @State private var currentStreak: Int = 0
    @State private var currentBestStreak: Int = 0

    private var allTimeCorrect: Int { UserDefaults.standard.integer(forKey: "beatclockAllTimeCorrect_\(difficultyKeySuffix())") }
    private var allTimeAnswered: Int { UserDefaults.standard.integer(forKey: "beatclockAllTimeAnswered_\(difficultyKeySuffix())") }
    private var allTimeBestStreak: Int { UserDefaults.standard.integer(forKey: "beatclockAllTimeBestStreak_\(difficultyKeySuffix())") }

    // Search
    @State private var searchText: String = ""
    @State private var selectionLocked: Bool = false // prevent multiple submissions
    @State private var acceptableBooks: Set<String> = []
    @State private var showAnswers: Bool = false
    @FocusState private var searchFieldFocused: Bool
    @State private var pulse: Bool = false

    private var allBookNames: [String] { BibleData.books.map { $0.name } }

    private var filteredBooks: [String] {
        let text = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return [] }
        return allBookNames.filter { $0.localizedCaseInsensitiveContains(text) }.sorted()
    }

    private var roundTime: Int {
        switch difficulty { case .easy: return 13; case .medium: return 10; case .hard: return 7 }
    }

    private var canSubmit: Bool {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !selectionLocked && !trimmed.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if !started {
                    Spacer(minLength: 32)
                    Text("Type a Bible book that mentions the shown person or place before the timer runs out.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Picker("Category", selection: $category) {
                        Text("People").tag(Category.people)
                        Text("Places").tag(Category.places)
                        Text("Both").tag(Category.both)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    Picker("Difficulty", selection: $difficulty) {
                        ForEach(Difficulty.allCases) { d in
                            Text(d.rawValue.capitalized).tag(d)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    Button("Start") { startGame() }
                        .buttonStyle(ModernPillButtonStyle(tint: .accentColor))
                        .controlSize(.large)
                        .frame(maxWidth: 240)
                    Spacer(minLength: 32)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        // Stats
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("")
                                    .frame(width: 80, alignment: .leading)
                                Text("Correct").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                                Text("Total").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                                Text("Streak").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                                Text("Percent").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                            }
                            HStack {
                                Text("Current").font(.subheadline).frame(width: 80, alignment: .leading)
                                Text("\(score)").frame(maxWidth: .infinity, alignment: .leading)
                                Text("\(answered)").frame(maxWidth: .infinity, alignment: .leading)
                                Text("\(currentBestStreak)")
                                    .foregroundStyle(currentStreak == currentBestStreak && currentBestStreak > 0 ? .green : .primary)
                                    .animation(.easeInOut(duration: 0.2), value: currentBestStreak)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(percentString(correct: score, answered: answered)).frame(maxWidth: .infinity, alignment: .leading)
                            }
                            HStack {
                                Text("All-time").font(.subheadline).frame(width: 80, alignment: .leading)
                                Text("\(allTimeCorrect)").frame(maxWidth: .infinity, alignment: .leading)
                                Text("\(allTimeAnswered)").frame(maxWidth: .infinity, alignment: .leading)
                                Text("\(allTimeBestStreak)").frame(maxWidth: .infinity, alignment: .leading)
                                Text(percentString(correct: allTimeCorrect, answered: allTimeAnswered)).frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        // Scoreboard
                        HStack {
                            Text("Score: \(score)")
                                .font(.headline)
                            Spacer()
                            HStack(spacing: 6) {
                                Image(systemName: "timer")
                                Text("\(remainingSeconds)s")
                                    .monospacedDigit()
                            }
                            .scaleEffect(pulse ? 1.25 : 1.0)
                            .animation(.easeOut(duration: 0.18), value: pulse)
                            .shadow(color: timerColor.opacity(pulse ? 0.7 : 0.35), radius: pulse ? 10 : 4)
                            .font(.title3)
                            .foregroundStyle(timerColor)
                        }

                        // Prompt card
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

                        // Search
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

                                Button(action: { submitCurrentEntry() }) {
                                    Image(systemName: "paperplane.fill")
                                        .font(.title3)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(canSubmit ? Color.accentColor : .secondary)
                                .disabled(!canSubmit)
                                .accessibilityLabel("Submit answer")
                            }

                            if !filteredBooks.isEmpty {
                                // Suggestions list
                                VStack(spacing: 6) {
                                    ForEach(filteredBooks.prefix(8), id: \.self) { name in
                                        Button(action: { searchText = name; searchFieldFocused = true }) {
                                            HStack {
                                                Text(name)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                            }
                                            .padding(.vertical, 8)
                                            .padding(.horizontal, 12)
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

                        // Controls
                        HStack(spacing: 12) {
                            Button("Skip") { endRound(correct: false) }
                                .buttonStyle(ModernPillButtonStyle(tint: .orange))
                                .disabled(selectionLocked)
                            Button("Next") { nextRound() }
                                .buttonStyle(ModernPillButtonStyle(tint: .accentColor))
                                .disabled(!selectionLocked)
                            Button(action: { submitCurrentEntry() }) {
                                Image(systemName: "paperplane.circle.fill")
                                    .font(.system(size: 34, weight: .bold))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(canSubmit ? Color.green : .secondary)
                            .disabled(!canSubmit)
                            .accessibilityLabel("Submit answer")
                        }
                        if selectionLocked {
                            Button("Show answers (\(acceptableBooks.count))") { showAnswers = true }
                                .buttonStyle(ModernPillButtonStyle(tint: .blue))
                        }
                    }
                    .padding(.vertical)
                }
            }
            .padding()
        }
        .navigationTitle("Beat the Clock")
        .onAppear {
            Task {
                if loadedPeople.isEmpty { loadedPeople = await GameDataLoaders.loadNamesAsync() }
                if loadedPlaces.isEmpty { loadedPlaces = await GameDataLoaders.loadLocationsAsync() }
            }
        }
        .onReceive(timer) { _ in
            guard started, !selectionLocked else { return }
            // Pulse big at the start of each second, then shrink back quickly; haptic every second
            if remainingSeconds > 0 {
                pulse = true
                let generator = UIImpactFeedbackGenerator(style: .heavy)
                generator.impactOccurred()
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
                        let books = Array(acceptableBooks).sorted()
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
        currentStreak = 0
        currentBestStreak = 0
        nextRound()
    }

    private func nextRound() {
        selectionLocked = false
        searchText = ""
        remainingSeconds = roundTime
        acceptableBooks = []
        pulse = false
        // Pick a random entry based on category
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
        // Build acceptable books set for this target
        acceptableBooks = booksMentioning(targetLabel)
        if let ref = referenceBookName { acceptableBooks.insert(ref) }

        // Focus the search field so the user can immediately start typing
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
            currentStreak += 1
            if currentStreak > currentBestStreak { currentBestStreak = currentStreak }
            updateAllTime(correct: 1, answered: 1, streak: currentBestStreak)
            let generator = UINotificationFeedbackGenerator(); generator.notificationOccurred(.success)
        } else {
            // Removed: score -= 1
            currentStreak = 0
            updateAllTime(correct: 0, answered: 1, streak: currentBestStreak)
            let generator = UINotificationFeedbackGenerator(); generator.notificationOccurred(.error)
        }
    }

    private func endRound(correct: Bool) {
        guard !selectionLocked else { return }
        selectionLocked = true
        answered += 1
        if correct {
            score += 1
            currentStreak += 1
            if currentStreak > currentBestStreak { currentBestStreak = currentStreak }
            updateAllTime(correct: 1, answered: 1, streak: currentBestStreak)
        } else {
            // Removed: score -= 1
            currentStreak = 0
            updateAllTime(correct: 0, answered: 1, streak: currentBestStreak)
        }
    }

    private func parseBookName(from reference: String?) -> String? {
        guard let ref = reference, !ref.isEmpty else { return nil }
        // Expect formats like "Genesis 1:1" or "1 Samuel 3:4"; take tokens except last
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

    private func difficultyKeySuffix() -> String {
        switch difficulty { case .easy: return "easy"; case .medium: return "medium"; case .hard: return "hard" }
    }

    private func updateAllTime(correct addCorrect: Int, answered addAnswered: Int, streak: Int) {
        let defaults = UserDefaults.standard
        let suffix = difficultyKeySuffix()
        let correctKey = "beatclockAllTimeCorrect_\(suffix)"
        let answeredKey = "beatclockAllTimeAnswered_\(suffix)"
        let bestKey = "beatclockAllTimeBestStreak_\(suffix)"
        let newCorrect = defaults.integer(forKey: correctKey) + addCorrect
        let newAnswered = defaults.integer(forKey: answeredKey) + addAnswered
        let newBest = max(defaults.integer(forKey: bestKey), streak)
        defaults.set(newCorrect, forKey: correctKey)
        defaults.set(newAnswered, forKey: answeredKey)
        defaults.set(newBest, forKey: bestKey)
    }
}

#Preview {
    NavigationStack { BeatTheClockGameView() }
}

