import Foundation

/// Builds a standardized shareable string for a verse reference and its text.
/// Example: "\"In the beginning...\" — Genesis 1:1"
public func shareText(bookName: String, chapter: Int, verse: Int, text: String) -> String {
    "“\(text)” — \(bookName) \(chapter):\(verse)"
}
