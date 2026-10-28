import Foundation
import Testing
import UIKit
@testable import Bible

@MainActor
struct SearchAndBackgroundPerformanceTests {
    // MARK: - Search index

    /// Every verse that has a word starting with each token, in Bible order.
    private func bruteForceMatches(
        tokens: [String],
        books: [Book],
        allowedBookIndices: Range<Int>? = nil
    ) -> [String] {
        var ids: [String] = []
        for (bookIndex, book) in books.enumerated() {
            if let allowedBookIndices, !allowedBookIndices.contains(bookIndex) { continue }
            for chapter in book.chapters {
                for verse in chapter.verses {
                    let words = BibleSearchTokenizer.tokens(in: verse.text)
                    if tokens.allSatisfy({ token in words.contains { $0.hasPrefix(token) } }) {
                        ids.append("\(bookIndex):\(chapter.number):\(verse.number)")
                    }
                }
            }
        }
        return ids
    }

    @Test(arguments: [["t"], ["lord", "god"], ["beginning"], ["in", "the", "begin"], ["xyzzy"]])
    func searchIndexMatchesBruteForceInBibleOrder(tokens: [String]) async {
        let books = await BibleRepository.shared.loadAllBooks()
        let expected = bruteForceMatches(tokens: tokens, books: books)

        let found = await BibleSearchIndex.shared.search(
            tokens: tokens,
            allowedBookIndices: nil,
            maxResults: 201
        )

        #expect(found.map(\.id) == Array(expected.prefix(201)))
    }

    @Test
    func searchIndexRespectsBookRange() async {
        let books = await BibleRepository.shared.loadAllBooks()
        let matthewIndex = books.firstIndex { $0.name == "Matthew" } ?? books.count
        let newTestament = matthewIndex..<books.count
        let expected = bruteForceMatches(tokens: ["love"], books: books, allowedBookIndices: newTestament)

        let found = await BibleSearchIndex.shared.search(
            tokens: ["love"],
            allowedBookIndices: newTestament,
            maxResults: 50
        )

        #expect(!found.isEmpty)
        #expect(found.map(\.id) == Array(expected.prefix(50)))
    }

    @Test
    func entryBitSetIntersectsAndWalksInOrder() {
        var first = EntryBitSet(capacity: 200)
        var second = EntryBitSet(capacity: 200)
        for position in [3, 64, 65, 130, 199] { first.insert(position) }
        for position in [4, 64, 130, 150, 199] { second.insert(position) }

        first.formIntersection(second)

        var visited: [Int] = []
        first.forEachEntryID { visited.append($0); return true }
        #expect(visited == [64, 130, 199])

        var firstOnly: [Int] = []
        first.forEachEntryID { firstOnly.append($0); return false }
        #expect(firstOnly == [64])

        var empty = EntryBitSet(capacity: 200)
        #expect(empty.isEmpty)
        empty.insert(7)
        #expect(!empty.isEmpty)
    }

    // MARK: - Background photos

    private func writeTestPhoto(width: Int, height: Int) throws -> String {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
        let image = renderer.image { context in
            UIColor.orange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        let data = try #require(image.jpegData(compressionQuality: 0.8))
        return try AppBackgroundStorage.savePhotoData(data)
    }

    private func removeTestPhoto(named fileName: String) throws {
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        try? FileManager.default.removeItem(
            at: support.appendingPathComponent("TabBackgrounds").appendingPathComponent(fileName)
        )
    }

    @Test
    func backgroundPhotoIsDownsampledAndCached() throws {
        let fileName = try writeTestPhoto(width: 4000, height: 2000)
        defer { try? removeTestPhoto(named: fileName) }

        let first = try #require(AppBackgroundStorage.image(named: fileName))
        let second = try #require(AppBackgroundStorage.image(named: fileName))

        #expect(max(first.size.width, first.size.height) <= 3000)
        #expect(first === second)
        #expect(AppBackgroundStorage.averageLuminance(ofImageNamed: fileName) != nil)
    }

    @Test
    func smallBackgroundPhotoIsNotScaledUp() throws {
        let fileName = try writeTestPhoto(width: 600, height: 400)
        defer { try? removeTestPhoto(named: fileName) }

        let image = try #require(AppBackgroundStorage.image(named: fileName))

        #expect(image.size.width == 600)
        #expect(image.size.height == 400)
    }

    @Test
    func importedPhotoIsScaledDownBeforeSaving() throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let large = UIGraphicsImageRenderer(size: CGSize(width: 5000, height: 2500), format: format).image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 5000, height: 2500))
        }
        let source = try #require(large.jpegData(compressionQuality: 0.9))

        let imported = try #require(AppBackgroundStorage.importedPhotoJPEGData(from: source))
        let decoded = try #require(UIImage(data: imported))

        #expect(max(decoded.size.width, decoded.size.height) <= 3000)
    }

    // MARK: - Game data loading

    @Test
    func concurrentGameDataLoadsAgree() async {
        async let first = GameDataLoaders.loadCharactersAsync()
        async let second = GameDataLoaders.loadCharactersAsync()
        let (a, b) = await (first, second)

        #expect(!a.isEmpty)
        #expect(a == b)
    }
}
