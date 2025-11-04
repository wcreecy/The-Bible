import SwiftUI
import SwiftData

enum FavoritesFlashcardMode: String, CaseIterable, Identifiable {
  case referenceToVerse = "Reference → Verse"
  case verseToReference = "Verse → Reference"
  
  var id: String { rawValue }
}

struct FavoritesFlashcardsView: View {
  @Query(sort: \.createdAt, order: .reverse)
  private var favorites: [Favorite]
  
  @State private var currentIndex = 0
  @State private var showAnswer = false
  @State private var mode: FavoritesFlashcardMode = .referenceToVerse
  @State private var shuffleOrder: [Int] = []
  
  private var currentFavorite: Favorite? {
    guard !favorites.isEmpty, currentIndex < shuffleOrder.count else { return nil }
    return favorites[shuffleOrder[currentIndex]]
  }
  
  private var promptText: String {
    guard let favorite = currentFavorite else { return "" }
    switch mode {
    case .referenceToVerse:
      return favorite.reference
    case .verseToReference:
      return favorite.verseText
    }
  }
  
  private var answerText: String {
    guard let favorite = currentFavorite else { return "" }
    switch mode {
    case .referenceToVerse:
      return favorite.verseText
    case .verseToReference:
      return favorite.reference
    }
  }
  
  private func nextCard() {
    guard !favorites.isEmpty else { return }
    showAnswer = false
    currentIndex = (currentIndex + 1) % shuffleOrder.count
  }
  
  private func shuffleCards() {
    guard !favorites.isEmpty else { return }
    showAnswer = false
    shuffleOrder = (0..<favorites.count).shuffled()
    currentIndex = 0
  }
  
  private func resetShuffleIfNeeded() {
    if shuffleOrder.count != favorites.count {
      shuffleOrder = (0..<favorites.count).shuffled()
      currentIndex = 0
    }
  }
  
  var body: some View {
    Group {
      if favorites.isEmpty {
        ContentUnavailableView("No Favorites Yet", systemImage: "star.slash") {
          Text("Add some favorites first to play flashcards.")
        }
        .padding()
      } else {
        VStack(spacing: 24) {
          Spacer()
          
          ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
              .fill(.regularMaterial)
              .shadow(radius: 4)
              .frame(maxWidth: 350, maxHeight: 220)
            
            VStack(spacing: 16) {
              Text(showAnswer ? answerText : promptText)
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)
                .padding(.horizontal, 24)
              
              if showAnswer {
                Text("Tap card to hide answer")
                  .font(.subheadline)
                  .foregroundColor(.secondary)
              } else {
                Text("Tap card to show answer")
                  .font(.subheadline)
                  .foregroundColor(.secondary)
              }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
          }
          .padding(.horizontal, 32)
          .rotation3DEffect(
            .degrees(showAnswer ? 180 : 0),
            axis: (x: 0, y: 1, z: 0)
          )
          .animation(.easeInOut(duration: 0.3), value: showAnswer)
          .onTapGesture {
            withAnimation {
              showAnswer.toggle()
            }
          }
          .accessibilityElement(children: .combine)
          .accessibilityAddTraits(.isButton)
          .accessibilityLabel(showAnswer ? "Answer: \(answerText)" : "Prompt: \(promptText)")
          .accessibilityHint("Tap to \(showAnswer ? "hide" : "show") answer")
          
          Spacer()
          
          Picker("Mode", selection: $mode) {
            ForEach(FavoritesFlashcardMode.allCases) { mode in
              Text(mode.rawValue).tag(mode)
            }
          }
          .pickerStyle(.segmented)
          .padding(.horizontal, 32)
          .onChange(of: mode) { _ in
            showAnswer = false
          }
          
          HStack(spacing: 24) {
            Button(action: shuffleCards) {
              Label("Shuffle", systemImage: "shuffle")
                .font(.headline)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("Shuffle cards")
            .accessibilityHint("Randomize order of flashcards")
            
            Button(action: nextCard) {
              Label("Next", systemImage: "arrow.right.circle")
                .font(.headline)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Next card")
            .accessibilityHint("Show next flashcard")
            .disabled(favorites.count <= 1)
          }
          .padding(.horizontal, 32)
          .padding(.bottom, 24)
        }
        .navigationTitle("Favorites Flashcards")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
          resetShuffleIfNeeded()
        }
        .onChange(of: favorites.count) { _ in
          resetShuffleIfNeeded()
          showAnswer = false
          currentIndex = 0
        }
      }
    }
  }
}

#Preview {
  import Foundation
  import SwiftData
  
  @Model
  final class Favorite {
    @Attribute(.unique) var id: UUID
    var reference: String
    var verseText: String
    var createdAt: Date
    
    init(id: UUID = UUID(), reference: String, verseText: String, createdAt: Date = Date()) {
      self.id = id
      self.reference = reference
      self.verseText = verseText
      self.createdAt = createdAt
    }
  }
  
  let sampleFavorites: [Favorite] = [
    Favorite(reference: "John 3:16", verseText: "For God so loved the world..."),
    Favorite(reference: "Psalm 23:1", verseText: "The Lord is my shepherd..."),
    Favorite(reference: "Romans 8:28", verseText: "And we know that in all things God works...")
  ]
  
  FavoritesFlashcardsView()
    .modelContainer(for: Favorite.self, inMemory: true) { context in
      for favorite in sampleFavorites {
        context.insert(favorite)
      }
    }
}
