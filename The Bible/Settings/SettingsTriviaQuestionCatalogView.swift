import SwiftUI
import UniformTypeIdentifiers

struct SettingsTriviaQuestionCatalogView: View {
    @State private var isImporting = false
    @State private var alertMessage: String?

    var body: some View {
        Form {
            Section {
                Text("Edit BibleTriviaQuestions.json on your Mac or in a text editor, then import the edited file here. Each question needs an id, question, correctAnswer, at least three incorrectAnswers, reference, and difficulty (easy, normal, or hard).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button("Import Trivia Questions", systemImage: "square.and.arrow.down") {
                    isImporting = true
                }
                .accessibilityIdentifier("importTriviaQuestionsButton")
            } header: {
                Text("Trivia Catalog")
            } footer: {
                Text("Import replaces the current custom catalog. The original built-in catalog remains available until you import a new file.")
            }
        }
        .navigationTitle("Trivia Questions")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            do {
                let urls = try result.get()
                guard let url = urls.first else { return }
                let didStartAccessing = url.startAccessingSecurityScopedResource()
                defer {
                    if didStartAccessing {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                try BibleTriviaCatalogStore.importCatalog(Data(contentsOf: url))
                alertMessage = "Trivia questions imported successfully."
            } catch {
                alertMessage = error.localizedDescription
            }
        }
        .alert("Trivia Questions", isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button("OK") { alertMessage = nil }
        } message: {
            Text(alertMessage ?? "")
        }
    }
}
