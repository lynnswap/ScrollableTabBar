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
    private(set) var controlSelections: [ID?] = []

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

        control.didSelectItem(id: .security)

        #expect(control.selectedID == .security)
        #expect(recorder.selections == [.security])
        #expect(recorder.controlSelections == [.security])

        control.didSelectItem(id: .security)

        #expect(recorder.selections == [.security])
    }

    @Test
    func disabledControlRejectsUserSelection() {
        let control = makeControl(selectedID: .preview)
        let recorder = SelectionRecorder<TabID>()
        control.delegate = recorder
        control.isEnabled = false

        control.didSelectItem(id: .cookies)

        #expect(control.selectedID == .preview)
        #expect(recorder.selections.isEmpty)
    }

    @Test
    func ignoresSelectionFromARemovedItem() {
        let control = makeControl(selectedID: .preview)
        let recorder = SelectionRecorder<TabID>()
        control.delegate = recorder

        control.setItems(control.items.filter { $0.id != .security }, selectedID: .preview)
        control.didSelectItem(id: .security)

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
    func fitsItemsAndHonorsNarrowContainerProposals() {
        let control = makeControl(selectedID: .headers)
        let preferredSize = control.intrinsicContentSize
        #expect(preferredSize.width > 0)
        #expect(preferredSize.width < 640)
        #expect(preferredSize.height == 49)
        let narrowWidth = preferredSize.width / 2
        #expect(control.sizeThatFits(CGSize(width: narrowWidth, height: 1)).width == narrowWidth)
        #expect(control.sizeThatFits(CGSize(width: 1_024, height: 1)) == preferredSize)
        #expect(control.sizeThatFits(.zero) == preferredSize)

        control.setItems([.init(id: .headers, title: "A")], selectedID: .headers)
        #expect(control.intrinsicContentSize.width < preferredSize.width)
    }

    @Test
    func navigationTitleViewFitsTabsAddedAfterInstallation() {
        let control = ScrollableTabBar<TabID>()
        control.sizeToFit()
        let detail = UIViewController()
        detail.navigationItem.titleView = control
        let navigation = UINavigationController(rootViewController: detail)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        window.layoutIfNeeded()

        control.setItems([.init(id: .headers, title: "A")], selectedID: .headers)
        window.layoutIfNeeded()
        let initialWidth = control.bounds.width
        control.setItems([
            .init(id: .headers, title: "A"),
            .init(id: .preview, title: "Preview"),
        ], selectedID: .preview)
        window.layoutIfNeeded()
        #expect(control.window === window)
        #expect(control.bounds.width > initialWidth)
        #expect(abs(control.bounds.width - control.intrinsicContentSize.width) <= 1)
    }

    @Test
    func updatesItemsAndSelectionTogetherWithoutNotifyingTheDelegate() {
        let control = makeControl(selectedID: .preview)
        let recorder = SelectionRecorder<TabID>()
        control.delegate = recorder
        var updated = control.items.filter { $0.id != .preview }
        updated.reverse()
        updated[0].title = "Permissions"
        updated[0].image = UIImage(systemName: "lock")
        control.setItems(updated, selectedID: .security)

        #expect(control.items.map(\.id) == [.security, .cookies, .headers])
        #expect(control.items.first?.title == "Permissions")
        #expect(control.items.first?.image != nil)
        #expect(control.selectedID == .security)
        #expect(recorder.selections.isEmpty)
        control.selectedID = nil
        #expect(control.selectedID == nil)
        #expect(recorder.selections.isEmpty)
    }

    @Test
    func startsEmptyAndCanPopulateClearAndRefill() {
        let control = ScrollableTabBar<TabID>()
        let recorder = SelectionRecorder<TabID>()
        control.delegate = recorder
        #expect(control.items.isEmpty)
        #expect(control.selectedID == nil)

        let items: [ScrollableTabBar<TabID>.Item] = [.init(id: .headers, title: "Headers")]
        control.setItems(items, selectedID: .headers)
        #expect(control.selectedID == .headers)
        control.setItems([], selectedID: nil)
        #expect(control.items.isEmpty)
        #expect(control.selectedID == nil)
        #expect(control.content.view.isHidden)
        control.setItems(items, selectedID: nil)
        #expect(control.items.map(\.id) == [.headers])
        #expect(control.selectedID == nil)
        #expect(recorder.selections.isEmpty)
        control.didSelectItem(id: .headers)
        #expect(recorder.selections == [.headers])
    }

    @Test
    func delayedSelectionUsesStableIdentityAfterReordering() throws {
        let control = makeControl(selectedID: .headers)
        let handler = try #require(control.content.selectionHandler)
        let recorder = SelectionRecorder<TabID>()
        control.delegate = recorder
        control.setItems(Array(control.items.reversed()), selectedID: .headers)
        handler(AnyHashable(TabID.cookies))
        #expect(control.selectedID == .cookies)
        #expect(recorder.selections == [.cookies])

        control.setItems(control.items.filter { $0.id != .cookies }, selectedID: .headers)
        handler(AnyHashable(TabID.cookies))
        #expect(control.selectedID == .headers)
        #expect(recorder.selections == [.cookies])
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
