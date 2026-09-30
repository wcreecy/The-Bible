import SwiftUI
import SwiftData

struct FavoritesFlashcardsGameView: View {
    @Query(sort: \Favorite.createdAt, order: .reverse) private var favorites: [Favorite]
    
    enum Mode: String, CaseIterable, Identifiable {
        case referenceToVerse = "Reference → Verse"
        case verseToReference = "Verse → Reference"
        
        var id: String { rawValue }
    }
    
    @State private var mode: Mode = .referenceToVerse
    @State private var started = false
    @State private var currentIndex = 0
    @State private var flipped = false
    @State private var shuffledFavorites: [Favorite] = []
    @AppStorage("favoritesFlashcardsPlayCount") private var playCount = 0
    @Namespace private var flipNamespace
    
    var body: some View {
        GeometryReader { geometry in
            let usesSplitLayout = started && geometry.size.width >= 700

            VStack {
                if favorites.isEmpty {
                    Spacer()
                    Text("You have no favorites yet.\nAdd favorites to start the flashcards game!")
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .padding()
                    Spacer()
                } else if !started {
                    Spacer()
                    Picker("Mode", selection: $mode) {
                        ForEach(Mode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 30)
                    
                    Text("Build & test your memorization of the Word. As you favorite scriptures, they'll be added to the game")
                        .gameStartDescriptionStyle()
                        .padding(.horizontal)
                        .padding(.bottom, 16)
                    
                    Button("Start") {
                        startGame()
                    }
                    .buttonStyle(ModernPillButtonStyle(tint: .accentColor))
                    .controlSize(.large)
                    .frame(maxWidth: 240)
                    Spacer()
                } else {
                    Spacer()

                    if usesSplitLayout {
                        splitFlashcardsView()
                            .frame(maxWidth: 900, minHeight: 280, maxHeight: 360)
                            .padding(.horizontal, 24)
                    } else {
                        flashcardView()
                            .frame(width: 320, height: 220)
                            .padding()
                    }
                    
                    Text(usesSplitLayout ? splitInstructionText : instructionText)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 30)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: usesSplitLayout ? 600 : 320)
                    
                    HStack(spacing: 12) {
                        Button("Previous") {
                            previousCard()
                        }
                        .buttonStyle(ModernPillButtonStyle())
                        .frame(maxWidth: .infinity)
                        .disabled(shuffledFavorites.count <= 1)
                        
                        Button("Random") {
                            randomCard()
                        }
                        .buttonStyle(ModernPillButtonStyle())
                        .frame(maxWidth: .infinity)
                    }
                    .frame(maxWidth: usesSplitLayout ? 600 : .infinity)

                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, minHeight: geometry.size.height)
        }
        .navigationTitle("Favorites Flashcards")
        .navigationBarTitleDisplayMode(.inline)
        .padding()
    }
    
    private func startGame() {
        shuffledFavorites = favorites.shuffled()
        currentIndex = 0
        flipped = false
        started = true
        playCount += 1
        NotificationCenter.default.post(name: .gameStatsExternallyUpdated, object: nil)
    }
    
    private func nextCard() {
        withAnimation(.easeInOut) {
            flipped = false
        }
        currentIndex = (currentIndex + 1) % shuffledFavorites.count
    }
    
    private func previousCard() {
        withAnimation(.easeInOut) {
            flipped = false
        }
        currentIndex = (currentIndex - 1 + shuffledFavorites.count) % shuffledFavorites.count
    }
    
    private func randomCard() {
        guard !shuffledFavorites.isEmpty else { return }
        withAnimation(.easeInOut) {
            flipped = false
        }
        // If there's only one card, nothing to change
        guard shuffledFavorites.count > 1 else { return }
        var newIndex = currentIndex
        // Ensure we pick a different index than the current one
        repeat {
            newIndex = Int.random(in: 0..<shuffledFavorites.count)
        } while newIndex == currentIndex
        currentIndex = newIndex
    }
    
    private var instructionText: String {
        switch (mode, flipped) {
        case (.referenceToVerse, false):
            return "Tap the card to reveal the verse."
        case (.referenceToVerse, true):
            return "Tap the card to see the reference again."
        case (.verseToReference, false):
            return "Tap the card to reveal the reference."
        case (.verseToReference, true):
            return "Tap the card to see the verse again."
        }
    }
    
    private var splitInstructionText: String {
        flipped ? "Tap the answer card to hide the answer." : "Tap the answer card to reveal the answer."
    }

