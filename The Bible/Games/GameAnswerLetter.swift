import Foundation

/// The A–D labels on multiple-choice answers (Quiz, Trivia), and the keys that pick them.
enum GameAnswerLetter {
    static let letters = ["A", "B", "C", "D"]

    /// "A" for the first answer; past D, the answer's number.
    static func letter(for index: Int) -> String {
        letters.indices.contains(index) ? letters[index] : "\(index + 1)"
    }

    /// The answer a hardware key picks: 1–4 or A–D.
    static func index(forKey characters: String) -> Int? {
        guard let key = characters.uppercased().first else { return nil }
        if let number = key.wholeNumberValue, (1...letters.count).contains(number) { return number - 1 }
        return letters.firstIndex(of: String(key))
    }
}
