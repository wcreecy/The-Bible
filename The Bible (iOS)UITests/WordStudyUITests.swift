import UIKit
import XCTest

/// Word study at accessibility text sizes, through its nested sheets, and as VoiceOver sees it.
/// Every test searches "h1834" (Damascus, 40 verses starting at Genesis 14:15).
final class WordStudyUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("-UITesting")
    }

    // MARK: Search card and its study sheet

    @MainActor
    func testHomeSearchCardOpensTheStudySheet() throws {
        app.launch()
        searchHome(for: "h1834")
        try assertStudySheetOpensAndCloses()
    }

    @MainActor
    func testStudySheetOpensFromHomeSearchAtAccessibilityTextSize() throws {
        launchAtAccessibilityTextSize()
        searchHome(for: "h1834")
        try assertStudySheetOpensAndCloses()
    }

    @MainActor
    func testSearchPageCardOpensTheStudySheet() throws {
        app.launch()
        openSearchPage(searching: "h1834")
        try assertStudySheetOpensAndCloses()
    }

    @MainActor
    func testSearchCardIsOneVoiceOverElementThatNamesTheWord() throws {
        app.launch()
        searchHome(for: "h1834")

        let card = strongsCard()
        XCTAssertTrue(card.waitForExistence(timeout: 8))
        // Combined into one element with the number, the word, and the verse count in its label.
        for part in ["H1834", "Damascus", "40 verses"] {
            XCTAssertTrue(card.label.contains(part), "The card's label is missing \(part): \(card.label)")
        }
        XCTAssertFalse(card.label.isEmpty)
    }

    // MARK: Interlinear sheet, from a verse's menu

    @MainActor
    func testInterlinearTilesAreLabeledForVoiceOver() throws {
        app.launch()
        try openInterlinearFromSearch()

        let tile = damascusTile()
        XCTAssertTrue(tile.waitForExistence(timeout: 8))
        for part in ["Damascus", "Strong’s H1834"] {
            XCTAssertTrue(tile.label.contains(part), "The tile's label is missing \(part): \(tile.label)")
        }
        XCTAssertFalse(tile.isSelected)
        tile.tap()
        XCTAssertTrue(tile.isSelected, "A chosen word must be announced as selected.")
    }

    @MainActor
    func testWordEntryDocksAndOpensItsVerseListInANestedSheet() throws {
        app.launch()
        try openInterlinearFromSearch()

        damascusTile().tap()
        // Docked beside the tiles, not a sheet of its own.
        XCTAssertTrue(app.buttons["Close Entry"].waitForExistence(timeout: 5))

        let usageRow = app.buttons["wordUsageRow"]
        XCTAssertTrue(usageRow.waitForExistence(timeout: 5))
        usageRow.tap()

        // The verse list opens over the interlinear sheet, which stays underneath.
        let verseList = app.navigationBars["H1834 · Damascus"]
        XCTAssertTrue(verseList.waitForExistence(timeout: 5))
        verseList.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["Close Entry"].waitForExistence(timeout: 5), "Closing the list must return to the entry.")

        app.buttons["Close Entry"].tap()
        XCTAssertFalse(app.buttons["Close Entry"].waitForExistence(timeout: 1))
    }

    @MainActor
    func testWordEntryOpensAsASheetAtAccessibilityTextSize() throws {
        launchAtAccessibilityTextSize()
        try openInterlinearFromSearch()

        let tile = damascusTile()
        scrollUntilHittable(tile)
        tile.tap()

        // Too big to dock, so the entry is its own sheet with its own Done button.
        XCTAssertFalse(app.buttons["Close Entry"].exists, "The docked panel must not appear at accessibility sizes.")
        let usageRow = app.buttons["wordUsageRow"]
        XCTAssertTrue(usageRow.waitForExistence(timeout: 8))
        scrollUntilHittable(usageRow)
        usageRow.tap()

        // A third level: verse list over the entry sheet over the interlinear sheet.
        let verseList = app.navigationBars["H1834 · Damascus"]
        XCTAssertTrue(verseList.waitForExistence(timeout: 5))
        verseList.buttons["Done"].tap()
        XCTAssertTrue(usageRow.waitForExistence(timeout: 5), "Closing the list must return to the entry sheet.")
    }

    @MainActor
    func testOpeningAVerseFromTheVerseListClosesEverySheet() throws {
        app.launch()
        try openInterlinearFromSearch()

        damascusTile().tap()
        let usageRow = app.buttons["wordUsageRow"]
        XCTAssertTrue(usageRow.waitForExistence(timeout: 5))
        usageRow.tap()

        let verseList = app.navigationBars["H1834 · Damascus"]
        XCTAssertTrue(verseList.waitForExistence(timeout: 5))
        // Genesis 15:2 is the second verse using the word.
        let verse = app.buttons.containing(NSPredicate(format: "label BEGINSWITH '15:2'")).firstMatch
        XCTAssertTrue(verse.waitForExistence(timeout: 5))
        verse.tap()

        XCTAssertTrue(verseList.waitForNonExistence(timeout: 8), "The verse list must close.")
        XCTAssertFalse(app.buttons["Done"].firstMatch.waitForExistence(timeout: 2), "No sheet should remain over the reader.")
    }

    // MARK: Steps

    @MainActor
    private func assertStudySheetOpensAndCloses() throws {
        let card = strongsCard()
        XCTAssertTrue(card.waitForExistence(timeout: 8), "Expected the Strong's card for h1834.")
        scrollUntilHittable(card)
        card.tap()

        let sheet = app.navigationBars["H1834 · Damascus"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 5), "Tapping the card must open the study sheet.")
        // The entry's definition and the verses that use the word, grouped by book.
        // At accessibility sizes the entry fills the first screens, so the verses are scrolled to.
        let genesis = app.staticTexts["Genesis · 2"]
        for _ in 0..<12 where !genesis.exists {
            app.swipeUp()
        }
        XCTAssertTrue(genesis.exists, "Expected the verses grouped by book.")
        for _ in 0..<12 where !sheet.buttons["Done"].isHittable {
            app.swipeDown()
        }

        let done = sheet.buttons["Done"]
        XCTAssertTrue(done.isHittable, "Done must stay reachable.")
        XCTAssertLessThanOrEqual(sheet.frame.maxX, app.frame.maxX)
        done.tap()
        XCTAssertTrue(sheet.waitForNonExistence(timeout: 5))
    }

    /// Search and verse-menu route to the interlinear sheet for Genesis 14:15.
    @MainActor
    private func openInterlinearFromSearch() throws {
        openSearchPage(searching: "h1834")

        // Under the Strong's card; at accessibility sizes, below the first screen.
        let menu = app.buttons["Verse actions"].firstMatch
        _ = menu.waitForExistence(timeout: 8)
        scrollUntilHittable(menu)
        XCTAssertTrue(menu.isHittable, "Expected a verse's action menu in the results.")
        menu.tap()

        let words = app.buttons["Hebrew Words"].firstMatch
        XCTAssertTrue(words.waitForExistence(timeout: 5), "Expected Hebrew Words in the verse menu.")
        words.tap()

        // Whichever verse's menu was used, it uses the word.
        XCTAssertTrue(damascusTile().waitForExistence(timeout: 8), "Expected the interlinear sheet with the word's tile.")
    }

    /// The card, found by what it says. On Home the container's identifier replaces the card's own.
    private func strongsCard() -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'Used in 40 verses'")).firstMatch
    }

    private func damascusTile() -> XCUIElement {
        app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'interlinearTile-' AND label CONTAINS 'H1834'")
        ).firstMatch
    }

    @MainActor
    private func searchHome(for text: String) {
        let field = app.textFields["Search words or a reference"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 8))
        for _ in 0..<10 where !field.isHittable {
            app.swipeUp()
        }
        field.tap()
        field.typeText(text)
    }

    @MainActor
    private func openSearchPage(searching text: String) {
        let open = app.buttons["Open Search"].firstMatch
        XCTAssertTrue(open.waitForExistence(timeout: 8))
        for _ in 0..<10 where !open.isHittable {
            app.swipeUp()
        }
        open.tap()

        let field = app.textFields["Search words or a reference"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 8))
        field.tap()
        field.typeText(text)
    }

    @MainActor
    private func scrollUntilHittable(_ element: XCUIElement) {
        for _ in 0..<12 where !(element.exists && element.isHittable) {
            app.swipeUp()
        }
    }

    @MainActor
    private func launchAtAccessibilityTextSize() {
        app.launchArguments.append(contentsOf: [
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL"
        ])
        app.launch()
    }
}
