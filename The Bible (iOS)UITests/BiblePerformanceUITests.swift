import XCTest

final class BiblePerformanceUITests: XCTestCase {
    func testColdLaunchPerformance() {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let app = XCUIApplication()
            app.launchArguments = ["-UITesting"]
            app.launch()
            app.terminate()
        }
    }
}
