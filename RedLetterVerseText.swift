import SwiftUI

enum RedLetterText {
    /// Settings key for showing translator-supplied words in italics (off by default).
    static let suppliedWordsInItalicsKey = "showSuppliedWordsInItalics"

    static func attributedText(
        _ text: String,
        redLetterRanges: [Range<Int>],
        suppliedWordRanges: [Range<Int>] = [],
        italicizesSuppliedWords: Bool = false
    ) -> AttributedString {
        var attributedText = AttributedString(text)

        for range in redLetterRanges {
            guard let attributedRange = attributedRange(for: range, in: text, attributedText: attributedText) else {
                continue
            }
            attributedText[attributedRange].foregroundColor = .red
        }

        if italicizesSuppliedWords {
            for range in suppliedWordRanges {
                guard let attributedRange = attributedRange(for: range, in: text, attributedText: attributedText) else {
                    continue
                }
                // An emphasis intent italicizes while keeping the surrounding font and size.
                attributedText[attributedRange].inlinePresentationIntent = .emphasized
            }
        }

        return attributedText
    }

    private static func attributedRange(
        for range: Range<Int>,
        in text: String,
        attributedText: AttributedString
    ) -> Range<AttributedString.Index>? {
        let lowerBound = String.Index(utf16Offset: range.lowerBound, in: text)
        let upperBound = String.Index(utf16Offset: range.upperBound, in: text)
        return Range(lowerBound..<upperBound, in: attributedText)
    }
}

extension Verse {
    var redLetterAttributedText: AttributedString {
        attributedText(italicizingSuppliedWords: false)
    }

    func attributedText(italicizingSuppliedWords: Bool) -> AttributedString {
        RedLetterText.attributedText(
            text,
            redLetterRanges: redLetterRanges,
            suppliedWordRanges: suppliedWordRanges,
            italicizesSuppliedWords: italicizingSuppliedWords
        )
    }
}
