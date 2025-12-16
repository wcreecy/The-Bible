import Foundation

// Shared helper: extract unique ScriptureRef list from a linkified AttributedString
enum ScriptureRefExtractor {
    static func refs(in attributed: AttributedString) -> [ScriptureRef] {
        var results: [ScriptureRef] = []
        var seen: Set<String> = []
        for run in attributed.runs {
            if let url = run.link, let ref = BibleReferenceLinker.parse(url: url) {
                let key: String = {
                    if let end = ref.endVerse, end != ref.startVerse {
                        return "\(ref.bookName) \(ref.chapter):\(ref.startVerse)-\(end)"
                    } else {
                        return "\(ref.bookName) \(ref.chapter):\(ref.startVerse)"
                    }
                }()
                if !seen.contains(key) {
                    seen.insert(key)
                    results.append(ref)
                }
            }
        }
        return results
    }
}
