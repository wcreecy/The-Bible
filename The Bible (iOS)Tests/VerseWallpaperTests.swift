import Foundation
import Testing
import UIKit
@testable import Bible

/// The wallpaper canvas, its layout, and the verse image composer's undo history.
///
/// Composer tests set the remembered composer choices aside and put them back afterward,
/// and undo timing runs on a clock the test moves by hand, so nothing waits on real time.
@MainActor
struct VerseWallpaperTests {
    // MARK: Canvas

    @Test
    func phoneCanvasIsTheScreenItself() {
        let canvas = WallpaperCanvas(screenPixels: CGSize(width: 1320, height: 2868), isSquare: false)
        #expect(canvas.pixelSize == CGSize(width: 1320, height: 2868))
        #expect(canvas.contentFraction == 1)
    }

    @Test
    func iPadCanvasIsASquareOfTheLongSide() {
        let canvas = WallpaperCanvas(screenPixels: CGSize(width: 2064, height: 2752), isSquare: true)
        #expect(canvas.pixelSize == CGSize(width: 2752, height: 2752))
        // Only the center square the width of the short side shows in every orientation.
        #expect(abs(canvas.contentFraction - 2064.0 / 2752.0) < 0.0001)
    }

    @Test
    func screenSizesAreTurnedPortrait() {
        #expect(WallpaperCanvas.portraitPixels(CGSize(width: 2868, height: 1320)) == CGSize(width: 1320, height: 2868))
        #expect(WallpaperCanvas.portraitPixels(CGSize(width: 1320, height: 2868)) == CGSize(width: 1320, height: 2868))
    }

    @Test
    func iPadSkipsExternalDisplays() {
        let iPad = CGSize(width: 2064, height: 2752)
        let iPadMini = CGSize(width: 1488, height: 2266)
        let monitor = CGSize(width: 2160, height: 3840)
        #expect(WallpaperCanvas.isDeviceScreen(iPad, isPad: true))
        #expect(WallpaperCanvas.isDeviceScreen(iPadMini, isPad: true))
        #expect(!WallpaperCanvas.isDeviceScreen(monitor, isPad: true))
        // A tall phone screen is never mistaken for a monitor.
        #expect(WallpaperCanvas.isDeviceScreen(CGSize(width: 1320, height: 2868), isPad: false))
        #expect(!WallpaperCanvas.isDeviceScreen(.zero, isPad: false))
    }

    // MARK: Formats

    @Test
    func artworkIsLaidOutAtAThirdOfItsPixelSize() {
        #expect(VerseImageFormat.square.layoutSize == CGSize(width: 360, height: 360))
        #expect(VerseImageFormat.story.layoutSize == CGSize(width: 360, height: 640))
        let wallpaper = VerseImageFormat.wallpaper
        #expect(wallpaper.layoutSize.width * VerseImageFormat.renderScale == wallpaper.pixelSize.width)
    }

    @Test
    func photosAreDecodedLargeEnoughForEveryFormat() {
        let largest = VerseImageFormat.largestPixelSide
        for format in VerseImageFormat.allCases {
            #expect(largest >= max(format.pixelSize.width, format.pixelSize.height), "\(format)")
        }
    }

    @Test
    func verseSitsBetweenTheClockAndNotifications() {
        let center = 0.5 + LockScreenLayout.verseCenterOffset
        #expect(center > LockScreenLayout.topZone)
        #expect(center < 1 - LockScreenLayout.bottomZone)
    }

    @Test
    func exportMatchesTheFormatsPixelSize() throws {
        try withComposerDefaultsSetAside {
            let model = makeModel()
            model.format = .square
            let image = try #require(model.render())
            #expect(image.size.width * image.scale == 1080)
            #expect(image.size.height * image.scale == 1080)
        }
    }

    // MARK: Composer

    @Test
    func openingTheComposerLeavesNothingToUndo() {
        withComposerDefaultsSetAside {
            let first = makeModel()
            first.format = .story
            first.textScale = 1.3
            first.savePreferences()

            // Remembered choices load on open without becoming undo steps.
            let reopened = makeModel()
            #expect(reopened.format == .story)
            #expect(abs(reopened.textScale - 1.3) < 0.0001)
            #expect(!reopened.canUndo)
        }
    }

