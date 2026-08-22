import XCTest

// XCUITest uses XCTestCase to own app launch and the automation session;
// the package and external product-contract suites use Swift Testing.
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

        let headersTab = app.buttons[
            "ScrollableTabBarDemo.Tab.headers"
        ].firstMatch
        XCTAssertTrue(headersTab.waitForExistence(timeout: 5))
        XCTAssertTrue(headersTab.isHittable)
        headersTab.tap()

        XCTAssertEqual(selectionLabel.label, "Selected: Headers")
    }

    @MainActor
    func testPagesToAnOverflowTab() {
        let app = XCUIApplication()
        app.launch()

        let responseTab = app.buttons[
            "ScrollableTabBarDemo.Tab.response"
        ].firstMatch
        let nextPageButton = app.buttons["Next Page"].firstMatch

        for _ in 0..<6 {
            guard nextPageButton.exists, nextPageButton.isHittable else {
                break
            }
            nextPageButton.tap()
        }

        XCTAssertFalse(nextPageButton.exists && nextPageButton.isHittable)
        XCTAssertTrue(responseTab.waitForExistence(timeout: 2))
        XCTAssertTrue(responseTab.isHittable)
        responseTab.tap()

        let selectionLabel = app.staticTexts[
            "ScrollableTabBarDemo.SelectionLabel"
        ]
        XCTAssertEqual(selectionLabel.label, "Selected: Response")
    }
}
