import SwiftUI
import UIKit

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
    enum Category: String, CaseIterable, Identifiable { case people = "People", places = "Places"; var id: String { rawValue } }

    @State private var started: Bool = false
    @State private var difficulty: Difficulty = .medium
    @State private var category: Category = .people

    // Data
    @State private var loadedPeople: [BibleName] = []
    @State private var loadedPlaces: [BibleLocation] = []

    // Current round
    @State private var targetLabel: String = ""
    @State private var referenceBookName: String? = nil // parsed from firstReference

    // Timer
    @State private var remainingSeconds: Int = 0
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // Scoring
    @State private var score: Int = 0
    @State private var answered: Int = 0

    // Search
    @State private var searchText: String = ""
    @State private var selectionLocked: Bool = false // prevent multiple submissions

    private var allBookNames: [String] { BibleData.books.map { $0.name } }

    private var filteredBooks: [String] {
        let text = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return [] }
        return allBookNames.filter { $0.localizedCaseInsensitiveContains(text) }.sorted()
    }

    private var roundTime: Int {
        switch difficulty { case .easy: return 13; case .medium: return 10; case .hard: return 7 }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if !started {
                    Spacer(minLength: 32)
                    Text("Beat the Clock")
                        .font(.largeTitle)
                        .fontWeight(.heavy)
                    Text("Type a Bible book that mentions the shown person or place before the timer runs out.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Picker("Category", selection: $category) {
                        Text("People").tag(Category.people)
                        Text("Places").tag(Category.places)
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
                            .font(.title3)
                            .foregroundStyle(timerColor)
                        }

                        // Prompt card
                        GroupBox {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(category == .people ? "Person" : "Place")
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
                            TextField("Start typing…", text: $searchText)
                                .textInputAutocapitalization(.words)
                                .disableAutocorrection(true)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit { submitCurrentEntry() }
                                .disabled(selectionLocked)

                            if !filteredBooks.isEmpty {
                                // Suggestions list
                                VStack(spacing: 6) {
                                    ForEach(filteredBooks.prefix(8), id: \._self) { name in
                                        Button(action: { submit(bookName: name) }) {
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
            if remainingSeconds > 0 { remainingSeconds -= 1 }
            if remainingSeconds == 0 {
                endRound(correct: false)
            }
        }
    }

    private var timerColor: Color {
        if remainingSeconds <= 3 { return .red }
        if remainingSeconds <= 6 { return .yellow }
        return .green
    }

    private func startGame() {
        score = 0
        answered = 0
        started = true
        nextRound()
    }

    private func nextRound() {
        selectionLocked = false
        searchText = ""
        remainingSeconds = roundTime
        // Pick a random entry based on category
        switch category {
        case .people:
            if loadedPeople.isEmpty { targetLabel = ""; referenceBookName = nil; return }
            let entry = loadedPeople.randomElement()!
            targetLabel = entry.name
            referenceBookName = parseBookName(from: entry.firstReference)
        case .places:
            if loadedPlaces.isEmpty { targetLabel = ""; referenceBookName = nil; return }
            let entry = loadedPlaces.randomElement()!
            targetLabel = entry.location
            referenceBookName = parseBookName(from: entry.firstReference)
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
        let correct = referenceBookName.map { normalize($0) } ?? ""
        if normalized == correct {
            score += 1
            let generator = UINotificationFeedbackGenerator(); generator.notificationOccurred(.success)
        } else {
            score -= 1
            let generator = UINotificationFeedbackGenerator(); generator.notificationOccurred(.error)
        }
    }

    private func endRound(correct: Bool) {
        guard !selectionLocked else { return }
        selectionLocked = true
        answered += 1
        if correct { score += 1 } else { score -= 1 }
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
}

#Preview {
    NavigationStack { BeatTheClockGameView() }
}
