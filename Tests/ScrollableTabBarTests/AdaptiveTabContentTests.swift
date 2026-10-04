import Testing
import UIKit
@testable import ScrollableTabBar

@MainActor
@Suite(.serialized)
struct AdaptiveTabContentTests {
    @Test
    func rendersEquivalentSegmentedAndMenuSelection() {
        let content = makeContent()
        content.render(
            selectedIndex: 2,
            isEnabled: true,
            accessibilityLabel: "Detail Mode",
            accessibilityIdentifier: "ScrollableTabBar.Control"
        )

        #expect(content.segmentedControl.selectedSegmentIndex == 2)
        #expect(content.segmentedControl.accessibilityLabel == "Detail Mode")
        #expect(content.segmentedControl.accessibilityValue == "Cookies")
        #expect(
            content.segmentedControl.accessibilityIdentifier
                == "ScrollableTabBar.Control"
        )
        #expect(content.menuButton.configuration?.title == "Cookies")
        #expect(content.menuButton.accessibilityLabel == "Detail Mode")
        #expect(content.menuButton.accessibilityValue == "Cookies")
        #expect(content.menuButton.accessibilityIdentifier == "ScrollableTabBar.Control")
        let menuActions = content.menuButton.menu?.children.compactMap { $0 as? UIAction }
        #expect(menuActions?.map(\.title) == ["Headers", "Preview", "Cookies", "Security"])
        #expect(
            menuActions?.map(\.accessibilityIdentifier)
                == (0..<4).map { "ScrollableTabBar.Test.\($0)" }
        )
        #expect(menuActions?.map(\.state) == [.off, .off, .on, .off])
        #expect(
            (0..<content.segmentedControl.numberOfSegments).map {
                content.segmentedControl.actionForSegment(at: $0)?.accessibilityIdentifier
            } == (0..<4).map { "ScrollableTabBar.Test.\($0)" }
        )
    }

    @Test
    func segmentedSelectionUsesItsUIActionPath() {
        let content = makeContent()
        var selectedIndices: [AnyHashable] = []
        content.selectionHandler = { index in
            selectedIndices.append(index)
        }
        content.render(
            selectedIndex: 0,
            isEnabled: true,
            accessibilityLabel: nil,
            accessibilityIdentifier: "ScrollableTabBar.Control"
        )

        content.segmentedControl.selectedSegmentIndex = 3
        content.segmentedControl.sendActions(for: .valueChanged)

        #expect(selectedIndices == [3])
    }

    @Test
    func disabledStateAppliesToBothPresentations() {
        let content = makeContent()
        content.render(
            selectedIndex: 1,
            isEnabled: false,
            accessibilityLabel: "Detail Mode",
            accessibilityIdentifier: "ScrollableTabBar.Control"
        )

        #expect(content.segmentedControl.isEnabled == false)
        #expect(content.menuButton.isEnabled == false)
        #expect((0..<content.segmentedControl.numberOfSegments).allSatisfy {
            content.segmentedControl.isEnabledForSegment(at: $0) == false
        })
    }

    @Test
    func adaptsRegularContentAndAccessibilitySizes() {
        let regular = UITraitCollection(horizontalSizeClass: .regular)
        let compact = UITraitCollection(horizontalSizeClass: .compact)
        let accessibilityRegular = UITraitCollection { mutableTraits in
            mutableTraits.horizontalSizeClass = .regular
            mutableTraits.preferredContentSizeCategory = .accessibilityLarge
        }

        #expect(AdaptiveTabView.presentation(for: regular) == .segmented)
        #expect(AdaptiveTabView.presentation(for: compact) == .menu)
        #expect(AdaptiveTabView.presentation(for: accessibilityRegular) == .menu)
    }

    @Test
    func adaptiveSizingPreservesTheActiveControlHeight() {
        let content = makeContent()
        content.adaptiveView.traitOverrides.horizontalSizeClass = .compact
        content.adaptiveView.updateTraitsIfNeeded()
        var configuration = content.menuButton.configuration ?? .plain()
        configuration.contentInsets = NSDirectionalEdgeInsets(
            top: 32,
            leading: 12,
            bottom: 32,
            trailing: 12
        )
        content.menuButton.configuration = configuration
        content.render(
            selectedIndex: 0,
            isEnabled: true,
            accessibilityLabel: "Detail Mode",
            accessibilityIdentifier: "ScrollableTabBar.Control"
        )

        let activeHeight = content.adaptiveView.intrinsicContentSize.height

        #expect(activeHeight > scrollableTabBarMinimumHeight)
        #expect(content.intrinsicHeight == activeHeight)
        #expect(
            content.heightThatFits(CGSize(width: 240, height: 1))
                >= activeHeight
        )
    }

    @Test
    func updatesBothPresentationsAndClearsSelection() throws {
        let content = makeContent()
        let updated: [ScrollableTabBarPresentationItem] = [
            .init(
                id: 3, title: "Permissions", image: nil, accessibilityIdentifier: "Updated.Security"
            ),
            .init(id: 4, title: "Timing", image: nil, accessibilityIdentifier: "Updated.Timing"),
        ]
        #expect(content.setItems(updated, selectedIndex: nil))
        content.render(
            selectedIndex: nil, isEnabled: true, accessibilityLabel: "Mode",
            accessibilityIdentifier: "Control")
        #expect(content.segmentedControl.numberOfSegments == 2)
        #expect(content.segmentedControl.selectedSegmentIndex == UISegmentedControl.noSegment)
        #expect(content.segmentedControl.accessibilityValue == nil)
        let actions = try #require(content.menuButton.menu?.children.compactMap { $0 as? UIAction })
        #expect(actions.map(\.title) == ["Permissions", "Timing"])
        #expect(actions.map(\.state) == [.off, .off])

        #expect(content.setItems([], selectedIndex: nil))
        content.render(
            selectedIndex: nil, isEnabled: true, accessibilityLabel: "Mode",
            accessibilityIdentifier: "Control")
        #expect(content.segmentedControl.numberOfSegments == 0)
        #expect(content.menuButton.menu?.children.isEmpty == true)
        #expect(content.view.isHidden)
    }

    @Test
    func menuActionsKeepTheirIDsAcrossUpdates() throws {
        let content = makeContent()
        content.render(
            selectedIndex: 0, isEnabled: true, accessibilityLabel: nil, accessibilityIdentifier: nil
        )
        let action = try #require(content.menuButton.menu?.children.last as? UIAction)
        var selectedIDs: [AnyHashable] = []
        content.selectionHandler = { selectedIDs.append($0) }
        #expect(
            content.setItems(
                [
                    .init(id: 3, title: "Permissions", image: nil, accessibilityIdentifier: nil),
                    .init(id: 0, title: "Headers", image: nil, accessibilityIdentifier: nil),
                ], selectedIndex: 1))
        content.menuButton.sendAction(action)
        #expect(selectedIDs == [3])
    }

    private func makeContent() -> AdaptiveTabContent {
        AdaptiveTabContent(
            items: [
                .init(
                    id: 0,
                    title: "Headers",
                    image: nil,
                    accessibilityIdentifier: "ScrollableTabBar.Test.0"
                ),
                .init(
                    id: 1,
                    title: "Preview",
                    image: nil,
                    accessibilityIdentifier: "ScrollableTabBar.Test.1"
                ),
                .init(
                    id: 2,
                    title: "Cookies",
                    image: nil,
                    accessibilityIdentifier: "ScrollableTabBar.Test.2"
                ),
                .init(
                    id: 3,
                    title: "Security",
                    image: nil,
                    accessibilityIdentifier: "ScrollableTabBar.Test.3"
                ),
            ]
        )
    }
}