    @ViewBuilder
    private func splitFlashcardsView() -> some View {
        let favorite = shuffledFavorites[currentIndex]

        HStack(spacing: 24) {
            notebookCard(title: "Question", systemImage: "questionmark.circle.fill") {
                cardFrontView(favorite: favorite)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Question. \(questionAccessibilityLabel(for: favorite))")

            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    flipped.toggle()
                }
            } label: {
                notebookCard(title: "Answer", systemImage: flipped ? "eye.fill" : "eye.slash.fill") {
                    if flipped {
                        cardBackContent(favorite: favorite)
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "hand.tap.fill")
                                .font(.largeTitle)
                                .foregroundStyle(.tint)

                            Text("Tap to reveal the answer")
                                .font(.headline)
                                .multilineTextAlignment(.center)
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(flipped ? answerAccessibilityLabel(for: favorite) : "Reveal answer")
            .accessibilityHint(flipped ? "Hides the answer" : "Shows the answer")
        }
    }

    private func notebookCard<Content: View>(
        title: LocalizedStringKey,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 16) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(.tint)

            Spacer(minLength: 0)
            content()
            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(IndexCardBackground(cornerRadius: 20))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.primary.opacity(0.15), lineWidth: 1)
        }
        .shadow(color: .primary.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    private func questionAccessibilityLabel(for favorite: Favorite) -> String {
        switch mode {
        case .referenceToVerse:
            return "Reference: \(favorite.bookName) \(favorite.chapterNumber):\(favorite.verseNumber)"
        case .verseToReference:
            return "Verse: \(favorite.verseText)"
        }
    }

    private func answerAccessibilityLabel(for favorite: Favorite) -> String {
        switch mode {
        case .referenceToVerse:
            return "Answer. Verse: \(favorite.verseText)"
        case .verseToReference:
            return "Answer. Reference: \(favorite.bookName) \(favorite.chapterNumber):\(favorite.verseNumber)"
        }
    }

    @ViewBuilder
    private func flashcardView() -> some View {
        let favorite = shuffledFavorites[currentIndex]
        
        ZStack {
            Group {
                if flipped {
                    cardBackView(favorite: favorite)
                        .matchedGeometryEffect(id: "flashcard", in: flipNamespace)
                } else {
                    cardFrontView(favorite: favorite)
                        .matchedGeometryEffect(id: "flashcard", in: flipNamespace)
                }
            }
            .frame(width: 320, height: 220)
            .background(IndexCardBackground(cornerRadius: 20))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(.primary.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: .primary.opacity(0.1), radius: 4, x: 0, y: 2)
            .rotation3DEffect(
                .degrees(flipped ? 180 : 0),
                axis: (x: 0, y: 1, z: 0)
            )
            .animation(.easeInOut(duration: 0.4), value: flipped)
            .onTapGesture {
                withAnimation(.easeInOut) {
                    flipped.toggle()
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(accessibilityLabel(for: favorite))
    }
    
    private func cardFrontView(favorite: Favorite) -> some View {
        Group {
            switch mode {
            case .referenceToVerse:
                Text("\(favorite.bookName) \(favorite.chapterNumber):\(favorite.verseNumber)")
                    .font(.title3.bold())
                    .multilineTextAlignment(.center)
                    .padding(30)
                    .foregroundColor(.primary)
            case .verseToReference:
                Text(favorite.verseText)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(30)
                    .foregroundColor(.primary)
            }
        }
    }
    
    private func cardBackView(favorite: Favorite) -> some View {
        cardBackContent(favorite: favorite)
            .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
    }

    @ViewBuilder
    private func cardBackContent(favorite: Favorite) -> some View {
        switch mode {
        case .referenceToVerse:
            Text(favorite.verseText)
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(30)
                .foregroundColor(.primary)
        case .verseToReference:
            Text("\(favorite.bookName) \(favorite.chapterNumber):\(favorite.verseNumber)")
                .font(.title3.bold())
                .multilineTextAlignment(.center)
                .padding(30)
                .foregroundColor(.primary)
        }
    }
    
    private func accessibilityLabel(for favorite: Favorite) -> String {
        if flipped {
            switch mode {
            case .referenceToVerse:
                return "Verse: \(favorite.verseText)"
            case .verseToReference:
                return "Reference: \(favorite.bookName) \(favorite.chapterNumber):\(favorite.verseNumber)"
            }
        } else {
            switch mode {
            case .referenceToVerse:
                return "Reference: \(favorite.bookName) \(favorite.chapterNumber):\(favorite.verseNumber)"
            case .verseToReference:
                return "Verse: \(favorite.verseText)"
            }
        }
    }
}

struct IndexCardBackground: View {
    var cornerRadius: CGFloat = 16
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Paper fill
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(.systemBackground), Color(.secondarySystemBackground)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                // Subtle horizontal ruling lines
                let spacing: CGFloat = 22
                ForEach(0...max(0, Int(geo.size.height / spacing)), id: \.self) { i in
                    Path { path in
                        let y = CGFloat(i) * spacing + 10
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geo.size.width, y: y))
                    }
                    .stroke(Color.blue.opacity(0.10), lineWidth: 1)
                }
                // Left margin line (index card style)
                Path { path in
                    let x: CGFloat = 32
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: geo.size.height))
                }
                .stroke(Color.red.opacity(0.15), lineWidth: 1)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

@MainActor
private let previewFavoritesContainer: ModelContainer = {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Favorite.self, configurations: configuration)
    let context = container.mainContext

    let samples: [(String, Int, Int, String)] = [
        ("John", 3, 16, "For God so loved the world..."),
        ("Psalms", 23, 1, "The Lord is my shepherd..."),
        ("Romans", 8, 28, "All things work together for good...")
    ]

    for (book, chapter, verse, text) in samples {
        let fav = Favorite()
        fav.bookName = book
        fav.chapterNumber = chapter
        fav.verseNumber = verse
        fav.verseText = text
        fav.createdAt = Date()
        context.insert(fav)
    }

    try? context.save()
    return container
}()

#Preview {
    FavoritesFlashcardsGameView()
        .modelContainer(previewFavoritesContainer)
}
