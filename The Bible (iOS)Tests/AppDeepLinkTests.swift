import Foundation
import Testing
@testable import Bible

struct AppDeepLinkTests {
    @Test
    func homeLinkOpensHome() throws {
        let url = try #require(URL(string: "thebible://home"))
        #expect(AppDeepLink(url: url) == .home)
    }

    @Test
    func openLinkCarriesTheVerse() throws {
        let url = try #require(URL(string: "thebible://open?book=John&chapter=3&verse=16"))
        #expect(AppDeepLink(url: url) == .open(book: "John", chapter: 3, verse: 16))
    }

    @Test
    func schemeHostAndParameterNamesIgnoreCase() throws {
        let url = try #require(URL(string: "TheBible://OPEN?Book=1%20John&CHAPTER=4&Verse=8"))
        #expect(AppDeepLink(url: url) == .open(book: "1 John", chapter: 4, verse: 8))
    }

    @Test
    func incompleteOrForeignLinksAreIgnored() throws {
        let rejected = [
            "thebible://open?book=John&chapter=3",
            "thebible://open?book=&chapter=3&verse=16",
            "thebible://open?book=John&chapter=three&verse=16",
            "thebible://ref?book=John&chapter=3&start=16",
            "https://open?book=John&chapter=3&verse=16"
        ]
        for string in rejected {
            let url = try #require(URL(string: string))
            #expect(AppDeepLink(url: url) == nil, "\(string)")
        }
    }
}
