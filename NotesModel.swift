import Foundation
import SwiftUI
import Combine

public struct Note: Identifiable, Equatable {
    public let id: UUID
    public var content: String
    public var reference: String
    public var createdAt: Date
    public var verse: String

    public init(id: UUID = UUID(), content: String, reference: String, createdAt: Date = Date(), verse: String) {
        self.id = id
        self.content = content
        self.reference = reference
        self.createdAt = createdAt
        self.verse = verse
    }
}

@MainActor
final class NotesStore: ObservableObject {
    static let shared = NotesStore()

    @Published private(set) var notes: [Note]

    init(notes: [Note] = []) {
        if notes.isEmpty {
            // Seed with sample notes for development/demo
            self.notes = [
                Note(content: "This is the first note.\nIt has multiple lines.\nLine three.\nLine four.", reference: "John 3:16", createdAt: Date(), verse: "John 3:16"),
                Note(content: "Second note content\nSecond line", reference: "Psalm 23:1", createdAt: Date().addingTimeInterval(-3600), verse: "Psalm 23:1")
            ]
        } else {
            self.notes = notes
        }
    }

    // MARK: - CRUD

    func addNote(content: String, reference: String, verse: String, createdAt: Date = Date()) {
        let note = Note(content: content, reference: reference, createdAt: createdAt, verse: verse)
        notes.append(note)
    }

    func removeNotes(withIDs ids: Set<UUID>) {
        notes.removeAll { ids.contains($0.id) }
    }

    func removeNote(withID id: UUID) {
        notes.removeAll { $0.id == id }
    }

    func updateNote(_ note: Note) {
        guard let idx = notes.firstIndex(where: { $0.id == note.id }) else { return }
        notes[idx] = note
    }

    // MARK: - Query helpers

    func notesSortedNewestFirst() -> [Note] {
        notes.sorted { $0.createdAt > $1.createdAt }
    }

    func hasNote(for verse: String) -> Bool {
        notes.contains { $0.verse == verse }
    }

    func notes(for verse: String) -> [Note] {
        notes.filter { $0.verse == verse }
            .sorted { $0.createdAt > $1.createdAt }
    }
}
