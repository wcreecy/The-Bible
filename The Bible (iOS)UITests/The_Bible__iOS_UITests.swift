import UIKit
import XCTest

final class The_Bible__iOS_UITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("-UITesting")
    }

    @MainActor
    func testHomeAndBibleTabsLoad() throws {
        app.launch()

        XCTAssertTrue(app.otherElements["homeView"].waitForExistence(timeout: 8))

        tapFloatingTab(named: "Bible")
        XCTAssertTrue(app.staticTexts["Select a Book"].waitForExistence(timeout: 8))
    }

    @MainActor
    func testSettingsToggleIsReachable() throws {
        app.launch()

        tapFloatingTab(named: "More")
        let settings = app.buttons["Settings"].firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testIPadGamesHubAndBookOrderSetupAreFullyReachable() throws {
        try XCTSkipUnless(
            UIDevice.current.userInterfaceIdiom == .pad,
            "This regression test exercises the iPad-only layout."
        )
        app.launch()

        tapFloatingTab(named: "Games")
        XCTAssertTrue(app.navigationBars["Games"].waitForExistence(timeout: 8))

        let bookOrder = app.descendants(matching: .any)["gameRoute-bookOrder"]
        XCTAssertTrue(bookOrder.waitForExistence(timeout: 5))
        XCTAssertTrue(bookOrder.isHittable, "Book Order must be fully reachable from the Games hub.")
        bookOrder.tap()

        let setup = app.scrollViews["bookOrderSetupScrollView"]
        XCTAssertTrue(setup.waitForExistence(timeout: 8))
        assertFullyContained(setup)

        for title in ["Quick Rounds", "Full Bible Order", "Whole Bible", "Old Testament", "New Testament"] {
            let control = app.staticTexts[title].firstMatch
            XCTAssertTrue(control.waitForExistence(timeout: 5), "Expected \(title) to be visible.")
            XCTAssertTrue(control.isHittable, "\(title) is clipped or outside the iPad viewport.")
            assertFullyContained(control)
        }
    }

    @MainActor
    func testIPadHomeAndGamesRootsFitTheViewport() throws {
        try XCTSkipUnless(
            UIDevice.current.userInterfaceIdiom == .pad,
            "This regression test exercises the iPad-only layout."
        )
        app.launch()

        let home = app.otherElements["homeView"]
        XCTAssertTrue(home.waitForExistence(timeout: 8))
        assertFullyContained(home)

        tapFloatingTab(named: "Games")
        let gamesTitle = app.navigationBars["Games"]
        XCTAssertTrue(gamesTitle.waitForExistence(timeout: 8))
        assertFullyContained(gamesTitle)
    }

    @MainActor
    func testGamesNavigationRowsExposeHumanReadableAccessibleControls() throws {
        app.launch()

        tapFloatingTab(named: "Games")
        let bookOrder = app.descendants(matching: .any)["gameRoute-bookOrder"]
        XCTAssertTrue(bookOrder.waitForExistence(timeout: 8))
        XCTAssertTrue(bookOrder.isHittable)
        XCTAssertTrue(
            bookOrder.label.localizedCaseInsensitiveContains("book order"),
            "The custom game row needs a human-readable VoiceOver label."
        )
    }

    @MainActor
    func testAccessibilityTextSizeKeepsBookOrderSetupReachable() throws {
        app.launchArguments.append(contentsOf: [
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL"
        ])
        app.launch()

        tapFloatingTab(named: "Games")
        let bookOrder = app.descendants(matching: .any)["gameRoute-bookOrder"]
        XCTAssertTrue(bookOrder.waitForExistence(timeout: 8))
        XCTAssertTrue(bookOrder.isHittable)
        bookOrder.tap()

        let setup = app.scrollViews["bookOrderSetupScrollView"]
        XCTAssertTrue(setup.waitForExistence(timeout: 8))
        XCTAssertTrue(setup.isHittable)
        assertFullyContained(setup)
    }

    @MainActor
    private func tapFloatingTab(named name: String) {
        let tab = app.buttons[name].firstMatch
        XCTAssertTrue(tab.waitForExistence(timeout: 5), "Expected the \(name) tab to exist")
        tab.tap()
    }

    private func assertFullyContained(
        _ element: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let frame = element.frame
        let appFrame = app.frame
        XCTAssertGreaterThanOrEqual(frame.minX, appFrame.minX, "\(element) begins outside the viewport.", file: file, line: line)
        XCTAssertLessThanOrEqual(frame.maxX, appFrame.maxX, "\(element) extends outside the viewport.", file: file, line: line)
    }
}
