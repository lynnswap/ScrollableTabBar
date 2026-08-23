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
    func testSelectsOverflowItemAcrossAvailablePresentation() throws {
        let app = XCUIApplication()
        app.launch()

        let responseIdentifier = "ScrollableTabBarDemo.Tab.response"
        let responseQuery = app.buttons.matching(identifier: responseIdentifier)
        let nextPageButton = app.buttons["Next Page"].firstMatch

        if nextPageButton.waitForExistence(timeout: 2) {
            // Seven demo items can require at most six forward page transitions.
            for _ in 0..<6 {
                guard nextPageButton.exists, nextPageButton.isHittable else {
                    break
                }
                nextPageButton.tap()
            }
            XCTAssertFalse(nextPageButton.exists && nextPageButton.isHittable)
        } else if responseQuery.firstMatch.exists == false {
            let menuButton = try XCTUnwrap(
                hittableButton(
                    in: app,
                    identifier: "ScrollableTabBarDemo.Control"
                )
            )
            menuButton.tap()
        }

        XCTAssertTrue(responseQuery.firstMatch.waitForExistence(timeout: 5))
        let responseButton = try XCTUnwrap(
            responseQuery.allElementsBoundByIndex.last { $0.isHittable }
        )
        responseButton.tap()

        let selectionLabel = app.staticTexts[
            "ScrollableTabBarDemo.SelectionLabel"
        ]
        let selectedResponse = XCTNSPredicateExpectation(
            predicate: NSPredicate(
                format: "label == %@",
                "Selected: Response"
            ),
            object: selectionLabel
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [selectedResponse], timeout: 5),
            .completed
        )
    }

    @MainActor
    private func hittableButton(
        in app: XCUIApplication,
        identifier: String
    ) -> XCUIElement? {
        app.buttons.matching(identifier: identifier)
            .allElementsBoundByIndex
            .last { $0.isHittable }
    }
}
