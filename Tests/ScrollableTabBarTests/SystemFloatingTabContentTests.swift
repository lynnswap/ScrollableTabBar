import Testing
import UIKit
@testable import ScrollableTabBar

@MainActor
@Suite(.serialized)
struct SystemFloatingTabContentTests {
    private class MetricsFixture: NSObject {}
    private final class PhoneMetricsFixture: MetricsFixture {}

    @Test
    func classifiesVerifiedPlatformMetricsByInheritance() {
        #expect(
            ExpandedPaginationRuntime.isVerifiedPlatformMetrics(
                MetricsFixture(),
                baseClass: MetricsFixture.self
            )
        )
        #expect(
            ExpandedPaginationRuntime.isVerifiedPlatformMetrics(
                PhoneMetricsFixture(),
                baseClass: MetricsFixture.self
            )
        )
        #expect(
            ExpandedPaginationRuntime.isVerifiedPlatformMetrics(
                NSObject(),
                baseClass: MetricsFixture.self
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
            #expect(content.tabItemsView.leftEdgeEffect.isHidden)
            #expect(content.tabItemsView.rightEdgeEffect.isHidden == false)
            let edgeEffectInteraction = try #require(
                content.tabItemsView.value(
                    forKey: "_edgeEffectViewInteraction"
                ) as? NSObject
            )
            let effectView = try #require(
                edgeEffectInteraction.value(
                    forKey: "effectView"
                ) as? UIView
            )
            let captureView = try #require(
                edgeEffectInteraction.value(
                    forKey: "captureView"
                ) as? UIView
            )
            let rightPocket = try #require(
                edgeEffectInteraction.value(
                    forKey: "rightPocket"
                ) as? UIView
            )
            let rightButton = try #require(
                rightArrowButton.value(forKey: "button") as? UIView
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
            let effectFrame = effectView.convert(
                effectView.bounds,
                to: content.floatingView.floatingTabBar
            )
            let captureFrame = captureView.convert(
                captureView.bounds,
                to: content.floatingView.floatingTabBar
            )
            let floatingBounds =
                content.floatingView.floatingTabBar.bounds
            #expect(
                abs(effectFrame.minX - floatingBounds.minX)
                    <= edgeTolerance
            )
            #expect(
                abs(effectFrame.maxX - floatingBounds.maxX)
                    <= edgeTolerance
            )
            #expect(
                abs(captureFrame.minX - floatingBounds.minX)
                    <= edgeTolerance
            )
            #expect(
                abs(captureFrame.maxX - floatingBounds.maxX)
                    <= edgeTolerance
            )
            #expect(rightPocketFrame.width > rightButtonFrame.width)
            #expect(
                abs(rightPocketFrame.maxX - rightButtonFrame.maxX)
                    <= edgeTolerance
            )
            let leftInteractions = leftArrowButton.interactions.compactMap {
                $0 as? UIScrollEdgeElementContainerInteraction
            }.filter {
                $0.scrollView === content.tabItemsView && $0.edge == .left
            }
            let rightInteractions = rightArrowButton.interactions.compactMap {
                $0 as? UIScrollEdgeElementContainerInteraction
            }.filter {
                $0.scrollView === content.tabItemsView && $0.edge == .right
            }
            #expect(leftInteractions.count == 1)
            #expect(rightInteractions.count == 1)

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
        if #available(iOS 26.0, *) {
            #expect(content.floatingView.hasLiquidLens)
        }
    }

    @Test
    func fullWidthLayoutTracksBoundsChangesAndKeepsContinuousScrolling() throws {
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
            if #available(iOS 26.0, *) {
                let interaction = try #require(
                    content.tabItemsView.value(
                        forKey: "_edgeEffectViewInteraction"
                    ) as? NSObject
                )
                for key in ["effectView", "captureView"] {
                    let edgeView = try #require(
                        interaction.value(forKey: key) as? UIView
                    )
                    let edgeFrame = edgeView.convert(
                        edgeView.bounds,
                        to: content.floatingView.floatingTabBar
                    )
                    #expect(
                        abs(edgeFrame.minX) <= tolerance
                    )
                    #expect(
                        abs(edgeFrame.maxX - width) <= tolerance
                    )
                }
            }
        }

        content.tabItemsView.setContentOffset(
            CGPoint(x: 47.25, y: 0),
            animated: false
        )
        content.floatingView.floatingTabBar.setNeedsLayout()
        content.floatingView.floatingTabBar.layoutIfNeeded()
        if #available(iOS 26.0, *) {
            #expect(
                content.tabItemsView.visibleCells.allSatisfy {
                    $0.contentView.alpha == 1
                }
            )
        }
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
    func expandedCollectionOwnsViewportFrameMutation() throws {
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

        let tolerance = 1 / max(
            content.floatingView.traitCollection.displayScale,
            1
        )
        let expandedFrame = content.tabItemsView.frame

        var nativeProposedFrame = expandedFrame
        nativeProposedFrame.origin.x += 3
        nativeProposedFrame.size.width -= 60
        content.tabItemsView.frame = nativeProposedFrame

        #expect(
            abs(content.tabItemsView.frame.minX - nativeProposedFrame.minX)
                <= tolerance
        )
        #expect(
            abs(content.tabItemsView.frame.height - nativeProposedFrame.height)
                <= tolerance
        )
        #expect(
            content.tabItemsView.frame.width
                >= expandedFrame.width - tolerance
        )

        var stretchedFrame = nativeProposedFrame
        stretchedFrame.size.width = expandedFrame.width + 18
        content.tabItemsView.frame = stretchedFrame
        #expect(
            abs(content.tabItemsView.frame.width - stretchedFrame.width)
                <= tolerance
        )
    }

    @Test(arguments: [CGFloat(-40), CGFloat(40)])
    func navigationTitleLayoutPreservesOverscrollWhenViewportMoves(
        overscroll: CGFloat
    ) throws {
        let control = ScrollableTabBar(
            items: ["Headers", "Preview", "Cookies", "Security"]
                .enumerated().map { .init(id: $0.offset, title: $0.element) },
            selectedID: 0
        )
        let content = try #require(control.content as? SystemFloatingTabContent)
        let root = UIViewController()
        root.navigationItem.backButtonDisplayMode = .minimal
        let detail = UIViewController()
        detail.navigationItem.titleView = control
        detail.navigationItem.rightBarButtonItem = UIBarButtonItem(
            systemItem: .done
        )
        let navigation = UINavigationController(rootViewController: root)
        navigation.setViewControllers([root, detail], animated: false)
        let window = showInWindow(navigation)
        defer { window.isHidden = true }
        control.layoutIfNeeded()
        let collection = content.tabItemsView
        let bar = content.floatingView.floatingTabBar
        bar.layoutIfNeeded()

        #expect(collection.contentSize.width > collection.bounds.width)
        let edge = overscroll < 0
            ? -collection.adjustedContentInset.left
            : collection.contentSize.width - collection.bounds.width
                + collection.adjustedContentInset.right
        collection.contentOffset.x = edge + overscroll
        let expectedOffset = collection.contentOffset
        let tolerance = 1 / max(control.traitCollection.displayScale, 1)

        // Page arrows move the viewport while a drag is beyond an edge.
        // Repositioning it must not change the scroll position.
        var proposedFrame = collection.frame
        proposedFrame.origin.x += 3
        collection.frame = proposedFrame
        #expect(abs(collection.contentOffset.x - expectedOffset.x) <= tolerance)
        #expect(abs(collection.frame.minX - proposedFrame.minX) <= tolerance)

        collection.frame = proposedFrame
        #expect(abs(collection.contentOffset.x - expectedOffset.x) <= tolerance)
    }

    @Test
    func trailingDecelerationTargetsTheFinalPhysicalEdge() throws {
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
        let finalPage = pages.count - 1
        let targetPageSelector = NSSelectorFromString("targetPage")
        let contentOffsetSelector = NSSelectorFromString(
            "contentOffsetForPage:"
        )
        typealias TargetPageImplementation =
            @convention(c) (AnyObject, Selector) -> Int
        typealias ContentOffsetImplementation =
            @convention(c) (AnyObject, Selector, Int) -> CGPoint

        let targetPage = unsafe unsafeBitCast(
            content.tabItemsView.method(for: targetPageSelector),
            to: TargetPageImplementation.self
        )
        let contentOffset = unsafe unsafeBitCast(
            content.tabItemsView.method(for: contentOffsetSelector),
            to: ContentOffsetImplementation.self
        )

        let pageTargets = (0..<pages.count).map { page in
            contentOffset(
                content.tabItemsView,
                contentOffsetSelector,
                page
            ).x
        }
        #expect(
            zip(pageTargets, pageTargets.dropFirst()).allSatisfy {
                $0.0 < $0.1
            }
        )

        var proposedOffset = CGPoint(
            x: pageTargets[finalPage] + 100,
            y: 0
        )
        unsafe content.tabItemsView.delegate?.scrollViewWillEndDragging?(
            content.tabItemsView,
            withVelocity: CGPoint(x: 2, y: 0),
            targetContentOffset: &proposedOffset
        )

        let finalMaximumOffset = pageTargets[finalPage]
        let tolerance = 1 / max(
            content.floatingView.traitCollection.displayScale,
            1
        )
        #expect(
            targetPage(content.tabItemsView, targetPageSelector)
                == finalPage
        )
        #expect(
            abs(proposedOffset.x - finalMaximumOffset) <= tolerance
        )
    }

    @Test
    func pageTargetsUsePhysicalScrollRangeAndAlignLastItem() throws {
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
        #expect(content.tabItemsView.contentInset.left == 0)
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
        #expect(content.tabItemsView.contentInset.left == 0)
        #expect(content.tabItemsView.contentInset.right == 0)
        if #available(iOS 26.0, *) {
            #expect(content.tabItemsView.rightEdgeEffect.isHidden)
            #expect(content.tabItemsView.leftEdgeEffect.isHidden == false)
            let edgeEffectInteraction = try #require(
                content.tabItemsView.value(
                    forKey: "_edgeEffectViewInteraction"
                ) as? NSObject
            )
            let effectView = try #require(
                edgeEffectInteraction.value(
                    forKey: "effectView"
                ) as? UIView
            )
            let captureView = try #require(
                edgeEffectInteraction.value(
                    forKey: "captureView"
                ) as? UIView
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
                leftPageButton.value(forKey: "button") as? UIView
            )
            let leftPocketFrame = leftPocket.convert(
                leftPocket.bounds,
                to: content.floatingView.floatingTabBar
            )
            let leftButtonFrame = leftButton.convert(
                leftButton.bounds,
                to: content.floatingView.floatingTabBar
            )
            let effectFrame = effectView.convert(
                effectView.bounds,
                to: content.floatingView.floatingTabBar
            )
            let captureFrame = captureView.convert(
                captureView.bounds,
                to: content.floatingView.floatingTabBar
            )
            let floatingBounds =
                content.floatingView.floatingTabBar.bounds
            #expect(
                abs(effectFrame.minX - floatingBounds.minX)
                    <= tolerance
            )
            #expect(
                abs(effectFrame.maxX - floatingBounds.maxX)
                    <= tolerance
            )
            #expect(
                abs(captureFrame.minX - floatingBounds.minX)
                    <= tolerance
            )
            #expect(
                abs(captureFrame.maxX - floatingBounds.maxX)
                    <= tolerance
            )
            #expect(leftPocketFrame.width > leftButtonFrame.width)
            #expect(
                abs(leftPocketFrame.minX - leftButtonFrame.minX)
                    <= tolerance
            )
        }
    }

    @Test
    func expandedWideLayoutFitsTheCurrentFourItemsWithoutPagination() throws {
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
    func pageModelWidthSupportsBothDirections() {
        #expect(
            ExpandedPaginationRuntime.semanticPageModelWidth(
                firstPageOrigin: 0,
                firstPageWidth: 180,
                finalPageOrigin: 420,
                finalPageWidth: 200
            ) == 620
        )
        #expect(
            ExpandedPaginationRuntime.semanticPageModelWidth(
                firstPageOrigin: 440,
                firstPageWidth: 180,
                finalPageOrigin: 0,
                finalPageWidth: 200
            ) == 620
        )
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
