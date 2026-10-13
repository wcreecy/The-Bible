import Foundation

enum BibleStudyMetadata {
    private static let newTestamentBooks: Set<String> = [
        "Matthew", "Mark", "Luke", "John", "Acts", "Romans", "1 Corinthians", "2 Corinthians",
        "Galatians", "Ephesians", "Philippians", "Colossians", "1 Thessalonians", "2 Thessalonians",
        "1 Timothy", "2 Timothy", "Titus", "Philemon", "Hebrews", "James", "1 Peter", "2 Peter",
        "1 John", "2 John", "3 John", "Jude", "Revelation"
    ]

    static func testament(for bookName: String) -> String {
        newTestamentBooks.contains(bookName) ? "New Testament" : "Old Testament"
    }

    static func genre(for bookName: String) -> String {
        switch bookName {
        case "Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy": "Law"
        case "Joshua", "Judges", "Ruth", "1 Samuel", "2 Samuel", "1 Kings", "2 Kings", "1 Chronicles", "2 Chronicles", "Ezra", "Nehemiah", "Esther", "Acts": "History"
        case "Job", "Psalms", "Proverbs", "Ecclesiastes", "Song of Solomon": "Wisdom & Poetry"
        case "Isaiah", "Jeremiah", "Lamentations", "Ezekiel", "Daniel", "Hosea", "Joel", "Amos", "Obadiah", "Jonah", "Micah", "Nahum", "Habakkuk", "Zephaniah", "Haggai", "Zechariah", "Malachi": "Prophecy"
        case "Matthew", "Mark", "Luke", "John": "Gospel"
        case "Revelation": "Apocalyptic"
        default: "Letter"
        }
    }

    static func readingTip(for bookName: String) -> String {
        switch genre(for: bookName) {
        case "Law": "Read for God’s covenant and the way it shaped Israel’s life together."
        case "History": "Follow the people, setting, and turning points that move the larger story forward."
        case "Wisdom & Poetry": "Read slowly; imagery and parallel lines often carry the point."
        case "Prophecy": "Notice both the original setting and the call to faithfulness and hope."
        case "Gospel": "Watch what Jesus does and says, and how people respond to him."
        case "Apocalyptic": "Read its symbols as a vision of hope and God’s ultimate reign."
        default: "Follow the author’s argument from beginning to end before isolating individual verses."
        }
    }
}
