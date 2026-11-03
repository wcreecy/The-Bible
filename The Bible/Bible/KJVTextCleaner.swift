import Foundation

// Shared by the app, which cleans saved verse text from older versions, and by
// Scripts/clean_kjv, which pre-cleans the bundled Bible text. Keep it Foundation-only.

/// Removes the KJV source's markup in one pass so verse text reads cleanly everywhere,
/// recording where the marked words were:
/// - U+E000…U+E001 bracket the words of Jesus → `redLetterRanges`.
/// - `{are}`-style braces mark words the translators supplied → kept, `suppliedWordRanges`.
/// - `{word: or, alternative}`-style braces are footnotes → removed.
/// Ranges are UTF-16 offsets into the cleaned text.
nonisolated enum KJVTextCleaner {
    struct Result {
        let text: String
        let redLetterRanges: [Range<Int>]
        let suppliedWordRanges: [Range<Int>]
    }

    private static let redLetterStart: Character = "\u{E000}"
    private static let redLetterEnd: Character = "\u{E001}"

    static func clean(_ raw: String) -> Result {
        // Fast path for verses without markup.
        guard raw.contains(where: { $0 == "{" || $0 == "}" || $0 == redLetterStart || $0 == redLetterEnd }) else {
            return Result(text: raw, redLetterRanges: [], suppliedWordRanges: [])
        }

        let characters = Array(raw)
        var output: [Character] = []
        var length = 0  // UTF-16 length of `output`
        var supplied: [Range<Int>] = []
        var redLetter: [Range<Int>] = []
        var redLetterOpen: Int?
        // Length right after the most recent footnote while only plain text has followed it.
        // A stray "}" then means the footnote ran on, so that text is dropped.
        var lengthAfterFootnote: (characters: Int, utf16: Int)?

        func append(_ character: Character) {
            let next: Character
            if character.isWhitespace {
                guard let last = output.last, !last.isWhitespace else { return }
                next = " "
            } else {
                next = character
            }
            output.append(next)
            length += next.utf16.count
        }

        func removeTrailingWhitespace() {
            while let last = output.last, last.isWhitespace {
                output.removeLast()
                length -= last.utf16.count
            }
        }

        var index = 0
        while index < characters.count {
            let character = characters[index]

            if character == redLetterStart {
                redLetterOpen = length
                index += 1
                continue
            }
            if character == redLetterEnd {
                if let start = redLetterOpen, length > start { redLetter.append(start..<length) }
                redLetterOpen = nil
                index += 1
                continue
            }

            if character == "{", let close = matchingBrace(in: characters, openingAt: index) {
                let content = characters[(index + 1)..<close]
                if content.contains(":") {
                    // Footnote: drop it along with the space before it.
                    removeTrailingWhitespace()
                    lengthAfterFootnote = (output.count, length)
                } else {
                    let start = length
                    for inner in content where inner != "{" && inner != "}" {
                        append(inner)
                    }
                    if length > start { supplied.append(start..<length) }
                    lengthAfterFootnote = nil
                }
                index = close + 1
                continue
            }

            if character == "{" || character == "}" {
                // Unbalanced brace. After a footnote it marks text that leaked out of it.
                if character == "}", let saved = lengthAfterFootnote {
                    output.removeLast(output.count - saved.characters)
                    length = saved.utf16
                }
                lengthAfterFootnote = nil
                index += 1
                continue
            }

            append(character)
            index += 1
        }

        removeTrailingWhitespace()
        if let start = redLetterOpen, length > start { redLetter.append(start..<length) }

        func clamped(_ ranges: [Range<Int>]) -> [Range<Int>] {
            ranges.compactMap { range in
                let upper = min(range.upperBound, length)
                return upper > range.lowerBound ? range.lowerBound..<upper : nil
            }
        }
        return Result(
            text: String(output),
            redLetterRanges: clamped(redLetter),
            suppliedWordRanges: clamped(supplied)
        )
    }

    /// Index of the brace closing the one at `openIndex`, allowing nested braces.
    private static func matchingBrace(in characters: [Character], openingAt openIndex: Int) -> Int? {
        var depth = 0
        for index in openIndex..<characters.count {
            if characters[index] == "{" { depth += 1 }
            if characters[index] == "}" {
                depth -= 1
                if depth == 0 { return index }
            }
        }
        return nil
    }
}
