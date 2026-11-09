import Foundation

/// The translation abbreviation widgets show beside a reference. The widget extension doesn't
/// include the app's `BibleTranslation`, so this reads the values the app copies into the app
/// group: `bibleTranslation` (the active translation), and the translation saved with the
/// bookmark and the pinned verse. Widget data from before translations existed is KJV.
enum WidgetTranslationTag {
    /// Text that follows the active translation: Verse of the Day and the lock screen verse.
    static var active: String { tag(forKey: "bibleTranslation") }
    /// The pinned verse widget keeps the text the verse was pinned with.
    static var pinned: String { tag(forKey: "pinnedVerseTranslation") }

    /// The tag for a stored translation value, such as "kjv". The Continue Reading widget's text
    /// is in the bookmark's translation or the active one, so it passes the value it was given.
    static func tag(for storedTranslation: String) -> String {
        storedTranslation.uppercased()
    }

    /// Same abbreviations as `BibleTranslation.abbreviation`.
    private static func tag(forKey key: String) -> String {
        tag(for: UserDefaults(suiteName: "group.bible.app")?.string(forKey: key) ?? "kjv")
    }
}
