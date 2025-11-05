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
    @Namespace private var flipNamespace
    
    var body: some View {
        NavigationStack {
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
                    
                    Button("Start") {
                        startGame()
                    }
                    .buttonStyle(ModernPillButtonStyle(tint: .accentColor))
                    .controlSize(.large)
                    .frame(maxWidth: 240)
                    Spacer()
                } else {
                    Spacer()
                    flashcardView()
                        .frame(width: 320, height: 220)
                        .padding()
                    
                    Text(instructionText)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 30)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 320)
                    
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
                    Spacer()
                }
            }
            .navigationTitle("Favorites Flashcards")
            .padding()
        }
    }
    
    private func startGame() {
        shuffledFavorites = favorites.shuffled()
        currentIndex = 0
        flipped = false
        started = true
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
        Group {
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
        .rotation3DEffect(.degrees(180), axis: (x: 0, y:1, z:0))
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

// MARK: - Button Styles

struct ModernPillButtonStyle: ButtonStyle {
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

struct ModernProminentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .fontWeight(.semibold)
            .padding(.vertical, 14)
            .padding(.horizontal, 34)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.accentColor)
                    .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
            )
            .foregroundColor(.white)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct GameProminentButtonStyle: ButtonStyle {
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
        let fav = Favorite(bookName: book, chapterNumber: chapter, verseNumber: verse, verseText: text)
        context.insert(fav)
    }

    try? context.save()
    return container
}()

#Preview {
    FavoritesFlashcardsGameView()
        .modelContainer(previewFavoritesContainer)
}
