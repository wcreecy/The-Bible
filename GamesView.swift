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
                            Text("Guess the book from a verse").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }

                NavigationLink {
                    SameAuthorGameView()
                        .navigationTitle("Same Author?")
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "person.2.questionmark")
                            .foregroundStyle(.purple)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Same Author?").font(.headline)
                            Text("True/False author matching").font(.subheadline).foregroundStyle(.secondary)
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
