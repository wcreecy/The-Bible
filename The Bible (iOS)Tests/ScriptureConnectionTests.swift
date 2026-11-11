import Foundation
import SwiftData
import Testing
@testable import Bible

@MainActor
struct ScriptureConnectionTests {
    private func passage(_ book: String, _ chapter: Int, _ start: Int?, through endChapter: Int? = nil, _ end: Int? = nil) -> PassageReference {
        PassageReference(
            bookName: book,
            startChapter: chapter,
            startVerse: start,
            endChapter: endChapter ?? chapter,
            endVerse: end ?? start
        )
    }

    private func reference(_ text: String) throws -> ScriptureRef {
        try #require(BibleReferenceLinker.parse(text), "Couldn't read \(text) as a reference")
    }

    @Test
    func searchingAVerseMatchesOnlyPassagesThatIncludeIt() throws {
        let john316 = passage("John", 3, 16)
        #expect(john316.overlaps(try reference("John 3:16")))
        #expect(john316.overlaps(try reference("Jn 3:16")))
        // A plain text match would find these too.
        #expect(!passage("John", 3, 1).overlaps(try reference("John 3:16")))
        #expect(!john316.overlaps(try reference("John 3:1")))
        #expect(!passage("1 John", 3, 1).overlaps(try reference("John 3:1")))
    }

    @Test
    func rangesAndWholeChaptersMatchAnyVerseInside() throws {
        #expect(passage("John", 3, 14, 18).overlaps(try reference("John 3:16")))
        #expect(passage("John", 3, 1).overlaps(try reference("John 3:1-3")))
        #expect(!passage("John", 3, 14, 18).overlaps(try reference("John 3:19")))
        // Romans 8:28-9:5 runs into chapter 9.
        let acrossChapters = passage("Romans", 8, 28, through: 9, 5)
        #expect(acrossChapters.overlaps(try reference("Romans 8:39")))
        #expect(acrossChapters.overlaps(try reference("Romans 9:1")))
        #expect(!acrossChapters.overlaps(try reference("Romans 9:6")))
        #expect(passage("Psalms", 23, nil).overlaps(try reference("Psalm 23:4")))
    }

    @Test
    func savedConnectionIDsStayTheSame() {
        // The first target keeps the record's ID, so connections saved before records were split still match.
        #expect(CrossReferenceExplorerEntry.connectionID(recordID: 42, targetIndex: 0, reference: "Mark 10:6") == 42)
        let second = CrossReferenceExplorerEntry.connectionID(recordID: 42, targetIndex: 1, reference: "Matthew 19:4")
        #expect(second != 42)
        #expect(second == CrossReferenceExplorerEntry.connectionID(recordID: 42, targetIndex: 1, reference: "Matthew 19:4"))
    }

    @Test
    func aConnectionWithoutAnExplanationHasNoTypeAndTheSharedSentence() {
        let unexplained = CrossReferenceExplorerEntry(
            id: 1,
            bookName: "Psalms",
            chapterNumber: 150,
            sourceVerse: 6,
            relatedReference: "Revelation 22:21",
            connectionExplanation: nil
        )
        #expect(unexplained.writtenExplanation == nil)
        #expect(unexplained.connectionType == nil)
        #expect(unexplained.relationshipDescription == ScriptureConnectionText.unexplainedRelationship)
        #expect(!unexplained.relationshipDescription.contains("Genesis"))

        let explained = CrossReferenceExplorerEntry(
            id: 2,
            bookName: "Psalms",
            chapterNumber: 150,
            sourceVerse: 6,
            relatedReference: "Revelation 22:21",
            connectionExplanation: "Hebrews quotes this psalm."
        )
        #expect(explained.connectionType == .quotation)
    }

    @Test
    func noteFromAConnectionIsAboutItsFirstPassage() {
        let note = ScriptureConnectionNote(
            connectionID: 7,
            source: "Genesis 1:27",
            target: "Mark 10:6",
            explanation: "Jesus points back to Genesis."
        )
        #expect(note.title == "Genesis 1:27 → Mark 10:6")
        #expect(note.prefill.passageReference == "Genesis 1:27")
        #expect(note.prefill.body.contains("Jesus points back to Genesis."))
        #expect(note.body(thoughts: "Marriage is God's design.").hasSuffix("Marriage is God's design."))
    }

    @Test
    func takeawaysMoveIntoNotesOnce() async throws {
        let container = try ModelContainer(
            for: SavedCrossReference.self, UserNote.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let entry = try #require(await CrossReferenceExplorerEntry.loadAll().first)

        let withTakeaway = SavedCrossReference(entryID: entry.id, savedAt: Date(timeIntervalSince1970: 1_000))
        withTakeaway.takeaway = "  God made us for each other.  "
        let unknown = SavedCrossReference(entryID: -1)
        unknown.takeaway = "A thought about a connection that no longer exists."
        context.insert(withTakeaway)
        context.insert(unknown)
        context.insert(SavedCrossReference(entryID: entry.id + 1))
        try context.save()

        await SavedConnectionTakeawayMigration.run(in: context)
        await SavedConnectionTakeawayMigration.run(in: context)

        let notes = try context.fetch(FetchDescriptor<UserNote>(sortBy: [SortDescriptor(\.createdAt)]))
        #expect(notes.count == 2)

        let moved = try #require(notes.first { $0.passageReference == entry.sourceReference })
        #expect(moved.title == "\(entry.sourceReference) → \(entry.relatedReference)")
        #expect(moved.content.hasSuffix("God made us for each other."))
        #expect(moved.createdAt == Date(timeIntervalSince1970: 1_000))

        #expect(notes.contains { $0.content == "A thought about a connection that no longer exists." })

        // Every saved connection is still saved, now without a takeaway.
        let saved = try context.fetch(FetchDescriptor<SavedCrossReference>())
        #expect(saved.count == 3)
        #expect(saved.allSatisfy { $0.takeaway.isEmpty })
    }
}
