import Testing
@testable import Bible

/// Checks on the bundled `BibleTerms.json`, so a typo in a future edit fails here instead of
/// quietly dropping a passage chip.
@MainActor
struct BibleTermsCatalogTests {
    private func loadedTerms() async -> [BibleTerm] {
        _ = await BibleRepository.shared.loadAllBooks()
        return BibleTermMatcher.loadTerms()
    }

    @Test
    func everyReferenceOpensARealPassage() async {
        let terms = await loadedTerms()
        #expect(!terms.isEmpty)
        for term in terms {
            for reference in term.references {
                #expect(
                    PassageReferenceParser.parse(reference.reference) != nil,
                    "\(term.id): \"\(reference.reference)\" isn't a passage"
                )
            }
        }
    }

    @Test
    func everyTermHasAUniqueIDAndAPassageToOpen() async {
        let terms = await loadedTerms()
        let ids = terms.map(\.id)
        #expect(Set(ids).count == ids.count, "Duplicate term IDs")
        for term in terms {
            #expect(term.primaryPassage != nil, "\(term.id) has no passage to open")
            #expect(
                term.references.allSatisfy { ["primary", "related"].contains($0.type) },
                "\(term.id) has a reference type other than primary or related"
            )
        }
    }
}
