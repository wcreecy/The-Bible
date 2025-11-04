import SwiftUI

struct GamesView: View {
    var body: some View {
        List {
            Section("Available Games") {
                NavigationLink {
                    QuizView()
                        .navigationTitle("Bible Quiz")
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "questionmark.circle")
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Bible Quiz").font(.headline)
                            Text("Guess which book the given verse is from").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
                
                NavigationLink {
                    HangmanGameView()
                        .navigationTitle("Hangman")
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "text.word.spacing")
                            .foregroundStyle(.teal)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Hangman").font(.headline)
                            Text("Guess a person, place or book from the Bible").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
                
                NavigationLink {
                    ReferenceMatchGameView()
                        .navigationTitle("Verse Match")
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "text.quote")
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Verse Match").font(.headline)
                            Text("Match the verse to its reference").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Games")
    }
}

#Preview {
    NavigationStack { GamesView() }
}
