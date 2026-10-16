import CoreGraphics
import SwiftUI
import Testing
@testable import Bible

@MainActor
struct NoteEditorSupportTests {
    @Test
    func defaultTextSizeFollowsTheSystemSize() {
        for size in DynamicTypeSize.allCases {
            #expect(NoteEditorTextSize.dynamicTypeSize(for: NoteEditorTextSize.defaultStep, relativeTo: size) == size)
        }
    }

    @Test
    func eachTextSizeStepMovesOneSize() {
        let base = DynamicTypeSize.large
        #expect(NoteEditorTextSize.dynamicTypeSize(for: NoteEditorTextSize.defaultStep + 1, relativeTo: base) == .xLarge)
        #expect(NoteEditorTextSize.dynamicTypeSize(for: NoteEditorTextSize.defaultStep - 1, relativeTo: base) == .medium)
        #expect(NoteEditorTextSize.dynamicTypeSize(for: NoteEditorTextSize.maximumStep, relativeTo: base) == .xxxLarge)
        #expect(NoteEditorTextSize.dynamicTypeSize(for: NoteEditorTextSize.minimumStep, relativeTo: base) == .xSmall)

        // Accessibility sizes can be reached from a large system size.
        #expect(NoteEditorTextSize.dynamicTypeSize(for: NoteEditorTextSize.defaultStep + 1, relativeTo: .xxxLarge) == .accessibility1)
    }

    @Test
    func textSizeStopsAtTheSmallestAndLargestSizes() {
        #expect(NoteEditorTextSize.dynamicTypeSize(for: NoteEditorTextSize.minimumStep, relativeTo: .xSmall) == .xSmall)
        #expect(NoteEditorTextSize.dynamicTypeSize(for: NoteEditorTextSize.maximumStep, relativeTo: .accessibility5) == .accessibility5)

        // Out-of-range stored steps are treated as the nearest valid step.
        #expect(NoteEditorTextSize.dynamicTypeSize(for: 99, relativeTo: .large) == .xxxLarge)
        #expect(NoteEditorTextSize.dynamicTypeSize(for: -99, relativeTo: .large) == .xSmall)
    }

    @Test
    func onlyAFullOnScreenKeyboardCounts() {
        let screenHeight: CGFloat = 1180

        // An on-screen keyboard rising from the bottom.
        #expect(OnScreenKeyboard.isShown(endFrame: CGRect(x: 0, y: 780, width: 820, height: 400), screenHeight: screenHeight))

        // A hardware keyboard's shortcut bar.
        #expect(!OnScreenKeyboard.isShown(endFrame: CGRect(x: 0, y: 1125, width: 820, height: 55), screenHeight: screenHeight))

        // A keyboard going away ends below the screen.
        #expect(!OnScreenKeyboard.isShown(endFrame: CGRect(x: 0, y: 1180, width: 820, height: 400), screenHeight: screenHeight))

        // A floating keyboard reports no frame.
        #expect(!OnScreenKeyboard.isShown(endFrame: .zero, screenHeight: screenHeight))
        #expect(!OnScreenKeyboard.isShown(endFrame: nil, screenHeight: screenHeight))
    }
}
