import Foundation
import SwiftData

/// A note about a Scripture connection, as written from Scripture Connections or Chapter Insights.
/// The note is about the connection's first passage, so Notes finds it by that reference and can
/// open it in the Bible.
@MainActor
struct ScriptureConnectionNote {
    let connectionID: Int
    /// Display titles, such as "Genesis 1:27" and "Mark 10:6".
    let source: String
    let target: String
    let explanation: String

    init(connectionID: Int, source: String, target: String, explanation: String) {
        self.connectionID = connectionID
        self.source = source
        self.target = target
        self.explanation = explanation
    }

    init(entry: CrossReferenceExplorerEntry) {
        self.init(
            connectionID: entry.id,
            source: entry.sourceReference,
            target: entry.relatedReference,
            explanation: entry.relationshipDescription
        )
    }

    var title: String {
        "\(source) → \(target)"
    }

    /// Both passages and how they relate, then the reader's own thoughts.
    func body(thoughts: String = "") -> String {
        String(localized: "Related Scriptures\n\(source)\n\(target)\n\nRelationship\n\(explanation)\n\nMy thoughts:\n\(thoughts)")
    }

    var prefill: UserNotePrefill {
        UserNotePrefill(
            id: "cross-reference-note-\(connectionID)",
            title: title,
            body: body(),
            passageReference: source
        )
    }
}

/// Saved connections used to have a "My Takeaway" box. Takeaways now belong in Notes, where
/// they can be searched and exported, so this moves each one into a note and clears the box.
///
/// The `takeaway` property stays on `SavedCrossReference` so the iCloud store keeps its shape;
/// running this after each sync also moves takeaways written in an older version of the app.
@MainActor
enum SavedConnectionTakeawayMigration {
    private static var isRunning = false

    static func run(in context: ModelContext) async {
        // A sync can finish while launch maintenance is still running; one pass at a time
        // keeps a takeaway from becoming two notes.
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }

        let descriptor = FetchDescriptor<SavedCrossReference>(
            predicate: #Predicate { $0.takeaway != "" }
        )
        guard let saved = try? context.fetch(descriptor), !saved.isEmpty else { return }

        // Every connection, including ones the explorer hides as covered by a wider one,
        // so each saved ID can be named.
        let records = await ChapterInsightsRepository.shared.allCrossReferences()
        let connections = Dictionary(
            CrossReferenceExplorerEntry.expanded(records).map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        for savedConnection in saved {
            let thoughts = savedConnection.takeaway.trimmingCharacters(in: .whitespacesAndNewlines)
            savedConnection.takeaway = ""
            guard !thoughts.isEmpty else { continue }

            let note = UserNote()
            if let entry = connections[savedConnection.entryID] {
                let connectionNote = ScriptureConnectionNote(entry: entry)
                note.title = connectionNote.title
                note.content = connectionNote.body(thoughts: thoughts)
                note.passageReference = connectionNote.source
            } else {
                note.title = String(localized: "Scripture Connection Takeaway")
                note.content = thoughts
            }
            note.createdAt = savedConnection.savedAt ?? Date()
            context.insert(note)
        }
        context.saveLoggingErrors()
    }
}
