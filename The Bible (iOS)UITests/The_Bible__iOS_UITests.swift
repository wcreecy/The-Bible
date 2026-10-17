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
    func testWidgetBackgroundsCanBeSelectedForEachWidget() throws {
        app.launch()

        tapFloatingTab(named: "More")
        let settings = app.buttons["Settings"].firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.tap()

        let widgetsSettings = app.descendants(matching: .any)["widgetsSettingsLink"].firstMatch
        XCTAssertTrue(widgetsSettings.waitForExistence(timeout: 5))
        widgetsSettings.tap()

        let widgets = [
            (pickerIdentifier: "verseWidgetBackgroundPicker", name: "Verse of the Day"),
            (pickerIdentifier: "lastReadWidgetBackgroundPicker", name: "Bookmark"),
            (pickerIdentifier: "pinnedVerseWidgetBackgroundPicker", name: "Pinned Verse")
        ]

        for background in ["Parchment", "Riverstone", "Olive & Gold", "Amethyst"] {
            for widget in widgets {
                selectBackground(
                    named: background,
                    pickerIdentifier: widget.pickerIdentifier,
                    widgetName: widget.name
                )
            }
        }
    }

    @MainActor
    private func selectBackground(named name: String, pickerIdentifier: String, widgetName: String) {
        let picker = app.buttons[pickerIdentifier].firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 5), "Expected the \(widgetName) background picker to exist")
        picker.tap()

        let option = app.descendants(matching: .any)[name].firstMatch
        XCTAssertTrue(option.waitForExistence(timeout: 5), "Expected \(name) to be available for \(widgetName)")
        option.tap()

        XCTAssertEqual(picker.value as? String, name, "Expected \(widgetName) to retain the selected background")
    }

    @MainActor
    private func tapFloatingTab(named name: String) {
        let tab = app.buttons[name].firstMatch
        XCTAssertTrue(tab.waitForExistence(timeout: 5), "Expected the \(name) tab to exist")
        tab.tap()
    }
}
