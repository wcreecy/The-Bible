import Foundation

/// Links handled by ContentView, from widgets and other custom URLs.
/// Passage links (`thebible://ref?...`) are parsed by BibleReferenceLinker instead.
enum AppDeepLink: Equatable {
    /// `thebible://home`
    case home
    /// `thebible://open?book=Name&chapter=Int&verse=Int`
    case open(book: String, chapter: Int, verse: Int)
    /// `thebible://plan?id=PlanID&read=1`: a reading plan, or with `read=1` its next reading.
    case readingPlan(id: String?, opensReading: Bool)

    init?(url: URL) {
        guard url.scheme?.lowercased() == "thebible" else { return nil }
        let host = url.host?.lowercased() ?? ""

        if host == "home" {
            self = .home
            return
        }

        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        var params: [String: String] = [:]
        comps.queryItems?.forEach { params[$0.name.lowercased()] = $0.value ?? "" }

        if host == "plan" {
            let id = params["id"].flatMap { $0.isEmpty ? nil : $0 }
            self = .readingPlan(id: id, opensReading: params["read"] == "1")
            return
        }

        guard host == "open" else { return nil }
        guard
            let book = params["book"], !book.isEmpty,
            let chapStr = params["chapter"], let chapter = Int(chapStr),
            let verseStr = params["verse"], let verse = Int(verseStr)
        else { return nil }

        self = .open(book: book, chapter: chapter, verse: verse)
    }
}
