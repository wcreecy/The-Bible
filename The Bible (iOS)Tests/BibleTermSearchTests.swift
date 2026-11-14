import Testing
@testable import Bible

struct BibleTermSearchTests {
    private func term(
        id: String,
        title: String,
        aliases: [String] = [],
        references: [String] = []
    ) -> BibleTerm {
        BibleTerm(
            id: id,
            term: title,
            category: "Test",
            description: "Test description",
            aliases: aliases,
            references: references.map {
                BibleTerm.Reference(reference: $0, type: "primary")
            }
        )
    }

    @Test
    func matchingNormalizesApostrophesCaseAndLeadingThe() {
        let lordPrayer = term(
            id: "lord-prayer",
            title: "Lord's Prayer",
            aliases: ["Our Father"]
        )
        let index = BibleTermMatcher.index([lordPrayer])

        let matches = BibleTermMatcher.matches(
            for: "the Lord’s Prayer",
            in: index
        )

        #expect(matches.map(\.id) == ["lord-prayer"])
    }

    @Test
    func matchingSupportsAliasesAndWordPrefixes() {
        let sermon = term(
            id: "sermon",
            title: "Sermon on the Mount",
            aliases: ["Jesus' sermon"]
        )
        let index = BibleTermMatcher.index([sermon])

        #expect(BibleTermMatcher.matches(for: "jesus serm", in: index).map(\.id) == ["sermon"])
        #expect(BibleTermMatcher.matches(for: "jes", in: index).map(\.id) == ["sermon"])
    }

    @Test
    func matchingRejectsQueriesShorterThanThreeCharacters() {
        let term = term(id: "faith", title: "Faith")
        let index = BibleTermMatcher.index([term])

        #expect(BibleTermMatcher.matches(for: "fa", in: index).isEmpty)
    }

    @Test
    func filteringKeepsTopicsWithAtLeastOneInScopeReference() {
        let exodus = term(
            id: "exodus",
            title: "Exodus",
            references: ["Exodus 12:1-28"]
        )
        let mixed = term(
            id: "mixed",
            title: "A Mixed Topic",
            references: ["Genesis 1:1", "Matthew 6:9-13"]
        )

        let oldTestament = BibleTermMatcher.filtered(
            [exodus, mixed],
            to: ["Genesis", "Exodus"]
        )
        let newTestament = BibleTermMatcher.filtered(
            [exodus, mixed],
            to: ["Matthew"]
        )

        #expect(oldTestament.map(\.id) == ["exodus", "mixed"])
        #expect(newTestament.map(\.id) == ["mixed"])
        #expect(BibleTermMatcher.filtered([exodus], to: nil).map(\.id) == ["exodus"])
    }
}
