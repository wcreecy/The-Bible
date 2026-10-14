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
    private func tapFloatingTab(named name: String) {
        let tab = app.buttons[name].firstMatch
        XCTAssertTrue(tab.waitForExistence(timeout: 5), "Expected the \(name) tab to exist")
        tab.tap()
    }
}
