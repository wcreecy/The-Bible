import Foundation

/// A Bible translation the app can bundle. Adding one is: build its text with
/// `Scripts/build_translation.py`, then add a case here.
///
/// Raw values are stored (in defaults and on saved verses), so never change one.
nonisolated enum BibleTranslation: String, CaseIterable, Identifiable, Sendable {
    case kjv
    case asv
    case web

    static let `default`: BibleTranslation = .kjv

    var id: String { rawValue }

    /// Short name shown beside references, such as "KJV".
    var abbreviation: String {
        switch self {
        case .kjv: "KJV"
        case .asv: "ASV"
        case .web: "WEB"
        }
    }

    var name: String {
        switch self {
        case .kjv: "King James Version"
        case .asv: "American Standard Version"
        case .web: "World English Bible"
        }
    }

    /// Copyright or license line for the translation.
    var notice: String {
        switch self {
        case .kjv: "Public domain."
        case .asv: "1901. Public domain."
        case .web: "Public domain. The name “World English Bible” is reserved for faithful copies of this translation."
        }
    }

    /// Why this translation leaves out the verses it omits (shown where the verse would be).
    /// It's each translation's own reason: the WEB follows the majority of Greek manuscripts,
    /// the ASV the oldest.
    var omissionReason: String {
        switch self {
        case .kjv: "it is part of the text"
        case .asv: "the oldest manuscripts don’t include it"
        case .web: "most Greek manuscripts don’t include it"
        }
    }

    /// The bundled text, in the shape `BibleData.decodeBooks(from:)` reads.
    var resourceName: String {
        "\(abbreviation)Text"
    }

    /// Only the KJV source marks the words of Jesus and the translators' supplied words.
    var hasMarkedWords: Bool {
        self == .kjv
    }

    /// Translations whose text is in this build.
    static var available: [BibleTranslation] {
        allCases.filter { Bundle.main.url(forResource: $0.resourceName, withExtension: "json") != nil }
    }

    /// The abbreviation for a stored raw value, such as a saved verse's translation.
    static func abbreviation(for rawValue: String) -> String {
        BibleTranslation(rawValue: rawValue)?.abbreviation ?? rawValue.uppercased()
    }

    // MARK: - Saved choice

    /// The app group the widgets read, so they show the same translation as the app.
    static let sharedDefaults = UserDefaults(suiteName: "group.bible.app")
    /// Same value as `AppStorageKey.bibleTranslation`, readable off the main actor.
    private static let storageKey = "bibleTranslation"

    /// The translation the person chose, or the default when none is saved or its text
    /// isn't in this build.
    static var saved: BibleTranslation {
        guard let translation = sharedDefaults?.string(forKey: storageKey)
            .flatMap(BibleTranslation.init(rawValue:)),
              available.contains(translation) else { return .default }
        return translation
    }

    static func save(_ translation: BibleTranslation) {
        sharedDefaults?.set(translation.rawValue, forKey: storageKey)
    }
}
