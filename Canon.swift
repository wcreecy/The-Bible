import Foundation

enum Testament: String {
    case old
    case new
}

struct Canon {
    // Full book names, matching BibleData/BibleLibrary construction
    static let old: Set<String> = [
        "Genesis","Exodus","Leviticus","Numbers","Deuteronomy",
        "Joshua","Judges","Ruth",
        "1 Samuel","2 Samuel",
        "1 Kings","2 Kings",
        "1 Chronicles","2 Chronicles",
        "Ezra","Nehemiah","Esther",
        "Job","Psalms","Proverbs","Ecclesiastes","Song of Solomon",
        "Isaiah","Jeremiah","Lamentations","Ezekiel","Daniel",
        "Hosea","Joel","Amos","Obadiah","Jonah",
        "Micah","Nahum","Habakkuk","Zephaniah",
        "Haggai","Zechariah","Malachi"
    ]

    static let new: Set<String> = [
        "Matthew","Mark","Luke","John","Acts","Romans",
        "1 Corinthians","2 Corinthians","Galatians","Ephesians",
        "Philippians","Colossians","1 Thessalonians","2 Thessalonians",
        "1 Timothy","2 Timothy","Titus","Philemon","Hebrews",
        "James","1 Peter","2 Peter","1 John","2 John","3 John",
        "Jude","Revelation"
    ]

    static func isOld(_ bookName: String) -> Bool {
        old.contains(bookName)
    }

    static func testament(for bookName: String) -> Testament? {
        if old.contains(bookName) { return .old }
        if new.contains(bookName) { return .new }
        return nil
    }
}
