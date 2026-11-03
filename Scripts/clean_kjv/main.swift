// Pre-cleans the Bible text the app bundles, so it doesn't clean every verse at launch.
//
// Reads the raw source (`The Bible/kjv.json`, which the other scripts edit) and writes
// `The Bible/KJVText.json`. Run from the repo root after changing kjv.json:
//
//   swiftc -O "The Bible/Bible/KJVTextCleaner.swift" Scripts/clean_kjv/main.swift -o /tmp/clean_kjv && /tmp/clean_kjv
//
// Output: the same books as the source, with each verse as `[text]`, or as
// `[text, [redLetterStart, end, …], [suppliedStart, end, …]]` when it has marked words.
// Offsets are UTF-16, as `KJVTextCleaner` produces them. `KJVTextBundleTests` fails if
// the bundled file doesn't match a fresh run of this script.

import Foundation

struct SourceBook: Decodable {
    let abbrev: String
    let name: String?
    let chapters: [[String]]
}

let arguments = CommandLine.arguments.dropFirst()
let inputURL = URL(fileURLWithPath: arguments.first ?? "The Bible/kjv.json")
let outputURL = URL(fileURLWithPath: arguments.dropFirst().first ?? "The Bible/KJVText.json")

func flattened(_ ranges: [Range<Int>]) -> [Int] {
    ranges.flatMap { [$0.lowerBound, $0.upperBound] }
}

do {
    let books = try JSONDecoder().decode([SourceBook].self, from: Data(contentsOf: inputURL))
    let output: [[String: Any]] = books.map { book in
        var entry: [String: Any] = [
            "abbrev": book.abbrev,
            "chapters": book.chapters.map { verses in
                verses.map { raw -> [Any] in
                    let cleaned = KJVTextCleaner.clean(raw)
                    if cleaned.redLetterRanges.isEmpty && cleaned.suppliedWordRanges.isEmpty {
                        return [cleaned.text]
                    }
                    return [cleaned.text, flattened(cleaned.redLetterRanges), flattened(cleaned.suppliedWordRanges)]
                }
            }
        ]
        if let name = book.name { entry["name"] = name }
        return entry
    }
    let data = try JSONSerialization.data(withJSONObject: output, options: [.sortedKeys, .withoutEscapingSlashes])
    try data.write(to: outputURL, options: .atomic)
    let verseCount = books.reduce(0) { $0 + $1.chapters.reduce(0) { $0 + $1.count } }
    print("Wrote \(verseCount) verses from \(books.count) books to \(outputURL.path) (\(data.count) bytes).")
} catch {
    FileHandle.standardError.write(Data("clean_kjv failed: \(error)\n".utf8))
    exit(1)
}
