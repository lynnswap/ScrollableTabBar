import Testing
import UIKit
@testable import ScrollableTabBar

private enum TabID: Hashable {
    case headers
    case preview
    case cookies
    case security
}

@MainActor
private final class SelectionRecorder<ID: Hashable>: ScrollableTabBarDelegate {
    private(set) var selections: [ID] = []
    private(set) var controlSelections: [ID] = []

    func scrollableTabBar(
        _ tabBar: ScrollableTabBar<ID>,
        didSelect selectedID: ID
    ) {
        selections.append(selectedID)
        controlSelections.append(tabBar.selectedID)
    }
}

@MainActor
@Suite(.serialized)
struct ScrollableTabBarTests {
    @Test
    func preservesMembershipAndProgrammaticSelectionWithoutADelegateCallback() {
        let control = makeControl(selectedID: .headers)
        let recorder = SelectionRecorder<TabID>()
        control.delegate = recorder

        #expect(control.items.map(\.id) == [.headers, .preview, .cookies, .security])
        #expect(control.items.map(\.title) == ["Headers", "Preview", "Cookies", "Security"])
        #expect(control.items[0].accessibilityIdentifier == "ScrollableTabBar.Test.0")
        #expect(control.selectedID == .headers)

        control.selectedID = .cookies

        #expect(control.selectedID == .cookies)
        #expect(recorder.selections.isEmpty)
    }

    @Test
    func userSelectionUpdatesBeforeOneDelegateCallback() {
        let control = makeControl(selectedID: .headers)
        let recorder = SelectionRecorder<TabID>()
        control.delegate = recorder

        control.didSelectItem(at: 3)

        #expect(control.selectedID == .security)
        #expect(recorder.selections == [.security])
        #expect(recorder.controlSelections == [.security])

        control.didSelectItem(at: 3)

        #expect(recorder.selections == [.security])
    }

    @Test
    func disabledControlRejectsUserSelection() {
        let control = makeControl(selectedID: .preview)
        let recorder = SelectionRecorder<TabID>()
        control.delegate = recorder
        control.isEnabled = false

        control.didSelectItem(at: 2)

        #expect(control.selectedID == .preview)
        #expect(recorder.selections.isEmpty)
    }

    @Test
    func invalidContentSelectionRestoresTheCurrentProjection() {
        let control = makeControl(selectedID: .preview)
        let recorder = SelectionRecorder<TabID>()
        control.delegate = recorder

        control.didSelectItem(at: 99)

        #expect(control.selectedID == .preview)
        #expect(recorder.selections.isEmpty)
    }

    @Test
    func doesNotRetainItsDelegate() {
        let control = makeControl(selectedID: .headers)
        weak var releasedDelegate: SelectionRecorder<TabID>?

        do {
            let recorder = SelectionRecorder<TabID>()
            releasedDelegate = recorder
            control.delegate = recorder
            #expect(control.delegate != nil)
        }

        #expect(releasedDelegate == nil)
        #expect(control.delegate == nil)
    }

    @Test
    func propagatesTheControlAccessibilityIdentifier() {
        let control = makeControl(selectedID: .headers)

        control.accessibilityIdentifier = "ScrollableTabBar.Control"

        if let systemContent = control.content as? SystemFloatingTabContent {
            #expect(
                systemContent.floatingView.accessibilityIdentifier
                    == "ScrollableTabBar.Control"
            )
        } else if let adaptiveContent = control.content as? AdaptiveTabContent {
            #expect(
                adaptiveContent.segmentedControl.accessibilityIdentifier
                    == "ScrollableTabBar.Control"
            )
            #expect(
                adaptiveContent.menuButton.accessibilityIdentifier
                    == "ScrollableTabBar.Control"
            )
        } else {
            Issue.record("ScrollableTabBar selected an unknown content implementation.")
        }
    }

    @Test
    func capsWideSizingAndHonorsNarrowContainerProposals() {
        let control = makeControl(selectedID: .headers)
        let preferredSize = CGSize(width: 640, height: 49)

        #expect(control.intrinsicContentSize == preferredSize)
        #expect(
            control.sizeThatFits(CGSize(width: 314, height: 1))
                == CGSize(width: 314, height: 49)
        )
        #expect(
            control.sizeThatFits(CGSize(width: 1_024, height: 1))
                == preferredSize
        )
        #expect(control.sizeThatFits(.zero) == preferredSize)
    }

    private func makeControl(selectedID: TabID) -> ScrollableTabBar<TabID> {
        ScrollableTabBar(
            items: [
                .init(
                    id: .headers,
                    title: "Headers",
                    accessibilityIdentifier: "ScrollableTabBar.Test.0"
                ),
                .init(
                    id: .preview,
                    title: "Preview",
                    accessibilityIdentifier: "ScrollableTabBar.Test.1"
                ),
                .init(
                    id: .cookies,
                    title: "Cookies",
                    accessibilityIdentifier: "ScrollableTabBar.Test.2"
                ),
                .init(
                    id: .security,
                    title: "Security",
                    accessibilityIdentifier: "ScrollableTabBar.Test.3"
                ),
            ],
            selectedID: selectedID
        )
    }
}
