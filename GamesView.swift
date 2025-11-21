import SwiftUI

struct GamesView: View {
    private enum GameRoute: Hashable {
        case quiz
        case hangman
        case beatTheClock
        case referenceMatch
        case favoritesFlashcards
        case bookOrder
        case wordSearch
    }

    @State private var selection: GameRoute? = nil

    var body: some View {
        List {
            Section("Available Games") {
                NavigationLink(value: GameRoute.quiz) {
                    HStack(spacing: 12) {
                        Image(systemName: "questionmark.circle")
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Bible Quiz").font(.headline)
                            Text("Guess which book the given verse is from").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
                
                NavigationLink(value: GameRoute.hangman) {
                    HStack(spacing: 12) {
                        Image(systemName: "text.word.spacing")
                            .foregroundStyle(.teal)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Hangman").font(.headline)
                            Text("Guess a person, place or book from the Bible").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
                
                NavigationLink(value: GameRoute.beatTheClock) {
                    HStack(spacing: 12) {
                        Image(systemName: "hourglass")
                            .foregroundStyle(.indigo)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Beat the Clock").font(.headline)
                            Text("Name a Bible book before time runs out").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
                
                NavigationLink(value: GameRoute.referenceMatch) {
                    HStack(spacing: 12) {
                        Image(systemName: "text.quote")
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Verse Match").font(.headline)
                            Text("Match the verse to its reference").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
                
                NavigationLink(value: GameRoute.favoritesFlashcards) {
                    HStack(spacing: 12) {
                        Image(systemName: "rectangle.portrait.on.rectangle.portrait")
                            .foregroundStyle(.pink)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Favorites Flashcards").font(.headline)
                            Text("Practice your favorited verses with flashcards").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
                
                NavigationLink(value: GameRoute.bookOrder) {
                    HStack(spacing: 12) {
                        Image(systemName: "list.number")
                            .foregroundStyle(.purple)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Book Order").font(.headline)
                            Text("Drag books into order").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }

                NavigationLink(value: GameRoute.wordSearch) {
                    HStack(spacing: 12) {
                        Image(systemName: "grid")
                            .foregroundStyle(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Word Search").font(.headline)
                            Text("Find 3–6 hidden words from a verse").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Games")
        .navigationDestination(for: GameRoute.self) { route in
            switch route {
            case .quiz:
                QuizView()
            case .hangman:
                HangmanGameView()
            case .beatTheClock:
                BeatTheClockGameView()
            case .referenceMatch:
                ReferenceMatchGameView()
            case .favoritesFlashcards:
                FavoritesFlashcardsGameView()
            case .bookOrder:
                BookOrderGameView()
            case .wordSearch:
                WordSearchGameView()
            }
        }
        .onAppear { selection = nil }
    }
}

#Preview {
    NavigationStack { GamesView() }
}
