import Testing
import UIKit
@testable import ScrollableTabBar

@MainActor
@Suite(.serialized)
struct ScrollableTabBarTests {
    private enum TabID: Hashable {
        case headers
        case preview
        case cookies
        case security
    }

    @Test
    func preservesMembershipAndProgrammaticSelectionWithoutAnEvent() {
        let control = makeControl(selectedID: .headers)
        var observedSelections: [TabID] = []
        control.addAction(
            UIAction { [weak control] _ in
                if let selectedID = control?.selectedID {
                    observedSelections.append(selectedID)
                }
            },
            for: .valueChanged
        )

        #expect(control.items.map(\.id) == [.headers, .preview, .cookies, .security])
        #expect(control.items.map(\.title) == ["Headers", "Preview", "Cookies", "Security"])
        #expect(control.items[0].accessibilityIdentifier == "ScrollableTabBar.Test.0")
        #expect(control.selectedID == .headers)

        control.selectedID = .cookies

        #expect(control.selectedID == .cookies)
        #expect(observedSelections.isEmpty)
    }

    @Test
    func userSelectionUpdatesBeforeOneValueChangedEvent() {
        let control = makeControl(selectedID: .headers)
        var observedSelections: [TabID] = []
        control.addAction(
            UIAction { [weak control] _ in
                if let selectedID = control?.selectedID {
                    observedSelections.append(selectedID)
                }
            },
            for: .valueChanged
        )

        control.didSelectItem(at: 3)

        #expect(control.selectedID == .security)
        #expect(observedSelections == [.security])

        control.didSelectItem(at: 3)

        #expect(observedSelections == [.security])
    }

    @Test
    func disabledControlRejectsUserSelection() {
        let control = makeControl(selectedID: .preview)
        var eventCount = 0
        control.addAction(
            UIAction { _ in
                eventCount += 1
            },
            for: .valueChanged
        )
        control.isEnabled = false

        control.didSelectItem(at: 2)

        #expect(control.selectedID == .preview)
        #expect(eventCount == 0)
    }

    @Test
    func invalidContentSelectionRestoresTheCurrentProjection() {
        let control = makeControl(selectedID: .preview)
        var eventCount = 0
        control.addAction(
            UIAction { _ in
                eventCount += 1
            },
            for: .valueChanged
        )

        control.didSelectItem(at: 99)

        #expect(control.selectedID == .preview)
        #expect(eventCount == 0)
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
