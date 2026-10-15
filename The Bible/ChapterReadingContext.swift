import SwiftUI

/// Chapter-specific context that helps readers interpret a passage in its literary, cultural,
/// and scriptural setting, loaded from BibleInsights.sqlite.
struct ChapterReadingContext: Equatable, Sendable {
    struct CulturalLens: Identifiable, Equatable, Sendable {
        let title: String
        let reference: String
        let then: String
        let whyItMatters: String

        var id: String { title }
    }

    struct ScriptureConnection: Identifiable, Equatable, Sendable {
        let reference: String
        let explanation: String

        var id: String { reference }
    }

    let narrativePlacement: String
    let firstCenturyMoment: String
    let originalAudience: String
    let culturalLenses: [CulturalLens]
    let scriptureConnections: [ScriptureConnection]
}

/// Old Testament passages the chapter quotes or echoes, with how they are used.
struct ChapterScriptureConnectionsCard: View {
    let connections: [ChapterReadingContext.ScriptureConnection]

    var body: some View {
        HeroCard(title: "Scripture Connections", icon: "arrow.triangle.branch") {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(connections) { connection in
                    VStack(alignment: .leading, spacing: 6) {
                        LinkedScriptureText(connection.reference)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        LinkedScriptureText(connection.explanation)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
