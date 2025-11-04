import SwiftUI
import SwiftData

struct FavoritesFlashcardsGameView: View {
    @Query(sort: \.order) private var favorites: [Favorite]
    
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
                    .buttonStyle(ModernPillButtonStyle())
                    .controlSize(.large)
                    .frame(maxWidth: 240)
                    Spacer()
                } else {
                    Spacer()
                    flashcardView()
                        .frame(maxWidth: 320, maxHeight: 220)
                        .padding()
                    
                    Text(instructionText)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 30)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 320)
                    
                    HStack(spacing: 40) {
                        Button("Previous") {
                            previousCard()
                        }
                        .buttonStyle(ModernProminentButtonStyle())
                        .disabled(shuffledFavorites.count <= 1)
                        
                        Button("Next") {
                            nextCard()
                        }
                        .buttonStyle(ModernProminentButtonStyle())
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
            .frame(maxWidth: 320, maxHeight: 220)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(
                Capsule()
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
                Text(favorite.reference)
                    .font(.title3.bold())
                    .multilineTextAlignment(.center)
                    .padding(30)
                    .foregroundColor(.primary)
            case .verseToReference:
                Text(favorite.verse)
                    .font(.title3)
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
                Text(favorite.verse)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .padding(30)
                    .foregroundColor(.primary)
            case .verseToReference:
                Text(favorite.reference)
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
                return "Verse: \(favorite.verse)"
            case .verseToReference:
                return "Reference: \(favorite.reference)"
            }
        } else {
            switch mode {
            case .referenceToVerse:
                return "Reference: \(favorite.reference)"
            case .verseToReference:
                return "Verse: \(favorite.verse)"
            }
        }
    }
}

// MARK: - Button Styles

struct ModernPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .fontWeight(.semibold)
            .padding(.vertical, 12)
            .padding(.horizontal, 36)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule()
                            .stroke(.primary.opacity(0.3), lineWidth: 1)
                    )
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
            .foregroundColor(.primary)
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

#Preview {
    // Provide an in-memory model container if possible, otherwise just show the view.
    if let container = try? ModelContainer(for: Favorite.self, inMemory: true) {
        // Add sample data
        let context = container.mainContext
        let sampleFavorites: [(String, String)] = [
            ("John 3:16", "For God so loved the world..."),
            ("Psalm 23:1", "The Lord is my shepherd..."),
            ("Romans 8:28", "All things work together for good...")
        ]
        for (ref, verse) in sampleFavorites {
            let fav = Favorite(reference: ref, verse: verse)
            context.insert(fav)
        }
        try? context.save()
        
        return FavoritesFlashcardsGameView()
            .modelContainer(container)
    } else {
        return FavoritesFlashcardsGameView()
    }
}
