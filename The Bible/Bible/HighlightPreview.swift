import SwiftUI

/// The highlight color the Apple Pencil is resting on in the verse action row, so the verse
/// itself can show how it would look. Hovering only previews; a tap still applies the color.
@MainActor
@Observable
final class HighlightPreview {
    static let shared = HighlightPreview()

    private var verseID: String?
    private var color: Color?

    private static func id(bookName: String, chapterNumber: Int, verseNumber: Int) -> String {
        "\(bookName)|\(chapterNumber)|\(verseNumber)"
    }

    func show(_ color: Color, bookName: String, chapterNumber: Int, verseNumber: Int) {
        verseID = Self.id(bookName: bookName, chapterNumber: chapterNumber, verseNumber: verseNumber)
        self.color = color
    }

    func clear() {
        verseID = nil
        color = nil
    }

    func color(bookName: String, chapterNumber: Int, verseNumber: Int) -> Color? {
        verseID == Self.id(bookName: bookName, chapterNumber: chapterNumber, verseNumber: verseNumber) ? color : nil
    }
}

/// Tints a verse row with the previewed highlight color. It's its own view so a change in
/// the preview redraws only this layer, not the verse text.
struct HighlightPreviewWash: View {
    let bookName: String
    let chapterNumber: Int
    let verseNumber: Int

    var body: some View {
        let color = HighlightPreview.shared.color(
            bookName: bookName,
            chapterNumber: chapterNumber,
            verseNumber: verseNumber
        )
        (color?.opacity(0.3) ?? .clear)
            .animation(.easeOut(duration: 0.12), value: color)
            .allowsHitTesting(false)
    }
}
