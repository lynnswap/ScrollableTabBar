import XCTest

// XCUITest uses XCTestCase to own app launch and the automation session;
// the package and external product-contract suites use Swift Testing.
final class ScrollableTabBarDemoUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSelectsTabsThroughVisibleAndContinuousInteractions() {
        let app = XCUIApplication()
        app.launch()

        let selectionLabel = app.staticTexts[
            "ScrollableTabBarDemo.SelectionLabel"
        ]
        XCTAssertTrue(selectionLabel.waitForExistence(timeout: 5))
        assertSelection("Overview", in: selectionLabel)
        XCTAssertTrue(
            app.buttons["ScrollableTabBarDemo.Done"]
                .waitForExistence(timeout: 5)
        )

        let headersTab = app.buttons[
            "ScrollableTabBarDemo.Tab.headers"
        ].firstMatch
        XCTAssertTrue(headersTab.waitForExistence(timeout: 5))
        XCTAssertTrue(headersTab.isHittable)
        headersTab.tap()

        assertSelection("Headers", in: selectionLabel)

        let previewTab = app.buttons[
            "ScrollableTabBarDemo.Tab.preview"
        ].firstMatch
        XCTAssertTrue(previewTab.waitForExistence(timeout: 5))

        let floatingControl = app.descendants(matching: .any)[
            "ScrollableTabBarDemo.Control"
        ].firstMatch
        XCTAssertTrue(floatingControl.waitForExistence(timeout: 5))

        let previewFrameBeforeDrag = previewTab.frame
        let startPoint = app.coordinate(
            withNormalizedOffset: .zero
        ).withOffset(
            CGVector(
                dx: previewFrameBeforeDrag.midX,
                dy: previewFrameBeforeDrag.midY
            )
        )
        let endPoint = startPoint.withOffset(
            CGVector(dx: -60, dy: 0)
        )
        startPoint.press(
            forDuration: 0.1,
            thenDragTo: endPoint,
            withVelocity: 100,
            thenHoldForDuration: 0.5
        )

        let previewFrameAfterDrag = previewTab.frame
        XCTAssertLessThan(
            previewFrameAfterDrag.minX,
            previewFrameBeforeDrag.minX
        )

        let cookiesTab = app.buttons[
            "ScrollableTabBarDemo.Tab.cookies"
        ].firstMatch
        XCTAssertTrue(cookiesTab.waitForExistence(timeout: 5))

        let cookiesFrame = cookiesTab.frame
        let visibleCookiesFrame = cookiesFrame.intersection(
            floatingControl.frame
        )
        XCTAssertFalse(visibleCookiesFrame.isNull)
        XCTAssertGreaterThan(visibleCookiesFrame.width, 0)
        XCTAssertLessThan(visibleCookiesFrame.width, cookiesFrame.width)

        let visibleCookiesPoint = app.coordinate(
            withNormalizedOffset: .zero
        ).withOffset(
            CGVector(
                dx: visibleCookiesFrame.midX,
                dy: visibleCookiesFrame.midY
            )
        )
        visibleCookiesPoint.tap()

        assertSelection("Cookies", in: selectionLabel)
    }

    @MainActor
    func testUpdatesTabsAndSelectsAfterRefillingAnEmptyBar() throws {
        let app = XCUIApplication()
        app.launch()
        let label = app.staticTexts["ScrollableTabBarDemo.SelectionLabel"]
        XCTAssertTrue(label.waitForExistence(timeout: 5))
        app.buttons["ScrollableTabBarDemo.RemoveTab"].tap()
        assertSelection("Headers", in: label)
        app.buttons["ScrollableTabBarDemo.AddTab"].tap()
        assertSelection("Overview", in: label)
        app.buttons["ScrollableTabBarDemo.ReverseTabs"].tap()
        assertSelection("Overview", in: label)
        app.buttons["ScrollableTabBarDemo.ClearSelection"].tap()
        assertSelection("None", in: label)
        let control = app.descendants(matching: .any)["ScrollableTabBarDemo.Control"].firstMatch
        let visibleTab = try XCTUnwrap(
            app.buttons.matching(
                NSPredicate(format: "identifier BEGINSWITH %@", "ScrollableTabBarDemo.Tab.")
            )
            .allElementsBoundByIndex.first { $0.isHittable && control.frame.contains($0.frame) }
        )
        let selectedTitle = visibleTab.label
        visibleTab.tap()
        assertSelection(selectedTitle, in: label)

        app.buttons["ScrollableTabBarDemo.ClearTabs"].tap()
        assertSelection("None", in: label)
        app.buttons["ScrollableTabBarDemo.AddTab"].tap()
        assertSelection("Overview", in: label)
        app.buttons["ScrollableTabBarDemo.AddTab"].tap()
        assertSelection("Headers", in: label)
        let refilledOverview = app.buttons["ScrollableTabBarDemo.Tab.overview"].firstMatch
        XCTAssertTrue(refilledOverview.waitForExistence(timeout: 5))
        refilledOverview.tap()
        assertSelection("Overview", in: label)
    }

    @MainActor
    private func assertSelection(
        _ title: String,
        in selectionLabel: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            selectionLabel.wait(
                for: \.label,
                toEqual: "Selected: \(title)",
                timeout: 5
            ),
            file: file,
            line: line
        )
    }
}
