#!/usr/bin/env swift

import AppKit
import Foundation

private struct BibleBook: Decodable {
    let name: String
    let chapters: [[String]]
}

private struct BibleCharacter: Decodable {
    let name: String
}

private struct BibleLocation: Decodable {
    let locationName: String

    enum CodingKeys: String, CodingKey {
        case locationName = "location_name"
    }
}

private struct ScrambleWord: Encodable {
    let word: String
    let category: String
    let difficulty: String
    let reference: String
}

private struct Candidate {
    let word: String
    var references: [String]

    var difficulty: String {
        switch (word.count, references.count) {
        case (4...5, 30...): "easy"
        case (4...7, 8...): "normal"
        default: "hard"
        }
    }
}

private let excludedWords: Set<String> = [
    "about", "after", "again", "against", "among", "and", "any", "are", "art", "because", "been", "before",
    "being", "but", "can", "could", "did", "doth", "each", "either", "even", "every", "for", "from", "had",
    "has", "hast", "hath", "have", "her", "here", "herself", "him", "himself", "his", "how", "into", "its",
    "let", "like", "may", "mine", "more", "much", "must", "neither", "nor", "not", "now", "off", "one", "only",
    "our", "ourselves", "out", "over", "own", "said", "same", "saith", "saying", "shall", "shalt", "she", "should",
    "such", "than", "that", "the", "thee", "their", "them", "themselves", "then", "there", "therefore", "these",
    "they", "thine", "this", "those", "thou", "thy", "thyself", "unto", "upon", "very", "was", "were", "what",
    "when", "where", "wherefore", "which", "while", "who", "whom", "whose", "will", "wilt", "with", "within",
    "without", "would", "ye", "yet", "you", "your", "yourselves"
]

private let minimumLength = 4
private let maximumLength = 10
private let minimumVerseAppearances = 2
private let language = "en_US"

private func normalizedSingleWord(_ value: String) -> String? {
    let name = value
        .replacingOccurrences(of: #"\\s*\\([^)]*\\)"#, with: "", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.contains(where: { !$0.isLetter }) else { return nil }
    return name.lowercased()
}

private func category(
    for word: String,
    people: Set<String>,
    places: Set<String>,
    books: Set<String>
) -> String {
    if people.contains(word) { return "Person" }
    if places.contains(word) { return "Place" }
    if books.contains(word) { return "Bible book" }
    return "Everyday word"
}

private func isRecognizedEnglishWord(_ word: String, checker: NSSpellChecker) -> Bool {
    let range = checker.checkSpelling(
        of: word,
        startingAt: 0,
        language: language,
        wrap: false,
        inSpellDocumentWithTag: 0,
        wordCount: nil
    )
    return range.location == NSNotFound
}

private func candidates(from books: [BibleBook]) -> [Candidate] {
    var referencesByWord: [String: [String]] = [:]

    for book in books {
        for (chapterOffset, verses) in book.chapters.enumerated() {
            for (verseOffset, verse) in verses.enumerated() {
                let cleaned = verse.replacingOccurrences(
                    of: "\\{[^}]*\\}",
                    with: "",
                    options: .regularExpression
                )
                let tokens = cleaned.components(separatedBy: CharacterSet.letters.inverted)
                let reference = "\(book.name) \(chapterOffset + 1):\(verseOffset + 1)"
                let uniqueWords = Set(tokens.compactMap { token -> String? in
                    let word = token.lowercased()
                    guard (minimumLength...maximumLength).contains(word.count),
                          !excludedWords.contains(word) else {
                        return nil
                    }
                    return word
                })

                for word in uniqueWords {
                    referencesByWord[word, default: []].append(reference)
                }
            }
        }
    }

    return referencesByWord.compactMap { word, references in
        guard references.count >= minimumVerseAppearances else { return nil }
        return Candidate(word: word, references: references)
    }
}

private func writeCatalog(_ catalog: [ScrambleWord], to outputURL: URL) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let data = try encoder.encode(catalog)
    try data.write(to: outputURL, options: .atomic)
}

let arguments = CommandLine.arguments.dropFirst()
let inputPath = arguments.first ?? "The Bible/kjv.json"
let outputPath = arguments.dropFirst().first ?? "The Bible/ScrambleWords.json"
let inputURL = URL(fileURLWithPath: inputPath)
let outputURL = URL(fileURLWithPath: outputPath)
let projectDirectory = inputURL.deletingLastPathComponent()
let charactersURL = projectDirectory.appendingPathComponent("Bible_Characters_Game_Clues_With_Difficulty.json")
let locationsURL = projectDirectory.appendingPathComponent("bible_locations.json")

do {
    let data = try Data(contentsOf: inputURL)
    let books = try JSONDecoder().decode([BibleBook].self, from: data)
    let people = Set(
        try JSONDecoder().decode([BibleCharacter].self, from: Data(contentsOf: charactersURL))
            .compactMap { normalizedSingleWord($0.name) }
    )
    let places = Set(
        try JSONDecoder().decode([BibleLocation].self, from: Data(contentsOf: locationsURL))
            .compactMap { normalizedSingleWord($0.locationName) }
    )
    let bookNames = Set(books.compactMap { normalizedSingleWord($0.name) })
    let checker = NSSpellChecker.shared
    let eligible = candidates(from: books)
    let catalog = eligible
        .filter { isRecognizedEnglishWord($0.word, checker: checker) }
        .sorted {
            if $0.difficulty != $1.difficulty { return $0.difficulty < $1.difficulty }
            if $0.references.count != $1.references.count { return $0.references.count > $1.references.count }
            return $0.word < $1.word
        }
        .map {
            ScrambleWord(
                word: $0.word.capitalized,
                category: category(for: $0.word, people: people, places: places, books: bookNames),
                difficulty: $0.difficulty,
                reference: $0.references[0]
            )
        }

    try writeCatalog(catalog, to: outputURL)

    let counts = Dictionary(grouping: catalog, by: \.difficulty).mapValues(\.count)
    print("Wrote \(catalog.count) Scramble words to \(outputURL.path)")
    print("Easy: \(counts["easy", default: 0]), Normal: \(counts["normal", default: 0]), Hard: \(counts["hard", default: 0])")
} catch {
    fputs("Failed to generate Scramble words: \(error)\\n", stderr)
    exit(1)
}
