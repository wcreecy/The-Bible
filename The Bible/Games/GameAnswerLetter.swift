import Foundation

/// Stable letter labels and hardware keys for multiple-choice answers.
enum GameAnswerLetter {
    static let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ").map(String.init)

    /// "A" for the first answer; beyond the alphabet, the answer’s number.
    static func letter(for index: Int) -> String {
        letters.indices.contains(index) ? letters[index] : "\(index + 1)"
    }

    /// Letters select any answer; 1–9 are aliases for the first nine choices.
    static func index(forKey characters: String) -> Int? {
        guard let key = characters.uppercased().first else { return nil }
        if let number = key.wholeNumberValue, (1...9).contains(number) { return number - 1 }
        return letters.firstIndex(of: String(key))
    }
}
