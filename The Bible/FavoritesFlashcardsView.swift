import SwiftData
import SwiftUI

/// Memorize favorite verses: each card shows a reference or verse, and tapping reveals
/// the other side.
struct FavoritesFlashcardsView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case referenceToVerse
        case verseToReference

        var id: String { rawValue }

        var title: LocalizedStringResource {
            switch self {
            case .referenceToVerse: "Reference → Verse"
            case .verseToReference: "Verse → Reference"
            }
        }
    }

    @Query(sort: \Favorite.createdAt, order: .reverse) private var favorites: [Favorite]

    @State private var mode: Mode = .referenceToVerse
    @State private var order: [Int] = []
    @State private var position = 0
    @State private var isShowingAnswer = false

    private var currentFavorite: Favorite? {
        guard order.indices.contains(position), favorites.indices.contains(order[position]) else { return nil }
        return favorites[order[position]]
    }

    var body: some View {
        Group {
            if let favorite = currentFavorite {
                VStack(spacing: 24) {
                    Picker("Mode", selection: $mode) {
                        ForEach(Mode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text("Card \(position + 1) of \(order.count)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()

                    card(for: favorite)

                    HStack(spacing: 12) {
                        Button("Shuffle", systemImage: "shuffle", action: shuffle)
                            .buttonStyle(.bordered)
                        Button("Next", systemImage: "arrow.right", action: next)
                            .buttonStyle(.borderedProminent)
                            .disabled(order.count <= 1)
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: 560)
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView(
                    "No Favorites Yet",
                    systemImage: "heart",
                    description: Text("Favorite some verses to practice them as flashcards.")
                )
            }
        }
        .background(AppBackgroundView(tab: .more))
        .navigationTitle("Flashcards")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: resetOrderIfNeeded)
        .onChange(of: favorites.count) { _, _ in resetOrderIfNeeded() }
        .onChange(of: mode) { _, _ in isShowingAnswer = false }
    }

    private func card(for favorite: Favorite) -> some View {
        let reference = "\(favorite.bookName) \(favorite.chapterNumber):\(favorite.verseNumber)"
        let prompt = mode == .referenceToVerse ? reference : favorite.verseText
        let answer = mode == .referenceToVerse ? favorite.verseText : reference

        return Button {
            withAnimation(.easeInOut(duration: 0.25)) { isShowingAnswer.toggle() }
        } label: {
            VStack(spacing: 16) {
                Text(prompt)
                    .font(mode == .referenceToVerse ? .title2.weight(.semibold) : .title3)
                if isShowingAnswer {
                    Divider()
                    Text(answer)
                        .font(mode == .referenceToVerse ? .title3 : .title2.weight(.semibold))
                        .foregroundStyle(.tint)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else {
                    Text("Tap to show the answer")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .multilineTextAlignment(.center)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, minHeight: 220)
            .padding(AppDesignMetrics.cardPadding)
            .heroCardSurface()
        }
        .buttonStyle(.plain)
        .accessibilityHint(isShowingAnswer ? "Hides the answer" : "Shows the answer")
    }

    private func next() {
        guard !order.isEmpty else { return }
        isShowingAnswer = false
        position = (position + 1) % order.count
    }

    private func shuffle() {
        isShowingAnswer = false
        order = Array(favorites.indices).shuffled()
        position = 0
    }

    /// Reshuffles when favorites are added or removed so every card points at one.
    private func resetOrderIfNeeded() {
        guard order.count != favorites.count else { return }
        shuffle()
    }
}

#Preview {
    NavigationStack {
        FavoritesFlashcardsView()
    }
    .modelContainer(for: Favorite.self, inMemory: true)
}
