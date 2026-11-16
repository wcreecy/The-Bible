import Testing
@testable import Bible

@MainActor
struct BibleBookGroupTests {
    @Test
    func everyBookIsInExactlyOneGroupInCanonicalOrder() {
        let grouped = BibleBookGroup.grouping(BibleData.books).flatMap(\.books).map(\.name)

        // Same books, none missing or repeated, and still in the Bible's order.
        #expect(grouped == BibleData.books.map(\.name))
    }

    @Test
    func groupsFollowTheirTestament() {
        for book in BibleData.books {
            let group = BibleBookGroup.group(for: book.name)
            #expect(group.testament == Canon.testament(for: book.name), "\(book.name) is in \(group.title)")
        }
    }

    @Test
    func knownBooksLandInTheExpectedGroups() {
        #expect(BibleBookGroup.group(for: "Genesis") == .law)
        #expect(BibleBookGroup.group(for: "Ruth") == .history)
        #expect(BibleBookGroup.group(for: "Psalms") == .wisdomAndPoetry)
        #expect(BibleBookGroup.group(for: "Daniel") == .majorProphets)
        #expect(BibleBookGroup.group(for: "Jonah") == .minorProphets)
        #expect(BibleBookGroup.group(for: "Acts") == .gospelsAndActs)
        #expect(BibleBookGroup.group(for: "Hebrews") == .letters)
        #expect(BibleBookGroup.group(for: "Revelation") == .revelation)
    }
}
