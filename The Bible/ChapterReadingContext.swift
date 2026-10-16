/// Chapter-specific context that helps readers interpret a passage in its literary, cultural,
/// and historical setting, loaded from BibleInsights.sqlite.
struct ChapterReadingContext: Equatable, Sendable {
    struct CulturalLens: Identifiable, Equatable, Sendable {
        let title: String
        let reference: String
        let then: String

        var id: String { title }
    }

    let narrativePlacement: String
    let firstCenturyMoment: String
    let originalAudience: String
    let culturalLenses: [CulturalLens]
}
