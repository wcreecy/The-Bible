import SwiftUI

struct BookOrderGameView: View {
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

    enum Difficulty: String, CaseIterable, Identifiable { case easy, medium; var id: String { rawValue } }
    @State private var difficulty: Difficulty = .easy

    private struct BookItem: Identifiable, Equatable { let id = UUID(); let name: String; let index: Int }

    @State private var started: Bool = false
    @State private var items: [BookItem] = [] // current order user is sorting
    @State private var correctOrder: [BookItem] = [] // canonical order of selected subset

    @State private var answered: Int = 0
    @State private var score: Int = 0
    @State private var currentStreak: Int = 0
    @State private var bestStreak: Int = 0

    @State private var checked: Bool = false
    @State private var wasCorrect: Bool = false

    private var allTimeCorrect: Int { UserDefaults.standard.integer(forKey: "bookorderAllTimeCorrect_\(difficultyKeySuffix())") }
    private var allTimeAnswered: Int { UserDefaults.standard.integer(forKey: "bookorderAllTimeAnswered_\(difficultyKeySuffix())") }
    private var allTimeBestStreak: Int { UserDefaults.standard.integer(forKey: "bookorderAllTimeBestStreak_\(difficultyKeySuffix())") }

    var body: some View {
        VStack(spacing: 16) {
            if !started {
                Spacer(minLength: 24)
                Text("Book Order")
                    .font(.largeTitle)
                    .fontWeight(.heavy)
                Text("Drag the books to arrange them in canonical order.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
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
                Spacer(minLength: 24)
            } else {
                // Stats header
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
                        Text("\(bestStreak)")
                            .foregroundStyle(currentStreak == bestStreak && bestStreak > 0 ? .green : .primary)
                            .animation(.easeInOut(duration: 0.2), value: bestStreak)
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
                .padding(.horizontal)

                // Draggable list of books
                List {
                    ForEach(items) { item in
                        HStack {
                            Image(systemName: "line.3.horizontal")
                                .foregroundStyle(.secondary)
                            Text(item.name)
                        }
                    }
                    .onMove(perform: move)
                }
                .environment(\.editMode, .constant(.active))

                if checked {
                    Text(wasCorrect ? "Correct!" : "Not quite.")
                        .font(.headline)
                        .foregroundStyle(wasCorrect ? .green : .red)
                        .padding(.top, 4)

                    if !wasCorrect {
                        let correctNames = correctOrder.map { $0.name }.joined(separator: ", ")
                        Text("Correct order: \(correctNames)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }

                HStack(spacing: 12) {
                    Button("Check") { checkAnswer() }
                        .buttonStyle(ModernPillButtonStyle(tint: .accentColor))
                        .disabled(checked)
                    Button("Next") { nextRound() }
                        .buttonStyle(ModernPillButtonStyle(tint: .accentColor))
                        .disabled(!checked)
                }
                .padding(.horizontal)
            }
        }
        .navigationTitle("Book Order")
        .padding(.vertical)
    }

    private func startGame() {
        score = 0
        answered = 0
        currentStreak = 0
        bestStreak = 0
        started = true
        checked = false
        wasCorrect = false
        nextRound()
    }

    private func nextRound() {
        checked = false
        wasCorrect = false
        // Determine count from difficulty
        let count: Int
        switch difficulty {
        case .easy:
            count = Int.random(in: 5...8)
        case .medium:
            count = Int.random(in: 9...15)
        }
        // Sample distinct books
        let books = BibleData.books.enumerated().map { (idx, b) in BookItem(name: b.name, index: idx) }
        var selected: [BookItem] = []
        var pool = books
        for _ in 0..<min(count, pool.count) {
            if let pick = pool.randomElement(), let rmIdx = pool.firstIndex(of: pick) {
                selected.append(pick)
                pool.remove(at: rmIdx)
            }
        }
        // Correct order is by index
        correctOrder = selected.sorted(by: { $0.index < $1.index })
        // Present shuffled to user
        items = correctOrder.shuffled()
    }

    private func move(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
    }

    private func checkAnswer() {
        guard !checked else { return }
        checked = true
        answered += 1
        let isCorrect = items.map { $0.index } == correctOrder.map { $0.index }
        wasCorrect = isCorrect
        if isCorrect {
            score += 1
            currentStreak += 1
            bestStreak = max(bestStreak, currentStreak)
            updateAllTime(correct: 1, answered: 1, streak: bestStreak)
        } else {
            currentStreak = 0
            updateAllTime(correct: 0, answered: 1, streak: bestStreak)
        }
    }

    private func updateAllTime(correct addCorrect: Int, answered addAnswered: Int, streak: Int) {
        let defaults = UserDefaults.standard
        let suffix = difficultyKeySuffix()
        let correctKey = "bookorderAllTimeCorrect_\(suffix)"
        let answeredKey = "bookorderAllTimeAnswered_\(suffix)"
        let bestKey = "bookorderAllTimeBestStreak_\(suffix)"
        let newCorrect = defaults.integer(forKey: correctKey) + addCorrect
        let newAnswered = defaults.integer(forKey: answeredKey) + addAnswered
        let newBest = max(defaults.integer(forKey: bestKey), streak)
        defaults.set(newCorrect, forKey: correctKey)
        defaults.set(newAnswered, forKey: answeredKey)
        defaults.set(newBest, forKey: bestKey)
    }

    private func difficultyKeySuffix() -> String {
        switch difficulty { case .easy: return "easy"; case .medium: return "medium" }
    }

    private func percentString(correct: Int, answered: Int) -> String {
        guard answered > 0 else { return "0%" }
        let pct = Int(round((Double(correct) / Double(answered)) * 100.0))
        return "\(pct)%"
    }
}

#Preview {
    NavigationStack { BookOrderGameView() }
}
