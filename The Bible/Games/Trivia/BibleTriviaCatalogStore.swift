import Foundation

enum BibleTriviaCatalogStore {
    static let didImportNotification = Notification.Name("BibleTriviaCatalogDidImport")

    // Read from `loadData()`, which runs off the main actor.
    private nonisolated static let importedFileName = "BibleTriviaQuestions.json"

    nonisolated static func loadData() -> Data? {
        if let importedURL, let data = try? Data(contentsOf: importedURL) {
            return data
        }

        guard let bundledURL = Bundle.main.url(
            forResource: "BibleTriviaQuestions",
            withExtension: "json"
        ) else {
            return nil
        }
        return try? Data(contentsOf: bundledURL, options: .mappedIfSafe)
    }

    static func importCatalog(_ data: Data) throws {
        let questions = try JSONDecoder().decode([BibleTriviaQuestion].self, from: data)
        try validate(questions)

        let directoryURL = try applicationSupportDirectory()
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        try data.write(to: directoryURL.appendingPathComponent(importedFileName), options: .atomic)
        NotificationCenter.default.post(name: didImportNotification, object: nil)
    }

    private nonisolated static var importedURL: URL? {
        guard let directoryURL = try? applicationSupportDirectory() else {
            return nil
        }
        return directoryURL.appendingPathComponent(importedFileName)
    }

    private nonisolated static func applicationSupportDirectory() throws -> URL {
        try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
    }

    private static func validate(_ questions: [BibleTriviaQuestion]) throws {
        guard !questions.isEmpty else {
            throw ImportError.emptyCatalog
        }

        var identifiers = Set<Int>()
        for question in questions {
            guard identifiers.insert(question.id).inserted else {
                throw ImportError.invalidQuestion("Duplicate id \(question.id).")
            }
            guard !question.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ImportError.invalidQuestion("Question \(question.id) has no question text.")
            }
            guard !question.correctAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ImportError.invalidQuestion("Question \(question.id) has no correct answer.")
            }
            guard question.incorrectAnswers.count >= 3 else {
                throw ImportError.invalidQuestion("Question \(question.id) needs at least three incorrect answers.")
            }

            let normalizedAnswers = question.incorrectAnswers.map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            }
            guard normalizedAnswers.allSatisfy({ !$0.isEmpty }),
                  Set(normalizedAnswers).count == normalizedAnswers.count else {
                throw ImportError.invalidQuestion("Question \(question.id) has empty or duplicate incorrect answers.")
            }
            guard !normalizedAnswers.contains(question.correctAnswer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()) else {
                throw ImportError.invalidQuestion("Question \(question.id) lists the correct answer as incorrect.")
            }
            guard ["easy", "normal", "hard"].contains(question.difficulty.lowercased()) else {
                throw ImportError.invalidQuestion("Question \(question.id) has an invalid difficulty.")
            }
        }
    }

    enum ImportError: LocalizedError {
        case emptyCatalog
        case invalidQuestion(String)

        var errorDescription: String? {
            switch self {
            case .emptyCatalog:
                "The file does not contain any Trivia questions."
            case .invalidQuestion(let message):
                message
            }
        }
    }
}
