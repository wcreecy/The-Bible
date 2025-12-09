import Foundation

// Shared helper to build a shareable verse string.
// Keep internal so it’s visible within the app target and any extensions that include this file.
internal func shareText(bookName: String, chapter: Int, verse: Int, text: String) -> String {
    "“\(text)” — \(bookName) \(chapter):\(verse)"
}
