import Testing
import UIKit
@testable import ScrollableTabBar

@MainActor
@Suite(.serialized)
struct SystemFloatingTabContentTests {
    private class GlassMetricsFixture: NSObject {}
    private final class GlassPhoneMetricsFixture: GlassMetricsFixture {}

    @Test
    func classifiesVerifiedGlassMetricsByInheritance() {
        #expect(
            ExpandedPaginationRuntime.isVerifiedGlassMetrics(
                GlassMetricsFixture(),
                baseClass: GlassMetricsFixture.self
            )
        )
        #expect(
            ExpandedPaginationRuntime.isVerifiedGlassMetrics(
                GlassPhoneMetricsFixture(),
                baseClass: GlassMetricsFixture.self
            )
        )
        #expect(
            ExpandedPaginationRuntime.isVerifiedGlassMetrics(
                NSObject(),
                baseClass: GlassMetricsFixture.self
            ) == false
        )
    }

    @Test
    func preservesPagingOutsideTheVerifiedRuntimeBranch() {
        let collectionView = UICollectionView(
            frame: .zero,
            collectionViewLayout: UICollectionViewFlowLayout()
        )
        collectionView.isPagingEnabled = true

        #expect(
            ExpandedPaginationRuntime.prepareCollectionView(
                collectionView,
                in: UIView()
            )
        )
        #expect(collectionView.isPagingEnabled)
    }

    @Test
    func usesFullWidthContinuousUIKitPresentationAndStableTabIdentity() throws {
        let content = try #require(makeContent())
        let originalTabIdentities = content.tabs.map(ObjectIdentifier.init)
        content.view.frame = CGRect(x: 0, y: 0, width: 314, height: 49)
        let host = UIViewController()
        host.view.addSubview(content.view)
        let window = showInWindow(host)
        defer { window.isHidden = true }

        content.render(
            selectedIndex: 0,
            isEnabled: true,
            accessibilityLabel: "Detail Mode",
            accessibilityIdentifier: "ScrollableTabBar.Control"
        )
        window.layoutIfNeeded()
        content.view.layoutIfNeeded()
        content.floatingView.floatingTabBar.layoutIfNeeded()

        let floatingTabBarClass: AnyClass = try #require(
            NSClassFromString("_UIFloatingTabBar")
        )
        #expect(content.floatingView.floatingTabBar.isKind(of: floatingTabBarClass))
        #expect(content.tabs.map(\.title) == ["Headers", "Preview", "Cookie", "Security"])
        #expect(content.tabs[0].accessibilityIdentifier == "ScrollableTabBar.Test.0")
        #expect(content.tabController.selectedTab === content.tabs[0])
        #expect(content.floatingView.accessibilityContainerType == .semanticGroup)
        #expect(content.floatingView.accessibilityLabel == "Detail Mode")
        #expect(
            content.floatingView.accessibilityIdentifier
                == "ScrollableTabBar.Control"
        )
        #expect(content.tabItemsView.contentSize.width > content.tabItemsView.bounds.width)
        #expect(content.tabItemsView.isPagingEnabled == false)
        #expect(
            descendants(of: content.floatingView.floatingTabBar).count {
                NSStringFromClass(type(of: $0)) == "_UIFloatingTabBarPageButton"
            } == 2
        )

        if #available(iOS 26.0, *) {
            let leftArrowButton = try #require(
                content.floatingView.floatingTabBar.value(
                    forKey: "leftArrowButton"
                ) as? UIView
            )
            let rightArrowButton = try #require(
                content.floatingView.floatingTabBar.value(
                    forKey: "rightArrowButton"
                ) as? UIView
            )
            #expect(
                content.tabItemsView.leftEdgeEffect.style.isEqual(
                    UIScrollEdgeEffect.Style.soft
                )
            )
            #expect(
                content.tabItemsView.rightEdgeEffect.style.isEqual(
                    UIScrollEdgeEffect.Style.soft
                )
            )
            #expect(
                content.tabItemsView.leftEdgeEffect.value(
                    forKey: "_overrideGeometryView"
                ) as? UIView === leftArrowButton
            )
            #expect(
                content.tabItemsView.rightEdgeEffect.value(
                    forKey: "_overrideGeometryView"
                ) as? UIView === rightArrowButton
            )
            #expect(content.tabItemsView.leftEdgeEffect.isHidden)
            #expect(content.tabItemsView.rightEdgeEffect.isHidden == false)
            let edgeEffectInteraction = try #require(
                content.tabItemsView.value(
                    forKey: "_edgeEffectViewInteraction"
                ) as? NSObject
            )
            let rightPocket = try #require(
                edgeEffectInteraction.value(
                    forKey: "rightPocket"
                ) as? UIView
            )
            let rightButton = try #require(
                rightArrowButton.value(forKey: "button") as? UIButton
            )
            let rightPocketFrame = rightPocket.convert(
                rightPocket.bounds,
                to: content.floatingView.floatingTabBar
            )
            let rightButtonFrame = rightButton.convert(
                rightButton.bounds,
                to: content.floatingView.floatingTabBar
            )
            let edgeTolerance = 1 / max(
                content.floatingView.traitCollection.displayScale,
                1
            )
            let rightPocketClass: AnyClass = try #require(
                object_getClass(rightPocket)
            )
            #expect(
                NSStringFromClass(rightPocketClass)
                    == "ScrollableTabBarRightEdgeEffectPocketView"
            )
            #expect(rightPocket.mask == nil)
            #expect(
                abs(rightPocketFrame.minX - rightButtonFrame.minX)
                    <= edgeTolerance
            )
            #expect(
                abs(rightPocketFrame.maxX - rightButtonFrame.maxX)
                    <= edgeTolerance
            )
            #expect(
                abs(rightPocketFrame.minY - rightButtonFrame.minY)
                    <= edgeTolerance
            )
            #expect(
                abs(rightPocketFrame.maxY - rightButtonFrame.maxY)
                    <= edgeTolerance
            )

            let initialContentView = try #require(
                content.floatingView.floatingTabBar.value(
                    forKey: "contentView"
                ) as? UIView
            )
            let selectionLens = try #require(
                descendants(
                    of: content.floatingView.floatingTabBar
                ).first {
                    NSStringFromClass(type(of: $0))
                        == "_UILiquidLensView"
                }
            )
            let contentFrame = initialContentView.convert(
                initialContentView.bounds,
                to: content.floatingView.floatingTabBar
            )
            let selectionFrame = selectionLens.convert(
                selectionLens.bounds,
                to: content.floatingView.floatingTabBar
            )
            let outerLeftCenter = CGPoint(
                x: contentFrame.minX + contentFrame.height / 2,
                y: contentFrame.midY
            )
            let selectionLeftCenter = CGPoint(
                x: selectionFrame.minX + selectionFrame.height / 2,
                y: selectionFrame.midY
            )
            #expect(
                abs(outerLeftCenter.x - selectionLeftCenter.x)
                    <= edgeTolerance
            )
            #expect(
                abs(outerLeftCenter.y - selectionLeftCenter.y)
                    <= edgeTolerance
            )
            #expect(
                content.tabItemsView.visibleCells.allSatisfy {
                    $0.contentView.alpha == 1
                }
            )
        }

        content.render(
            selectedIndex: 3,
            isEnabled: true,
            accessibilityLabel: "Detail Mode",
            accessibilityIdentifier: "ScrollableTabBar.Control"
        )

        #expect(content.tabController.selectedTab === content.tabs[3])
        #expect(content.tabs.map(ObjectIdentifier.init) == originalTabIdentities)

        if #available(iOS 26.0, *) {
            #expect(
                NSStringFromClass(type(of: content.floatingView.floatingTabBar))
                    == "ScrollableTabBarFullWidthPaginationFloatingTabBar"
            )
            #expect(
                NSStringFromClass(type(of: content.tabItemsView))
                    == "ScrollableTabBarFullWidthPaginationCollectionView"
            )
            let maximumContainerWidth = try #require(
                ExpandedPaginationRuntime.maximumContainerSize(
                    of: content.floatingView.floatingTabBar
                )?.width
            )
            let contentView = try #require(
                content.floatingView.floatingTabBar.value(
                    forKey: "contentView"
                ) as? UIView
            )
            let tolerance =
                1 / content.floatingView.traitCollection.displayScale
            #expect(
                abs(
                    maximumContainerWidth
                        - content.floatingView.floatingTabBar.bounds.width
                ) <= tolerance
            )
            #expect(
                abs(
                    contentView.bounds.width
                        - content.floatingView.floatingTabBar.bounds.width
                ) <= tolerance
            )
            #expect(content.floatingView.hasLiquidLens)
        }
    }

    @Test
    func fullWidthLayoutTracksBoundsChangesAndKeepsContinuousScrolling() throws {
        guard #available(iOS 26.0, *) else {
            return
        }

        let content = try #require(makeContent())
        let host = UIViewController()
        host.view.addSubview(content.view)
        let window = showInWindow(host)
        defer { window.isHidden = true }

        content.render(
            selectedIndex: 0,
            isEnabled: true,
            accessibilityLabel: "Detail Mode",
            accessibilityIdentifier: "ScrollableTabBar.Control"
        )

        for width: CGFloat in [240, 360, 314] {
            content.view.frame = CGRect(
                x: 0,
                y: 0,
                width: width,
                height: 49
            )
            window.layoutIfNeeded()
            content.view.layoutIfNeeded()
            content.floatingView.floatingTabBar.layoutIfNeeded()

            let contentView = try #require(
                content.floatingView.floatingTabBar.value(
                    forKey: "contentView"
                ) as? UIView
            )
            let maximumContainerWidth = try #require(
                ExpandedPaginationRuntime.maximumContainerSize(
                    of: content.floatingView.floatingTabBar
                )?.width
            )
            let tolerance = 1 / max(
                content.floatingView.traitCollection.displayScale,
                1
            )
            #expect(abs(contentView.bounds.width - width) <= tolerance)
            #expect(abs(maximumContainerWidth - width) <= tolerance)
            #expect(content.tabItemsView.bounds.width > width * 0.8)
            #expect(content.tabItemsView.frame.minX >= -tolerance)
            #expect(content.tabItemsView.frame.maxX <= width + tolerance)
            #expect(content.tabItemsView.isPagingEnabled == false)
        }

        content.tabItemsView.setContentOffset(
            CGPoint(x: 47.25, y: 0),
            animated: false
        )
        content.floatingView.floatingTabBar.setNeedsLayout()
        content.floatingView.floatingTabBar.layoutIfNeeded()
        #expect(
            content.tabItemsView.visibleCells.allSatisfy {
                $0.contentView.alpha == 1
            }
        )
        let fractionalContentView = try #require(
            content.floatingView.floatingTabBar.value(
                forKey: "contentView"
            ) as? UIView
        )
        let fractionalTolerance = 1 / max(
            content.floatingView.traitCollection.displayScale,
            1
        )
        #expect(
            abs(
                fractionalContentView.bounds.width
                    - content.view.bounds.width
            ) <= fractionalTolerance
        )
        #expect(
            content.tabItemsView.frame.maxX
                <= fractionalContentView.bounds.maxX + fractionalTolerance
        )

        var proposedOffset = CGPoint(x: 47.25, y: 0)
        let expectedOffset = proposedOffset
        unsafe content.tabItemsView.delegate?.scrollViewWillEndDragging?(
            content.tabItemsView,
            withVelocity: CGPoint(x: 0.75, y: 0),
            targetContentOffset: &proposedOffset
        )
        #expect(proposedOffset == expectedOffset)
    }

    @Test
    func pageTargetsUsePhysicalScrollRangeAndAlignLastItem() throws {
        guard #available(iOS 26.0, *) else {
            return
        }

        let content = try #require(
            makeContent(
                titles: [
                    "Overview",
                    "Headers",
                    "Preview",
                    "Cookies",
                    "Security",
                    "Timing",
                    "Response",
                ]
            )
        )
        content.view.frame = CGRect(x: 0, y: 0, width: 314, height: 49)
        let host = UIViewController()
        host.view.addSubview(content.view)
        let window = showInWindow(host)
        defer { window.isHidden = true }

        content.render(
            selectedIndex: 0,
            isEnabled: true,
            accessibilityLabel: "Detail Mode",
            accessibilityIdentifier: "ScrollableTabBar.Control"
        )
        window.layoutIfNeeded()
        content.view.layoutIfNeeded()
        content.floatingView.floatingTabBar.layoutIfNeeded()

        let pages = try #require(
            content.tabItemsView.value(forKey: "pages") as? NSArray
        )
        #expect(pages.count > 2)
        #expect(content.tabItemsView.contentInset.right == 0)

        let incrementSelector = NSSelectorFromString(
            "incrementTargetPage"
        )
        let scrollSelector = NSSelectorFromString(
            "scrollToTargetPageAnimated:"
        )
        let currentPageSelector = NSSelectorFromString("currentPage")
        typealias VoidImplementation =
            @convention(c) (AnyObject, Selector) -> Void
        typealias ScrollImplementation =
            @convention(c) (AnyObject, Selector, Bool) -> Void
        typealias CurrentPageImplementation =
            @convention(c) (AnyObject, Selector) -> CGFloat

        let increment = unsafe unsafeBitCast(
            content.tabItemsView.method(for: incrementSelector),
            to: VoidImplementation.self
        )
        let scroll = unsafe unsafeBitCast(
            content.tabItemsView.method(for: scrollSelector),
            to: ScrollImplementation.self
        )
        let currentPage = unsafe unsafeBitCast(
            content.tabItemsView.method(for: currentPageSelector),
            to: CurrentPageImplementation.self
        )

        for _ in 1..<pages.count {
            increment(content.tabItemsView, incrementSelector)
            scroll(content.tabItemsView, scrollSelector, false)
            content.floatingView.floatingTabBar.layoutIfNeeded()
        }

        let tolerance = 1 / max(
            content.floatingView.traitCollection.displayScale,
            1
        )
        #expect(
            abs(
                currentPage(content.tabItemsView, currentPageSelector)
                    - CGFloat(pages.count - 1)
            ) <= tolerance
        )
        let systemRightInset =
            content.tabItemsView.adjustedContentInset.right
            - content.tabItemsView.contentInset.right
        let maximumOffset =
            content.tabItemsView.contentSize.width
            - content.tabItemsView.bounds.width
            + systemRightInset
        #expect(
            abs(
                content.tabItemsView.contentOffset.x
                    - maximumOffset
            ) <= tolerance
        )
        #expect(content.tabItemsView.contentInset.right == 0)
        #expect(content.tabItemsView.rightEdgeEffect.isHidden)

        let edgeEffectInteraction = try #require(
            content.tabItemsView.value(
                forKey: "_edgeEffectViewInteraction"
            ) as? NSObject
        )
        let leftPocket = try #require(
            edgeEffectInteraction.value(
                forKey: "leftPocket"
            ) as? UIView
        )
        let leftPageButton = try #require(
            content.floatingView.floatingTabBar.value(
                forKey: "leftArrowButton"
            ) as? UIView
        )
        let leftButton = try #require(
            leftPageButton.value(forKey: "button") as? UIButton
        )
        let leftPocketFrame = leftPocket.convert(
            leftPocket.bounds,
            to: content.floatingView.floatingTabBar
        )
        let leftButtonFrame = leftButton.convert(
            leftButton.bounds,
            to: content.floatingView.floatingTabBar
        )
        let leftPocketClass: AnyClass = try #require(
            object_getClass(leftPocket)
        )
        #expect(
            NSStringFromClass(leftPocketClass)
                == "ScrollableTabBarLeftEdgeEffectPocketView"
        )
        #expect(leftPocket.mask == nil)
        #expect(
            abs(leftPocketFrame.minX - leftButtonFrame.minX)
                <= tolerance
        )
        #expect(
            abs(leftPocketFrame.maxX - leftButtonFrame.maxX)
                <= tolerance
        )
        #expect(
            abs(leftPocketFrame.minY - leftButtonFrame.minY)
                <= tolerance
        )
        #expect(
            abs(leftPocketFrame.maxY - leftButtonFrame.maxY)
                <= tolerance
        )
    }

    @Test
    func expandedWideLayoutFitsTheCurrentFourItemsWithoutPagination() throws {
        guard #available(iOS 26.0, *) else {
            return
        }

        let content = try #require(makeContent())
        content.view.frame = CGRect(x: 0, y: 0, width: 640, height: 49)
        let host = UIViewController()
        host.view.addSubview(content.view)
        let window = showInWindow(
            host,
            size: CGSize(width: 1_024, height: 768)
        )
        defer { window.isHidden = true }

        content.render(
            selectedIndex: 0,
            isEnabled: true,
            accessibilityLabel: "Detail Mode",
            accessibilityIdentifier: "ScrollableTabBar.Control"
        )
        window.layoutIfNeeded()
        content.view.layoutIfNeeded()
        content.floatingView.floatingTabBar.layoutIfNeeded()

        #expect(content.tabItemsView.contentSize.width <= content.tabItemsView.bounds.width)
    }

    @Test
    func translatesDelegateSelectionAndDisabledState() throws {
        let content = try #require(makeContent())
        var selectedIndices: [Int] = []
        content.selectionHandler = { index in
            selectedIndices.append(index)
        }
        content.render(
            selectedIndex: 0,
            isEnabled: true,
            accessibilityLabel: "Detail Mode",
            accessibilityIdentifier: "ScrollableTabBar.Control"
        )

        content.tabBarController(
            content.tabController,
            didSelectTab: content.tabs[2],
            previousTab: content.tabs[0]
        )

        #expect(selectedIndices == [2])

        content.render(
            selectedIndex: 2,
            isEnabled: false,
            accessibilityLabel: "Detail Mode",
            accessibilityIdentifier: "ScrollableTabBar.Control"
        )
        #expect(content.floatingView.isUserInteractionEnabled == false)
        #expect(content.floatingView.alpha == 0.5)
        if #available(iOS 18.4, *) {
            #expect(content.tabs.allSatisfy { $0.isEnabled == false })
        }

        content.tabBarController(
            content.tabController,
            didSelectTab: content.tabs[2],
            previousTab: content.tabs[0]
        )
        #expect(selectedIndices == [2])
    }

    @Test
    func detachesTabModelAndControllerRelationships() throws {
        var content: SystemFloatingTabContent? = makeContent()
        let floatingTabBar = try #require(content?.floatingView.floatingTabBar)
        let tabController = try #require(content?.tabController)
        #expect(floatingTabBar.value(forKey: "_tabModel") != nil)

        content = nil

        #expect(floatingTabBar.value(forKey: "_tabModel") == nil)
        #expect(tabController.delegate == nil)
        #expect(tabController.tabs.isEmpty)
    }

    private func makeContent(
        titles: [String] = [
            "Headers",
            "Preview",
            "Cookie",
            "Security",
        ]
    ) -> SystemFloatingTabContent? {
        SystemFloatingTabContent.makeIfAvailable(
            items: titles.enumerated().map { index, title in
                .init(
                    title: title,
                    image: nil,
                    accessibilityIdentifier:
                        "ScrollableTabBar.Test.\(index)"
                )
            },
            selectedIndex: 0
        )
    }

    private func showInWindow(
        _ viewController: UIViewController,
        size: CGSize = CGSize(width: 390, height: 844)
    ) -> UIWindow {
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = viewController
        viewController.loadViewIfNeeded()
        viewController.view.frame = window.bounds
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        return window
    }

    private func descendants(of view: UIView) -> [UIView] {
        view.subviews.flatMap { subview in
            [subview] + descendants(of: subview)
        }
    }
}