    @Test
    func switchingToWallpaperPlacesACenteredVerseInTheOpenBand() {
        withComposerDefaultsSetAside {
            let model = makeModel()
            model.format = .portrait
            model.textOffset = .zero
            model.format = .wallpaper
            model.formatDidChange()

            if VerseImageFormat.wallpaper.contentFraction == 1 {
                #expect(abs(model.textOffset.height - LockScreenLayout.verseCenterOffset) < 0.0001)
            } else {
                // iPad keeps the verse centered in the square every orientation shows.
                #expect(model.textOffset == .zero)
            }
        }
    }

    @Test
    func textOffsetStaysOnTheCanvas() {
        withComposerDefaultsSetAside {
            let model = makeModel()
            model.format = .square
            let clamped = model.clampedTextOffset(CGSize(width: 5, height: -5))
            #expect(abs(clamped.width - 0.35) < 0.0001)
            #expect(abs(clamped.height + 0.35) < 0.0001)
        }
    }

    // MARK: Undo

    @Test
    func aBurstOfChangesIsOneUndoStep() {
        withComposerDefaultsSetAside {
            let (model, clock) = makeModelWithClock()
            // Like a slider drag: many changes a few milliseconds apart.
            for step in 1...20 {
                clock.advance(by: .milliseconds(16))
                model.photoDimming = Double(step) / 40
            }
            #expect(model.undoStepCount == 1)

            model.undo()
            #expect(abs(model.photoDimming - 0.28) < 0.0001)
        }
    }

    @Test
    func changesFarApartAreSeparateSteps() {
        withComposerDefaultsSetAside {
            let (model, clock) = makeModelWithClock()
            model.showsReference = false
            clock.advance(by: .seconds(1))
            model.textAlignment = .leading
            #expect(model.undoStepCount == 2)

            model.undo()
            #expect(model.textAlignment == .center)
            #expect(model.showsReference == false)
        }
    }

    @Test
    func stepsStartedOnPurposeAreNeverMerged() {
        withComposerDefaultsSetAside {
            let (model, clock) = makeModelWithClock()
            model.showsReference = false
            clock.advance(by: .milliseconds(10))
            model.beginEditingText()
            #expect(model.undoStepCount == 2)
        }
    }

    @Test
    func aChangeRightAfterUndoIsItsOwnStep() {
        withComposerDefaultsSetAside {
            let (model, clock) = makeModelWithClock()
            model.showsReference = false
            clock.advance(by: .seconds(1))
            model.showsBranding = false
            model.undo()

            clock.advance(by: .milliseconds(10))
            model.textAlignment = .trailing
            #expect(model.undoStepCount == 2)
        }
    }

    @Test
    func historyKeepsOnlyTheNewestSteps() {
        withComposerDefaultsSetAside {
            let (model, clock) = makeModelWithClock()
            for step in 0..<(VerseImageComposerModel.undoLimit + 10) {
                clock.advance(by: .seconds(1))
                model.textScale = 0.7 + CGFloat(step) * 0.01
            }
            #expect(model.undoStepCount == VerseImageComposerModel.undoLimit)

            // Undoing everything lands on the oldest step still kept, not the original size.
            while model.canUndo { model.undo() }
            #expect(abs(model.textScale - (0.7 + 9 * 0.01)) < 0.0001)
        }
    }

    // MARK: Helpers

    /// A hand-moved clock for undo timing.
    private final class ManualClock {
        var now = ContinuousClock.now
        func advance(by duration: Duration) { now += duration }
    }

    private func makeModel() -> VerseImageComposerModel {
        VerseImageComposerModel(verse: VerseActionReference(
            bookName: "John",
            chapterNumber: 3,
            verseNumber: 16,
            verseText: "For God so loved the world, that he gave his only begotten Son.",
            translation: .kjv
        ))
    }

    private func makeModelWithClock() -> (VerseImageComposerModel, ManualClock) {
        let model = makeModel()
        let clock = ManualClock()
        model.undoClock = { clock.now }
        model.clearUndoHistory()
        return (model, clock)
    }

    /// Runs `body` with no remembered composer choices, then puts the person's back.
    private func withComposerDefaultsSetAside<T>(_ body: () throws -> T) rethrows -> T {
        let key = "verseImageComposerPreferences"
        let defaults = UserDefaults.standard
        let saved = defaults.object(forKey: key)
        defaults.removeObject(forKey: key)
        defer {
            if let saved { defaults.set(saved, forKey: key) } else { defaults.removeObject(forKey: key) }
        }
        return try body()
    }
}
