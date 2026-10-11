import SwiftData
import SwiftUI

/// Memorize favorite verses: each card shows a prompt, and tapping flips it to the answer.
/// "Got it" sets a card aside; "Again" sends it to the back of the deck.
struct FavoritesFlashcardsView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case referenceToVerse
        case verseToReference
        case fillInBlanks

        var id: String { rawValue }

        var title: LocalizedStringResource {
            switch self {
            case .referenceToVerse: "Verse"
            case .verseToReference: "Reference"
            case .fillInBlanks: "Blanks"
            }
        }

        var detail: LocalizedStringResource {
            switch self {
            case .referenceToVerse: "See the reference and recite the verse."
            case .verseToReference: "Read the verse and name its reference."
            case .fillInBlanks: "Fill in the missing words of the verse."
            }
        }
    }

    @Query(sort: \Favorite.createdAt, order: .reverse) private var favorites: [Favorite]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var mode: Mode = .referenceToVerse
    /// The deck, by favorite ID, so cards stay attached to their verse when favorites change.
    @State private var order: [PersistentIdentifier] = []
    @State private var position = 0
    @State private var known: Set<PersistentIdentifier> = []
    @State private var isShowingAnswer = false

    /// Cards still being practiced, in deck order.
    private var remaining: [PersistentIdentifier] {
        order.filter { !known.contains($0) }
    }

    private var currentFavorite: Favorite? {
        guard remaining.indices.contains(position) else { return nil }
        let id = remaining[position]
        return favorites.first { $0.persistentModelID == id }
    }

    var body: some View {
        Group {
            if favorites.isEmpty {
                ContentUnavailableView(
                    "No Favorites Yet",
                    systemImage: "heart",
                    description: Text("Favorite some verses to practice them as flashcards.")
                )
            } else if remaining.isEmpty {
                deckFinished
            } else if let favorite = currentFavorite {
                practice(favorite)
            }
        }
        .background(AppBackgroundView(tab: .more))
        .navigationTitle("Flashcards")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: syncDeck)
        .onChange(of: favorites.map(\.persistentModelID)) { _, _ in syncDeck() }
        .onChange(of: mode) { _, _ in isShowingAnswer = false }
    }

    // MARK: - Practice

    private func practice(_ favorite: Favorite) -> some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Picker("Mode", selection: $mode) {
                    ForEach(Mode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text(mode.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Text("Card \(position + 1) of \(remaining.count) · \(known.count) learned")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .monospacedDigit()

            FlashcardView(
                prompt: prompt(for: favorite),
                answer: answer(for: favorite),
                promptIsReference: mode == .referenceToVerse,
                isShowingAnswer: isShowingAnswer,
                reduceMotion: reduceMotion
            ) {
                withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .easeInOut(duration: 0.45)) {
                    isShowingAnswer.toggle()
                }
            }

            if isShowingAnswer {
                HStack(spacing: 12) {
                    Button("Again", systemImage: "arrow.counterclockwise", action: again)
                        .buttonStyle(.bordered)
                        .accessibilityHint("Moves this card to the back of the deck")
                    Button("Got It", systemImage: "checkmark", action: gotIt)
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .accessibilityHint("Sets this card aside as learned")
                }
                .font(.headline)
            }

            HStack(spacing: 12) {
                Button("Previous", systemImage: "arrow.left", action: previous)
                    .disabled(remaining.count <= 1)
                Button("Shuffle", systemImage: "shuffle", action: shuffle)
                Button("Next", systemImage: "arrow.right", action: next)
                    .disabled(remaining.count <= 1)
            }
            .buttonStyle(.bordered)
            .labelStyle(.iconOnly)
            .font(.title3)
        }
        .frame(maxWidth: 560)
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var deckFinished: some View {
        ContentUnavailableView {
            Label("Deck Complete", systemImage: "checkmark.seal.fill")
        } description: {
            Text(known.count == 1 ? "You learned 1 verse." : "You learned all \(known.count) verses.")
        } actions: {
            Button("Practice Again", systemImage: "arrow.counterclockwise") {
                known.removeAll()
                shuffle()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Card content

    private func prompt(for favorite: Favorite) -> String {
        switch mode {
        case .referenceToVerse: favorite.reference
        case .verseToReference: favorite.currentVerseText
        case .fillInBlanks: Self.blanked(favorite.currentVerseText)
        }
    }

    private func answer(for favorite: Favorite) -> String {
        switch mode {
        case .referenceToVerse: favorite.currentVerseText
        case .verseToReference: favorite.reference
        case .fillInBlanks: "\(favorite.currentVerseText)\n\(favorite.reference)"
        }
    }

    /// Hides about every third longer word. Which words are hidden depends only on the
    /// text, so a card shows the same blanks each time.
    static func blanked(_ text: String) -> String {
        var wordIndex = 0
        return text.split(separator: " ", omittingEmptySubsequences: false).map { piece -> String in
            let letters = piece.filter(\.isLetter)
            guard letters.count >= 4 else { return String(piece) }
            defer { wordIndex += 1 }
            // A simple, stable mix of the word and its position decides which words go.
            let seed = letters.unicodeScalars.reduce(wordIndex) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
            guard seed % 3 == 0 else { return String(piece) }
            // Keep surrounding punctuation so the sentence still reads naturally.
            return piece.map { $0.isLetter ? "_" : String($0) }.joined()
                .replacingOccurrences(of: #"_+"#, with: "_____", options: .regularExpression)
        }.joined(separator: " ")
    }

    // MARK: - Deck

    private func next() {
        guard !remaining.isEmpty else { return }
        isShowingAnswer = false
        position = (position + 1) % remaining.count
    }

    private func previous() {
        guard !remaining.isEmpty else { return }
        isShowingAnswer = false
        position = (position - 1 + remaining.count) % remaining.count
    }

    private func gotIt() {
        guard remaining.indices.contains(position) else { return }
        isShowingAnswer = false
        known.insert(remaining[position])
        // The next card slides into this position; wrap at the end.
        if position >= remaining.count { position = 0 }
    }

    private func again() {
        guard remaining.indices.contains(position) else { return }
        isShowingAnswer = false
        let id = remaining[position]
        order.removeAll { $0 == id }
        order.append(id)
        if position >= remaining.count { position = 0 }
    }

    private func shuffle() {
        isShowingAnswer = false
        order = favorites.map(\.persistentModelID).shuffled()
        position = 0
    }

    /// Keeps the deck in step with favorites without restarting it: removed favorites
    /// leave the deck and new ones join at random spots.
    private func syncDeck() {
        let current = favorites.map(\.persistentModelID)
        guard !order.isEmpty else {
            shuffle()
            return
        }
        let currentSet = Set(current)
        order.removeAll { !currentSet.contains($0) }
        known.formIntersection(currentSet)
        for id in current where !order.contains(id) {
            order.insert(id, at: Int.random(in: 0...order.count))
        }
        position = min(position, max(remaining.count - 1, 0))
    }
}

/// A card that flips over to show its answer.
private struct FlashcardView: View {
    let prompt: String
    let answer: String
    let promptIsReference: Bool
    let isShowingAnswer: Bool
    let reduceMotion: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                face {
                    Text(prompt)
                        .font(promptIsReference ? .title2.weight(.semibold) : .title3)
                    Text("Tap to flip")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .opacity(isShowingAnswer ? 0 : 1)

                face {
                    Text(answer)
                        .font(promptIsReference ? .title3 : .title2.weight(.semibold))
                        .foregroundStyle(.tint)
                }
                .opacity(isShowingAnswer ? 1 : 0)
                // The back is pre-rotated so it reads correctly once the card turns over.
                .rotation3DEffect(.degrees(reduceMotion ? 0 : 180), axis: (x: 0, y: 1, z: 0))
            }
            .rotation3DEffect(
                .degrees(isShowingAnswer && !reduceMotion ? 180 : 0),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.5
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isShowingAnswer ? answer : prompt)
        .accessibilityHint(isShowingAnswer ? "Shows the prompt" : "Shows the answer")
        .accessibilityAddTraits(.isButton)
    }

    private func face<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 16, content: content)
            .multilineTextAlignment(.center)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, minHeight: 220)
            .padding(AppDesignMetrics.cardPadding)
            .heroCardSurface()
    }
}

#Preview {
    NavigationStack {
        FavoritesFlashcardsView()
    }
    .modelContainer(for: Favorite.self, inMemory: true)
}
