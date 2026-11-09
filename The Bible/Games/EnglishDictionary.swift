import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Checks words against the system's English spelling dictionary. WORD uses it to accept
/// guesses, and Scramble to accept another real word spelled from the same letters.
enum EnglishDictionary {
    #if canImport(UIKit)
    /// US English when available, otherwise any English the system has.
    static var spellCheckLanguage: String {
        let languages = UITextChecker.availableLanguages

        return languages.first {
            $0.replacingOccurrences(of: "-", with: "_")
                .caseInsensitiveCompare("en_US") == .orderedSame
        } ?? languages.first {
            $0.lowercased().hasPrefix("en")
        } ?? "en_US"
    }
    #endif

    /// True when `word` is spelled correctly. Only plain letters count, so an empty or
    /// punctuated string is never a word.
    static func contains(_ word: String) -> Bool {
        let lower = word.lowercased()
        guard !lower.isEmpty, lower.unicodeScalars.allSatisfy({ CharacterSet.lowercaseLetters.contains($0) }) else {
            return false
        }
        #if canImport(UIKit)
        let checker = UITextChecker()
        let range = NSRange(location: 0, length: lower.utf16.count)
        let misspelled = checker.rangeOfMisspelledWord(
            in: lower, range: range, startingAt: 0, wrap: false, language: spellCheckLanguage
        )
        return misspelled.location == NSNotFound
        #else
        return true
        #endif
    }
}
