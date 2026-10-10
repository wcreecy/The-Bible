import SwiftUI

enum RedLetterText {
    static func attributedText(
        _ text: String,
        redLetterRanges: [Range<Int>]
    ) -> AttributedString {
        var attributedText = AttributedString(text)

        for range in redLetterRanges {
            let lowerBound = String.Index(utf16Offset: range.lowerBound, in: text)
            let upperBound = String.Index(utf16Offset: range.upperBound, in: text)
            guard let attributedRange = Range(lowerBound..<upperBound, in: attributedText) else {
                continue
            }
            attributedText[attributedRange].foregroundColor = .red
        }

        return attributedText
    }
}

extension Verse {
    var redLetterAttributedText: AttributedString {
        RedLetterText.attributedText(text, redLetterRanges: redLetterRanges)
    }
}
