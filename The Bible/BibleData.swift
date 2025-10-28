import Foundation

struct Verse: Identifiable, Hashable {
    let id = UUID()
    let number: Int
    let text: String
}

struct Chapter: Identifiable, Hashable {
    let id = UUID()
    let number: Int
    let verses: [Verse]
}

struct Book: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let chapters: [Chapter]
}

// DTOs matching the provided KJV JSON structure: [{ abbrev: String, chapters: [[String]], name?: String }]
private struct KJVBookDTO: Decodable {
    let abbrev: String
    let chapters: [[String]]
    let name: String?
}

private enum BookNames {
    // Map common abbreviations to full names.
    static let map: [String: String] = [
        // Old Testament
        "gn": "Genesis", "ex": "Exodus", "lev": "Leviticus", "num": "Numbers", "de": "Deuteronomy",
        "jos": "Joshua", "jdg": "Judges", "ru": "Ruth",
        "1sa": "1 Samuel", "2sa": "2 Samuel",
        "1ki": "1 Kings", "2ki": "2 Kings",
        "1ch": "1 Chronicles", "2ch": "2 Chronicles",
        "ezr": "Ezra", "ne": "Nehemiah", "es": "Esther",
        "job": "Job", "ps": "Psalms", "pr": "Proverbs", "ec": "Ecclesiastes", "so": "Song of Solomon",
        "is": "Isaiah", "je": "Jeremiah", "la": "Lamentations", "eze": "Ezekiel", "da": "Daniel",
        "ho": "Hosea", "joe": "Joel", "am": "Amos", "ob": "Obadiah", "jon": "Jonah",
        "mic": "Micah", "na": "Nahum", "hab": "Habakkuk", "zep": "Zephaniah",
        "hag": "Haggai", "zec": "Zechariah", "mal": "Malachi",
        // New Testament
        "mt": "Matthew", "mr": "Mark", "lu": "Luke", "joh": "John",
        "ac": "Acts", "ro": "Romans",
        "1co": "1 Corinthians", "2co": "2 Corinthians",
        "ga": "Galatians", "eph": "Ephesians", "php": "Philippians", "col": "Colossians",
        "1th": "1 Thessalonians", "2th": "2 Thessalonians",
        "1ti": "1 Timothy", "2ti": "2 Timothy",
        "tit": "Titus", "phm": "Philemon",
        "heb": "Hebrews", "jas": "James",
        "1pe": "1 Peter", "2pe": "2 Peter",
        "1jo": "1 John", "2jo": "2 John", "3jo": "3 John",
        "jude": "Jude", "re": "Revelation"
    ]

    static func fullName(for abbrev: String) -> String {
        map[abbrev.lowercased()] ?? abbrev.uppercased()
    }
}

enum BibleData {
    static let books: [Book] = {
        // Try to load kjv.json from the app bundle
        if let url = Bundle.main.url(forResource: "kjv", withExtension: "json") {
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                let dtoBooks = try decoder.decode([KJVBookDTO].self, from: data)
                return dtoBooks.enumerated().map { (_, dto) in
                    let fullName = dto.name ?? BookNames.fullName(for: dto.abbrev)
                    return Book(
                        name: fullName,
                        chapters: dto.chapters.enumerated().map { (chapterIndex, versesArray) in
                            Chapter(
                                number: chapterIndex + 1,
                                verses: versesArray.enumerated().map { (verseIndex, text) in
                                    Verse(number: verseIndex + 1, text: text)
                                }
                            )
                        }
                    )
                }
            } catch {
                // If decoding fails, fall back to sample
                print("Failed to load kjv.json: \(error)")
            }
        }

        // Minimal sample data to demonstrate the flow if kjv.json isn't available.
        return [
            Book(
                name: "Genesis",
                chapters: [
                    Chapter(number: 1, verses: (1...31).map { Verse(number: $0, text: "Genesis 1:\($0) text") }),
                    Chapter(number: 2, verses: (1...25).map { Verse(number: $0, text: "Genesis 2:\($0) text") }),
                    Chapter(number: 3, verses: (1...24).map { Verse(number: $0, text: "Genesis 3:\($0) text") })
                ]
            ),
            Book(
                name: "Exodus",
                chapters: [
                    Chapter(number: 1, verses: (1...22).map { Verse(number: $0, text: "Exodus 1:\($0) text") }),
                    Chapter(number: 2, verses: (1...25).map { Verse(number: $0, text: "Exodus 2:\($0) text") })
                ]
            ),
            Book(
                name: "Matthew",
                chapters: [
                    Chapter(number: 1, verses: (1...25).map { Verse(number: $0, text: "Matthew 1:\($0) text") }),
                    Chapter(number: 2, verses: (1...23).map { Verse(number: $0, text: "Matthew 2:\($0) text") })
                ]
            )
        ]
    }()
}
