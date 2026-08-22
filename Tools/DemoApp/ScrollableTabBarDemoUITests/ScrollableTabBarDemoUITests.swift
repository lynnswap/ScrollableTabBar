import XCTest

final class ScrollableTabBarDemoUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSelectsAVisibleTab() {
        let app = XCUIApplication()
        app.launch()

        let selectionLabel = app.staticTexts[
            "ScrollableTabBarDemo.SelectionLabel"
        ]
        XCTAssertTrue(selectionLabel.waitForExistence(timeout: 5))
        XCTAssertEqual(selectionLabel.label, "Selected: Overview")
        XCTAssertTrue(app.navigationBars.buttons["Demo"].exists)

        let previewTab = app.descendants(matching: .any)[
            "ScrollableTabBarDemo.Tab.preview"
        ]
        XCTAssertTrue(previewTab.waitForExistence(timeout: 5))
        XCTAssertTrue(previewTab.isHittable)
        previewTab.tap()

        XCTAssertEqual(selectionLabel.label, "Selected: Preview")
    }

    @MainActor
    func testPagesToAnOverflowTab() {
        let app = XCUIApplication()
        app.launch()

        let responseTab = app.descendants(matching: .any)[
            "ScrollableTabBarDemo.Tab.response"
        ]
        XCTAssertTrue(responseTab.waitForExistence(timeout: 5))

        let navigationBar = app.navigationBars["ScrollableTabBar"]
        XCTAssertTrue(navigationBar.waitForExistence(timeout: 5))

        for _ in 0..<3 where responseTab.isHittable == false {
            navigationBar.swipeLeft()
        }

        XCTAssertTrue(responseTab.isHittable)
        responseTab.tap()

        let selectionLabel = app.staticTexts[
            "ScrollableTabBarDemo.SelectionLabel"
        ]
        XCTAssertEqual(selectionLabel.label, "Selected: Response")
    }
}
