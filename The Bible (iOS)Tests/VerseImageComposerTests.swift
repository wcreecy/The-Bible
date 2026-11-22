import Foundation
import Testing
import UIKit
@testable import Bible

/// Verse image formats, export, and the composer's undo history.
///
/// Composer tests set the remembered composer choices aside and put them back afterward,
/// and undo timing runs on a clock the test moves by hand, so nothing waits on real time.
@MainActor
struct VerseImageComposerTests {
    // MARK: Formats

    @Test
    func artworkIsLaidOutAtAThirdOfItsPixelSize() {
        #expect(VerseImageFormat.square.layoutSize == CGSize(width: 360, height: 360))
        #expect(VerseImageFormat.story.layoutSize == CGSize(width: 360, height: 640))
    }

    @Test
    func photosAreDecodedLargeEnoughForEveryFormat() {
        let largest = VerseImageFormat.largestPixelSide
        for format in VerseImageFormat.allCases {
            #expect(largest >= max(format.pixelSize.width, format.pixelSize.height), "\(format)")
        }
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
