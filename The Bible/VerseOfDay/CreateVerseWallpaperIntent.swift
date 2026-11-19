import AppIntents
import Foundation
import UIKit
import UniformTypeIdentifiers

/// Renders the Verse of the Day as a wallpaper sized for this device, styled like the last verse
/// image the person made. Apps can't set the wallpaper themselves, but Shortcuts' Set Wallpaper
/// Photo action can, so pairing the two in an automation gives a new Lock Screen verse every day.
struct CreateVerseWallpaperIntent: AppIntent {
    static let title: LocalizedStringResource = "Create Verse Wallpaper"
    static let description = IntentDescription(
        "Makes a Lock Screen wallpaper of the Verse of the Day, styled like your last verse image. Follow it with Set Wallpaper Photo to use it."
    )
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Pick a New Verse First", default: false)
    var picksNewVerse: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Create a verse wallpaper") {
            \.$picksNewVerse
        }
    }

    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        if picksNewVerse {
            _ = try await RefreshVerseOfDayIntent().perform()
        }

        let data = try await MainActor.run { try Self.renderVerseOfDayWallpaper() }
        return .result(value: IntentFile(data: data, filename: "Verse Wallpaper.png", type: .png))
    }

    /// The composer model, SwiftUI rendering, and app storage keys all live on the main actor.
    @MainActor
    private static func renderVerseOfDayWallpaper() throws -> Data {
        let defaults = UserDefaults.standard
        let book = defaults.string(forKey: AppStorageKey.verseOfDayBook) ?? ""
        let text = defaults.string(forKey: AppStorageKey.verseOfDayText) ?? ""
        let chapter = defaults.integer(forKey: AppStorageKey.verseOfDayChapter)
        let verseNumber = defaults.integer(forKey: AppStorageKey.verseOfDayNumber)
        guard !book.isEmpty, !text.isEmpty, chapter > 0, verseNumber > 0 else {
            throw CreateVerseWallpaperError.noVerseOfDay
        }

        let model = VerseImageComposerModel(verse: VerseActionReference(
            bookName: book,
            chapterNumber: chapter,
            verseNumber: verseNumber,
            verseText: text
        ))
        model.format = .wallpaper
        model.formatDidChange()
        guard let data = model.render()?.pngData() else {
            throw CreateVerseWallpaperError.couldNotRender
        }
        return data
    }
}

enum CreateVerseWallpaperError: Error, CustomLocalizedStringResourceConvertible {
    case noVerseOfDay
    case couldNotRender

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .noVerseOfDay: "There’s no Verse of the Day yet. Open The Bible once, or turn on Pick a New Verse First."
        case .couldNotRender: "The wallpaper couldn’t be created."
        }
    }
}
