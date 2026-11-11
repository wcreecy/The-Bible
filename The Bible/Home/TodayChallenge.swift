import Foundation

enum TodayChallengeKind: String, Codable {
    case readChapter
    case studyChapter
    case playGame
    case prayerTimer
    case reflection
    case favoriteVerse
    case highlightVerse
}

struct TodayChallenge: Identifiable, Codable, Equatable {
    let id: UUID
    var kind: TodayChallengeKind
    let title: String
    let detail: String
    let bookName: String?
    let chapterNumber: Int?
    let gameName: String?
    let minimumMinutes: Int?
    var isCompleted: Bool
}
