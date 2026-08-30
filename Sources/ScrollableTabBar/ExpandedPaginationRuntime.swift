import ObjectiveC
import UIKit

@MainActor
enum ExpandedPaginationRuntime {
    private typealias MaximumContainerSizeImplementation =
        @convention(c) (AnyObject, Selector) -> CGSize
    private typealias LayoutSubviewsImplementation =
        @convention(c) (AnyObject, Selector) -> Void
    private typealias SetFrameImplementation =
        @convention(c) (AnyObject, Selector, CGRect) -> Void
    private typealias SetContentInsetImplementation =
        @convention(c) (AnyObject, Selector, UIEdgeInsets) -> Void
    private typealias ObjectGetterImplementation =
        @convention(c) (AnyObject, Selector) -> AnyObject?
    private typealias ForceEdgeEffectPocketImplementation =
        @convention(c) (AnyObject, Selector, UInt) -> AnyObject?
    private typealias PageViewportWidthImplementation =
        @convention(c) (AnyObject, Selector, CGFloat) -> CGFloat
    private typealias CurrentPageImplementation =
        @convention(c) (AnyObject, Selector) -> CGFloat
    private typealias BackgroundInsetsImplementation =
        @convention(c) (AnyObject, Selector) -> UIEdgeInsets
    private typealias UpdateItemContentAlphaImplementation =
        @convention(c) (AnyObject, Selector, NSIndexPath) -> Void
    private typealias GestureIndexPathImplementation =
        @convention(c) (
            AnyObject,
            Selector,
            UIGestureRecognizer
        ) -> NSIndexPath?
    private typealias ScrollViewWillEndDraggingImplementation =
        @convention(c) (
            AnyObject,
            Selector,
            UIScrollView,
            CGPoint,
            UnsafeMutablePointer<CGPoint>
        ) -> Void
    private typealias ContentOffsetForPageImplementation =
        @convention(c) (AnyObject, Selector, Int) -> CGPoint
    private typealias PageProgressForContentOffsetImplementation =
        @convention(c) (
            AnyObject,
            Selector,
            CGPoint,
            Bool
        ) -> CGFloat
    private typealias EdgeEffectGeometryViewSetter =
        @convention(c) (AnyObject, Selector, UIView?) -> Void
    private typealias PageButtonContentOpacityImplementation =
        @convention(c) (AnyObject, Selector) -> CGFloat
    private typealias PageWidthImplementation =
        @convention(c) (AnyObject, Selector) -> CGFloat

    private static let expandedFloatingTabBarClassName =
        "ScrollableTabBarFullWidthPaginationFloatingTabBar"
    private static let expandedCollectionViewClassName =
        "ScrollableTabBarFullWidthPaginationCollectionView"
    private static let leftAlignedEdgeEffectPocketClassName =
        "ScrollableTabBarLeftAlignedEdgeEffectPocketView"
    private static let rightAlignedEdgeEffectPocketClassName =
        "ScrollableTabBarRightAlignedEdgeEffectPocketView"
    private static let expandedEdgeEffectViewClassName =
        "ScrollableTabBarExpandedEdgeEffectView"
    private static let expandedEdgeCaptureViewClassName =
        "ScrollableTabBarExpandedEdgeCaptureView"
    private static let expectedMaximumContainerSizeTypeEncoding =
        "{CGSize=dd}16@0:8"
    private static let expectedLayoutSubviewsTypeEncoding = "v16@0:8"
    private static let expectedSetFrameTypeEncoding =
        "v48@0:8{CGRect={CGPoint=dd}{CGSize=dd}}16"
    private static let expectedSetContentInsetTypeEncoding =
        "v48@0:8{UIEdgeInsets=dddd}16"
    private static let expectedPageViewportWidthTypeEncoding = "d24@0:8d16"
    private static let expectedCurrentPageTypeEncoding = "d16@0:8"
    private static let expectedBackgroundInsetsTypeEncoding =
        "{UIEdgeInsets=dddd}16@0:8"
    private static let expectedUpdateItemContentAlphaTypeEncoding =
        "v24@0:8@16"
    private static let expectedGestureIndexPathTypeEncoding =
        "@24@0:8@16"
    private static let expectedScrollViewWillEndDraggingTypeEncoding =
        "v48@0:8@16{CGPoint=dd}24N^{CGPoint=dd}40"
    private static let expectedContentOffsetForPageTypeEncoding =
        "{CGPoint=dd}24@0:8q16"
    private static let expectedPageProgressForContentOffsetTypeEncoding =
        "d36@0:8{CGPoint=dd}16B32"
    private static let expectedEdgeEffectGeometryViewSetterTypeEncoding =
        "v24@0:8@16"
    private static let expectedObjectGetterTypeEncoding = "@16@0:8"
    private static let expectedForceEdgeEffectPocketTypeEncoding =
        "@24@0:8Q16"
    private static let expectedVoidMethodTypeEncoding = "v16@0:8"
    private static let expectedPageButtonContentOpacityTypeEncoding =
        "d16@0:8"
    private static let expectedPageWidthTypeEncoding = "d16@0:8"
    // Match UIView's effective visibility boundary so the blur and hit region
    // disappear with the native arrow rather than its floating-point tail.
    private static let minimumVisiblePageButtonOpacity: CGFloat = 0.01

    static func makeFloatingTabBar(
        baseClass: UIView.Type
    ) -> UIView {
        guard let expandedClass = makeExpandedFloatingTabBarClass(
            baseClass: baseClass
        ) else {
            return baseClass.init(frame: .zero)
        }

        let expandedTabBar = expandedClass.init(frame: .zero)
        guard expandedTabBar.responds(
            to: PrivateUIKitRuntimeNames.currentPlatformMetricsSelector
        ),
              let metrics = unsafe expandedTabBar
                .perform(PrivateUIKitRuntimeNames.currentPlatformMetricsSelector)?
                .takeUnretainedValue() else {
            scrollableTabBarLogger.error(
                "UIKit's floating tab metrics are unavailable; retaining the standard pagination width."
            )
            return baseClass.init(frame: .zero)
        }
        guard let metricsBaseClass = verifiedPlatformMetricsBaseClass(),
              isVerifiedPlatformMetrics(
                metrics,
                baseClass: metricsBaseClass
              ) else {
            scrollableTabBarLogger.error(
                "UIKit's floating tab metrics are not a verified platform implementation; retaining the standard pagination width."
            )
            return baseClass.init(frame: .zero)
        }
        return expandedTabBar
    }

    static func prepareCollectionView(
        _ collectionView: UICollectionView,
        in floatingTabBar: UIView
    ) -> Bool {
        guard NSStringFromClass(type(of: floatingTabBar))
                == expandedFloatingTabBarClassName else {
            return true
        }

        guard collectionView.contentInset == .zero else {
            scrollableTabBarLogger.error(
                "UIKit's floating-tab scroll contract changed; using the public adaptive tab control."
            )
            return false
        }
        if #available(iOS 26.0, *),
           configureEdgeEffects(
               on: collectionView,
               in: floatingTabBar
           ) == false {
            scrollableTabBarLogger.error(
                "UIKit's floating-tab scroll contract changed; using the public adaptive tab control."
            )
            return false
        }

        collectionView.isPagingEnabled = false
        if NSStringFromClass(type(of: collectionView))
            == expandedCollectionViewClassName {
            return true
        }

        let layout = collectionView.collectionViewLayout
        guard layout.responds(
            to: PrivateUIKitRuntimeNames.floatingTabBarSelector
        ),
              let layoutOwner = unsafe layout
                .perform(PrivateUIKitRuntimeNames.floatingTabBarSelector)?
                .takeUnretainedValue() as? UIView,
              layoutOwner === floatingTabBar,
              let baseClass = object_getClass(collectionView),
              let expandedClass = makeExpandedCollectionViewClass(
                baseClass: baseClass
              ) else {
            scrollableTabBarLogger.error(
                "UIKit's floating-tab collection contract changed; using the public adaptive tab control."
            )
            return false
        }

        let previousClass: AnyClass? = object_setClass(
            collectionView,
            expandedClass
        )
        guard previousClass === baseClass else {
            scrollableTabBarLogger.fault(
                "UIKit changed the floating-tab collection class during configuration."
            )
            return false
        }
        floatingTabBar.setNeedsLayout()
        return true
    }

    static func isVerifiedPlatformMetrics(
        _ metrics: AnyObject,
        baseClass: AnyClass
    ) -> Bool {
        // UIKit can specialize a verified metrics base with device-specific
        // subclasses, so exact type equality would reject compatible runtimes.
        (metrics as? NSObject)?.isKind(of: baseClass) == true
    }

    private static func verifiedPlatformMetricsBaseClass() -> AnyClass? {
        // iOS 18 uses the legacy material metrics while iOS 26 moves the same
        // pagination contract onto its Glass metrics hierarchy.
        let className = if #available(iOS 26.0, *) {
            PrivateUIKitRuntimeNames
                .floatingTabBarPlatformMetricsGlassBaseClassName
        } else {
            PrivateUIKitRuntimeNames
                .floatingTabBarPlatformMetricsBaseClassName
        }
        return NSClassFromString(className)
    }

    static func maximumContainerSize(of floatingTabBar: UIView) -> CGSize? {
        let selector = PrivateUIKitRuntimeNames.maximumContainerSizeSelector
        guard floatingTabBar.responds(to: selector) else {
            return nil
        }
        let implementation = unsafe unsafeBitCast(
            floatingTabBar.method(for: selector),
            to: MaximumContainerSizeImplementation.self
        )
        return implementation(floatingTabBar, selector)
    }

    private static func makeExpandedFloatingTabBarClass(
        baseClass: UIView.Type
    ) -> UIView.Type? {
        if let existingClass = NSClassFromString(
            expandedFloatingTabBarClassName
        ) {
            guard class_getSuperclass(existingClass) === baseClass else {
                scrollableTabBarLogger.fault(
                    "The ScrollableTabBar runtime class has an unexpected superclass."
                )
                return nil
            }
            return existingClass as? UIView.Type
        }

        let maximumSizeSelector =
            PrivateUIKitRuntimeNames.maximumContainerSizeSelector
        let layoutSelector = #selector(UIView.layoutSubviews)
        let updateAlphaSelector =
            PrivateUIKitRuntimeNames.updateItemContentAlphaSelector
        let gestureIndexPathSelector =
            PrivateUIKitRuntimeNames.gestureIndexPathSelector
        let scrollViewWillEndDraggingSelector = #selector(
            UIScrollViewDelegate.scrollViewWillEndDragging(
                _:withVelocity:targetContentOffset:
            )
        )
        guard let maximumSizeMethod = unsafe verifiedMethod(
            on: baseClass,
            selector: maximumSizeSelector,
            typeEncoding: expectedMaximumContainerSizeTypeEncoding
        ),
              let layoutMethod = unsafe verifiedMethod(
                on: baseClass,
                selector: layoutSelector,
                typeEncoding: expectedLayoutSubviewsTypeEncoding
              ),
              let updateAlphaMethod = unsafe verifiedMethod(
                on: baseClass,
                selector: updateAlphaSelector,
                typeEncoding: expectedUpdateItemContentAlphaTypeEncoding
              ),
              let gestureIndexPathMethod = unsafe verifiedMethod(
                on: baseClass,
                selector: gestureIndexPathSelector,
                typeEncoding: expectedGestureIndexPathTypeEncoding
              ),
              let scrollViewWillEndDraggingMethod = unsafe verifiedMethod(
                on: baseClass,
                selector: scrollViewWillEndDraggingSelector,
                typeEncoding:
                    expectedScrollViewWillEndDraggingTypeEncoding
              ) else {
            scrollableTabBarLogger.error(
                "UIKit's floating-tab interaction contract changed; retaining the standard presentation."
            )
            return nil
        }

        let originalMaximumSizeImplementation =
            unsafe method_getImplementation(maximumSizeMethod)
        let maximumSizeBlock: @convention(block) (AnyObject) -> CGSize = {
            object in
            let implementation = unsafe unsafeBitCast(
                originalMaximumSizeImplementation,
                to: MaximumContainerSizeImplementation.self
            )
            let originalSize = implementation(object, maximumSizeSelector)
            guard let view = object as? UIView,
                  view.bounds.width.isFinite,
                  view.bounds.width > 0,
                  originalSize.height.isFinite,
                  originalSize.height > 0 else {
                return originalSize
            }
            return CGSize(
                width: view.bounds.width,
                height: originalSize.height
            )
        }
        let maximumSizeOverride = unsafe imp_implementationWithBlock(
            maximumSizeBlock
        )

        let originalLayoutImplementation =
            unsafe method_getImplementation(layoutMethod)
        let layoutBlock: @convention(block) (AnyObject) -> Void = { object in
            let implementation = unsafe unsafeBitCast(
                originalLayoutImplementation,
                to: LayoutSubviewsImplementation.self
            )
            implementation(object, layoutSelector)
            synchronizeEdgeEffectVisibility(in: object)
        }
        let layoutOverride = unsafe imp_implementationWithBlock(layoutBlock)

        let originalUpdateAlphaImplementation =
            unsafe method_getImplementation(updateAlphaMethod)
        let updateAlphaBlock:
            @convention(block) (AnyObject, NSIndexPath) -> Void = {
                object,
                indexPath in
                let implementation = unsafe unsafeBitCast(
                    originalUpdateAlphaImplementation,
                    to: UpdateItemContentAlphaImplementation.self
                )
                implementation(object, updateAlphaSelector, indexPath)
                if #available(iOS 26.0, *) {
                    restoreItemContentAlpha(
                        at: indexPath as IndexPath,
                        in: object
                    )
                }
            }
        let updateAlphaOverride = unsafe imp_implementationWithBlock(
            updateAlphaBlock
        )

        let originalGestureIndexPathImplementation =
            unsafe method_getImplementation(gestureIndexPathMethod)
        let gestureIndexPathBlock:
            @convention(block) (
                AnyObject,
                UIGestureRecognizer
            ) -> NSIndexPath? = {
                object,
                gestureRecognizer in
                let implementation = unsafe unsafeBitCast(
                    originalGestureIndexPathImplementation,
                    to: GestureIndexPathImplementation.self
                )
                if let originalIndexPath = implementation(
                    object,
                    gestureIndexPathSelector,
                    gestureRecognizer
                ) {
                    return originalIndexPath
                }
                guard let floatingTabBar = object as? UIView,
                      let collectionView = collectionView(
                        in: floatingTabBar
                      ),
                      let indexPath = visibleItemIndexPath(
                        for: gestureRecognizer,
                        in: collectionView,
                        within: floatingTabBar
                      ) else {
                    return nil
                }
                return indexPath as NSIndexPath
            }
        let gestureIndexPathOverride = unsafe imp_implementationWithBlock(
            gestureIndexPathBlock
        )

        let originalScrollViewWillEndDraggingImplementation =
            unsafe method_getImplementation(
                scrollViewWillEndDraggingMethod
            )
        let scrollViewWillEndDraggingBlock:
            @convention(block) (
                AnyObject,
                UIScrollView,
                CGPoint,
                UnsafeMutablePointer<CGPoint>
            ) -> Void = {
                object,
                scrollView,
                velocity,
                targetContentOffset in
                let implementation = unsafe unsafeBitCast(
                    originalScrollViewWillEndDraggingImplementation,
                    to: ScrollViewWillEndDraggingImplementation.self
                )
                implementation(
                    object,
                    scrollViewWillEndDraggingSelector,
                    scrollView,
                    velocity,
                    targetContentOffset
                )
                alignDecelerationTarget(
                    targetContentOffset,
                    for: scrollView,
                    in: object
                )
            }
        let scrollViewWillEndDraggingOverride = unsafe imp_implementationWithBlock(
            scrollViewWillEndDraggingBlock
        )

        guard let subclass = unsafe objc_allocateClassPair(
            baseClass,
            expandedFloatingTabBarClassName,
            0
        ) else {
            unsafe imp_removeBlock(maximumSizeOverride)
            unsafe imp_removeBlock(layoutOverride)
            unsafe imp_removeBlock(updateAlphaOverride)
            unsafe imp_removeBlock(gestureIndexPathOverride)
            unsafe imp_removeBlock(scrollViewWillEndDraggingOverride)
            scrollableTabBarLogger.error(
                "UIKit's floating-tab pagination subclass could not be allocated."
            )
            return nil
        }
        guard unsafe class_addMethod(
            subclass,
            maximumSizeSelector,
            maximumSizeOverride,
            method_getTypeEncoding(maximumSizeMethod)
        ),
              unsafe class_addMethod(
                subclass,
                layoutSelector,
                layoutOverride,
                method_getTypeEncoding(layoutMethod)
              ),
              unsafe class_addMethod(
                subclass,
                updateAlphaSelector,
                updateAlphaOverride,
                method_getTypeEncoding(updateAlphaMethod)
              ),
              unsafe class_addMethod(
                subclass,
                gestureIndexPathSelector,
                gestureIndexPathOverride,
                method_getTypeEncoding(gestureIndexPathMethod)
              ),
              unsafe class_addMethod(
                subclass,
                scrollViewWillEndDraggingSelector,
                scrollViewWillEndDraggingOverride,
                method_getTypeEncoding(scrollViewWillEndDraggingMethod)
              ) else {
            unsafe imp_removeBlock(maximumSizeOverride)
            unsafe imp_removeBlock(layoutOverride)
            unsafe imp_removeBlock(updateAlphaOverride)
            unsafe imp_removeBlock(gestureIndexPathOverride)
            unsafe imp_removeBlock(scrollViewWillEndDraggingOverride)
            objc_disposeClassPair(subclass)
            scrollableTabBarLogger.error(
                "UIKit's floating-tab overrides could not be installed."
            )
            return nil
        }
        objc_registerClassPair(subclass)
        return subclass as? UIView.Type
    }

    private static func makeExpandedCollectionViewClass(
        baseClass: AnyClass
    ) -> AnyClass? {
        if let existingClass = NSClassFromString(
            expandedCollectionViewClassName
        ) {
            guard class_getSuperclass(existingClass) === baseClass else {
                scrollableTabBarLogger.fault(
                    "The ScrollableTabBar collection runtime class has an unexpected superclass."
                )
                return nil
            }
            return existingClass
        }

        let viewportWidthSelector =
            PrivateUIKitRuntimeNames.pageViewportWidthSelector
        let contentOffsetSelector =
            PrivateUIKitRuntimeNames.contentOffsetForPageSelector
        let pageProgressSelector =
            PrivateUIKitRuntimeNames.pageProgressForContentOffsetSelector
        let setFrameSelector = #selector(setter: UIView.frame)
        let setContentInsetSelector = #selector(
            setter: UIScrollView.contentInset
        )
        guard let viewportWidthMethod = unsafe verifiedMethod(
            on: baseClass,
            selector: viewportWidthSelector,
            typeEncoding: expectedPageViewportWidthTypeEncoding
        ),
              let contentOffsetMethod = unsafe verifiedMethod(
                on: baseClass,
                selector: contentOffsetSelector,
                typeEncoding: expectedContentOffsetForPageTypeEncoding
              ),
              let pageProgressMethod = unsafe verifiedMethod(
                on: baseClass,
                selector: pageProgressSelector,
                typeEncoding: expectedPageProgressForContentOffsetTypeEncoding
              ),
              let setFrameMethod = unsafe verifiedMethod(
                on: baseClass,
                selector: setFrameSelector,
                typeEncoding: expectedSetFrameTypeEncoding
              ),
              let setContentInsetMethod = unsafe verifiedMethod(
                on: baseClass,
                selector: setContentInsetSelector,
                typeEncoding: expectedSetContentInsetTypeEncoding
              ),
              unsafe verifiedMethod(
                on: baseClass,
                selector: PrivateUIKitRuntimeNames.currentPageSelector,
                typeEncoding: expectedCurrentPageTypeEncoding
              ) != nil,
              verifiedBackgroundInsetsMethod() else {
            return nil
        }

        let originalViewportWidthImplementation =
            unsafe method_getImplementation(viewportWidthMethod)
        let viewportWidthBlock:
            @convention(block) (AnyObject, CGFloat) -> CGFloat = {
                object,
                pageProgress in
                let implementation = unsafe unsafeBitCast(
                    originalViewportWidthImplementation,
                    to: PageViewportWidthImplementation.self
                )
                let originalWidth = implementation(
                    object,
                    viewportWidthSelector,
                    pageProgress
                )
                guard let collectionView = object as? UICollectionView,
                      let expandedWidth = pageViewportWidth(
                        for: collectionView,
                        pageProgress: pageProgress
                      ),
                      expandedWidth >= originalWidth else {
                    return originalWidth
                }
                return expandedWidth
            }
        let viewportWidthOverride = unsafe imp_implementationWithBlock(
            viewportWidthBlock
        )

        let originalContentOffsetImplementation =
            unsafe method_getImplementation(contentOffsetMethod)
        let contentOffsetBlock:
            @convention(block) (AnyObject, Int) -> CGPoint = {
                object,
                page in
                let implementation = unsafe unsafeBitCast(
                    originalContentOffsetImplementation,
                    to: ContentOffsetForPageImplementation.self
                )
                let originalOffset = implementation(
                    object,
                    contentOffsetSelector,
                    page
                )
                guard let collectionView = object as? UICollectionView else {
                    return originalOffset
                }
                // Keep this mapping and pageProgressForContentOffset: as an
                // inverse pair. Extending contentInset to preserve UIKit's
                // original last target exposes that extension as empty content.
                return clampedContentOffset(
                    originalOffset,
                    forPage: page,
                    in: collectionView,
                    originalContentOffsetImplementation:
                        originalContentOffsetImplementation,
                    contentOffsetSelector: contentOffsetSelector
                )
            }
        let contentOffsetOverride = unsafe imp_implementationWithBlock(
            contentOffsetBlock
        )

        let originalPageProgressImplementation =
            unsafe method_getImplementation(pageProgressMethod)
        let pageProgressBlock:
            @convention(block) (
                AnyObject,
                CGPoint,
                Bool
            ) -> CGFloat = {
                object,
                contentOffset,
                clamped in
                guard let collectionView = object as? UICollectionView,
                      let progress = unsafe pageProgress(
                        for: contentOffset,
                        in: collectionView,
                        originalContentOffsetImplementation:
                            originalContentOffsetImplementation,
                        contentOffsetSelector: contentOffsetSelector,
                        clamped: clamped
                      ) else {
                    let implementation = unsafe unsafeBitCast(
                        originalPageProgressImplementation,
                        to: PageProgressForContentOffsetImplementation.self
                    )
                    return implementation(
                        object,
                        pageProgressSelector,
                        contentOffset,
                        clamped
                    )
                }
                return progress
            }
        let pageProgressOverride = unsafe imp_implementationWithBlock(
            pageProgressBlock
        )

        let originalSetFrameImplementation = unsafe method_getImplementation(
            setFrameMethod
        )
        let setFrameBlock:
            @convention(block) (AnyObject, CGRect) -> Void = {
                object,
                proposedFrame in
                let implementation = unsafe unsafeBitCast(
                    originalSetFrameImplementation,
                    to: SetFrameImplementation.self
                )
                guard let collectionView = object as? UICollectionView,
                      collectionView.responds(
                        to: PrivateUIKitRuntimeNames.currentPageSelector
                      ) else {
                    implementation(object, setFrameSelector, proposedFrame)
                    return
                }

                let currentPage = unsafe unsafeBitCast(
                    collectionView.method(
                        for: PrivateUIKitRuntimeNames.currentPageSelector
                    ),
                    to: CurrentPageImplementation.self
                )(
                    collectionView,
                    PrivateUIKitRuntimeNames.currentPageSelector
                )
                guard currentPage.isFinite,
                      let viewportWidth = pageViewportWidth(
                        for: collectionView,
                        pageProgress: currentPage
                      ) else {
                    implementation(object, setFrameSelector, proposedFrame)
                    return
                }

                // _UIFloatingTabBar proposes its paginated viewport during
                // layout. Applying that transient width makes UIScrollView
                // clamp an active rubber-band offset before a later layout
                // pass can expand the viewport again. Preserve UIKit's origin,
                // height, and any wider native stretch while owning the minimum
                // expanded width at the frame-mutation boundary.
                var frame = proposedFrame
                frame.size.width = max(proposedFrame.width, viewportWidth)
                let currentFrame = collectionView.frame
                let tolerance = 1 / max(
                    collectionView.traitCollection.displayScale,
                    1
                )
                let hasEffectiveFrameChange =
                    abs(frame.origin.x - currentFrame.origin.x) > tolerance
                    || abs(frame.origin.y - currentFrame.origin.y) > tolerance
                    || abs(frame.size.width - currentFrame.size.width) > tolerance
                    || abs(frame.size.height - currentFrame.size.height) > tolerance
                if !hasEffectiveFrameChange,
                   collectionView.isTracking
                    || collectionView.isDragging
                    || collectionView.isDecelerating,
                   let naturalRange = naturalHorizontalScrollRange(
                       in: collectionView,
                       viewportWidth: collectionView.bounds.width
                   ),
                   collectionView.contentOffset.x
                    < naturalRange.lowerBound - tolerance
                    || collectionView.contentOffset.x
                        > naturalRange.upperBound + tolerance {
                    // UIScrollView revalidates contentOffset in setFrame: even
                    // when the effective frame is unchanged. During trailing
                    // rubber-banding that turns a no-op layout pass into an
                    // immediate clamp back to the physical maximum, including
                    // while UIKit is animating the release spring.
                    return
                }
                implementation(object, setFrameSelector, frame)
            }
        let setFrameOverride = unsafe imp_implementationWithBlock(
            setFrameBlock
        )

        let originalSetContentInsetImplementation =
            unsafe method_getImplementation(setContentInsetMethod)
        let setContentInsetBlock:
            @convention(block) (AnyObject, UIEdgeInsets) -> Void = {
                object,
                proposedContentInset in
                let implementation = unsafe unsafeBitCast(
                    originalSetContentInsetImplementation,
                    to: SetContentInsetImplementation.self
                )
                // The factory requires zero explicit content inset, while
                // system safe-area adjustments remain in adjustedContentInset.
                // Our page mapping owns the horizontal range, so any horizontal
                // inset later proposed by the paginated layout would create a
                // second range regardless of layout direction.
                var contentInset = proposedContentInset
                contentInset.left = 0
                contentInset.right = 0
                implementation(
                    object,
                    setContentInsetSelector,
                    contentInset
                )
            }
        let setContentInsetOverride = unsafe imp_implementationWithBlock(
            setContentInsetBlock
        )

        guard let subclass = unsafe objc_allocateClassPair(
            baseClass,
            expandedCollectionViewClassName,
            0
        ) else {
            unsafe imp_removeBlock(viewportWidthOverride)
            unsafe imp_removeBlock(contentOffsetOverride)
            unsafe imp_removeBlock(pageProgressOverride)
            unsafe imp_removeBlock(setFrameOverride)
            unsafe imp_removeBlock(setContentInsetOverride)
            return nil
        }
        guard unsafe class_addMethod(
            subclass,
            viewportWidthSelector,
            viewportWidthOverride,
            method_getTypeEncoding(viewportWidthMethod)
        ),
              unsafe class_addMethod(
                subclass,
                contentOffsetSelector,
                contentOffsetOverride,
                method_getTypeEncoding(contentOffsetMethod)
              ),
              unsafe class_addMethod(
                subclass,
                pageProgressSelector,
                pageProgressOverride,
                method_getTypeEncoding(pageProgressMethod)
              ),
              unsafe class_addMethod(
                subclass,
                setFrameSelector,
                setFrameOverride,
                method_getTypeEncoding(setFrameMethod)
              ),
              unsafe class_addMethod(
                subclass,
                setContentInsetSelector,
                setContentInsetOverride,
                method_getTypeEncoding(setContentInsetMethod)
              ) else {
            unsafe imp_removeBlock(viewportWidthOverride)
            unsafe imp_removeBlock(contentOffsetOverride)
            unsafe imp_removeBlock(pageProgressOverride)
            unsafe imp_removeBlock(setFrameOverride)
            unsafe imp_removeBlock(setContentInsetOverride)
            objc_disposeClassPair(subclass)
            return nil
        }
        objc_registerClassPair(subclass)
        return subclass
    }

    @available(iOS 26.0, *)
    private static func configureEdgeEffects(
        on collectionView: UICollectionView,
        in floatingTabBar: UIView
    ) -> Bool {
        guard let leftArrowButton = view(
            from: floatingTabBar,
            selector: PrivateUIKitRuntimeNames.leftArrowButtonSelector
        ),
              let rightArrowButton = view(
                from: floatingTabBar,
                selector: PrivateUIKitRuntimeNames.rightArrowButtonSelector
              ),
              unsafe verifiedMethod(
                on: type(of: leftArrowButton),
                selector:
                    PrivateUIKitRuntimeNames.pageButtonContentOpacitySelector,
                typeEncoding: expectedPageButtonContentOpacityTypeEncoding
              ) != nil,
              unsafe verifiedMethod(
                on: type(of: rightArrowButton),
                selector:
                    PrivateUIKitRuntimeNames.pageButtonContentOpacitySelector,
                typeEncoding: expectedPageButtonContentOpacityTypeEncoding
              ) != nil,
              unsafe verifiedMethod(
                on: type(of: leftArrowButton),
                selector: PrivateUIKitRuntimeNames.pageButtonButtonSelector,
                typeEncoding: expectedObjectGetterTypeEncoding
              ) != nil,
              unsafe verifiedMethod(
                on: type(of: rightArrowButton),
                selector: PrivateUIKitRuntimeNames.pageButtonButtonSelector,
                typeEncoding: expectedObjectGetterTypeEncoding
              ) != nil else {
            return false
        }

        configureEdgeElementContainer(
            on: leftArrowButton,
            edge: .left,
            for: collectionView
        )
        configureEdgeElementContainer(
            on: rightArrowButton,
            edge: .right,
            for: collectionView
        )

        let leftEdgeEffect = collectionView.leftEdgeEffect
        let rightEdgeEffect = collectionView.rightEdgeEffect
        let geometrySelector =
            PrivateUIKitRuntimeNames.edgeEffectGeometryViewWriteSelector
        guard let leftGeometryMethod = unsafe verifiedMethod(
            on: type(of: leftEdgeEffect),
            selector: geometrySelector,
            typeEncoding: expectedEdgeEffectGeometryViewSetterTypeEncoding
        ),
              let rightGeometryMethod = unsafe verifiedMethod(
                on: type(of: rightEdgeEffect),
                selector: geometrySelector,
                typeEncoding: expectedEdgeEffectGeometryViewSetterTypeEncoding
              ),
              hasVerifiedEdgeEffectActivationContract(
                on: collectionView
              ) else {
            return false
        }

        unsafe unsafeBitCast(
            method_getImplementation(leftGeometryMethod),
            to: EdgeEffectGeometryViewSetter.self
        )(
            leftEdgeEffect,
            geometrySelector,
            leftArrowButton
        )
        unsafe unsafeBitCast(
            method_getImplementation(rightGeometryMethod),
            to: EdgeEffectGeometryViewSetter.self
        )(
            rightEdgeEffect,
            geometrySelector,
            rightArrowButton
        )
        leftEdgeEffect.style = .soft
        rightEdgeEffect.style = .soft
        synchronizeEdgeEffectVisibility(in: floatingTabBar)
        // This floating hierarchy does not request pockets from the public
        // overlay interaction alone. Force initial creation, extend only the
        // effect capture beneath the sibling arrows, and anchor each pocket to
        // the corresponding physical edge.
        guard installExpandedEdgeGeometry(in: floatingTabBar),
              forceEdgeEffectPockets(in: floatingTabBar),
              updateEdgeEffects(in: floatingTabBar) else {
            return false
        }
        return true
    }

    @available(iOS 26.0, *)
    private static func configureEdgeElementContainer(
        on view: UIView,
        edge: UIRectEdge,
        for collectionView: UICollectionView
    ) {
        guard view.interactions.contains(where: {
            guard let interaction =
                $0 as? UIScrollEdgeElementContainerInteraction else {
                return false
            }
            return interaction.scrollView === collectionView
                && interaction.edge == edge
        }) == false else {
            return
        }

        let interaction = UIScrollEdgeElementContainerInteraction()
        interaction.scrollView = collectionView
        interaction.edge = edge
        view.addInteraction(interaction)
    }

    private static func synchronizeEdgeEffectVisibility(
        in object: AnyObject
    ) {
        guard #available(iOS 26.0, *),
              let floatingTabBar = object as? UIView,
              let collectionView = collectionView(in: floatingTabBar),
              let leftArrowButton = view(
                from: floatingTabBar,
                selector: PrivateUIKitRuntimeNames.leftArrowButtonSelector
              ),
              let rightArrowButton = view(
                from: floatingTabBar,
                selector: PrivateUIKitRuntimeNames.rightArrowButtonSelector
              ),
              let leftOpacity = pageButtonContentOpacity(
                of: leftArrowButton
              ),
              let rightOpacity = pageButtonContentOpacity(
                of: rightArrowButton
              ) else {
            return
        }

        collectionView.leftEdgeEffect.isHidden =
            leftOpacity <= minimumVisiblePageButtonOpacity
        collectionView.rightEdgeEffect.isHidden =
            rightOpacity <= minimumVisiblePageButtonOpacity
    }

    private static func hasVerifiedEdgeEffectActivationContract(
        on collectionView: UICollectionView
    ) -> Bool {
        guard let interaction = edgeEffectInteraction(
            in: collectionView
        ) else {
            return false
        }
        let interactionType: AnyClass = type(of: interaction)
        guard unsafe verifiedMethod(
            on: interactionType,
            selector: PrivateUIKitRuntimeNames.edgeEffectUpdateSelector,
            typeEncoding: expectedVoidMethodTypeEncoding
        ) != nil,
              unsafe verifiedMethod(
                on: interactionType,
                selector: PrivateUIKitRuntimeNames.forceEdgeEffectPocketSelector,
                typeEncoding: expectedForceEdgeEffectPocketTypeEncoding
              ) != nil,
              unsafe verifiedMethod(
                on: interactionType,
                selector: PrivateUIKitRuntimeNames.edgeEffectViewSelector,
                typeEncoding: expectedObjectGetterTypeEncoding
              ) != nil,
              unsafe verifiedMethod(
                on: interactionType,
                selector: PrivateUIKitRuntimeNames.edgeCaptureViewSelector,
                typeEncoding: expectedObjectGetterTypeEncoding
              ) != nil else {
            return false
        }
        return true
    }

    private static func edgeEffectInteraction(
        in collectionView: UICollectionView
    ) -> AnyObject? {
        let selector =
            PrivateUIKitRuntimeNames.edgeEffectViewInteractionSelector
        guard let getter = unsafe verifiedMethod(
            on: type(of: collectionView),
            selector: selector,
            typeEncoding: expectedObjectGetterTypeEncoding
        ) else {
            return nil
        }
        return unsafe unsafeBitCast(
            method_getImplementation(getter),
            to: ObjectGetterImplementation.self
        )(
            collectionView,
            selector
        )
    }

    @discardableResult
    private static func updateEdgeEffects(
        in object: AnyObject
    ) -> Bool {
        let updateSelector =
            PrivateUIKitRuntimeNames.edgeEffectUpdateSelector
        guard #available(iOS 26.0, *),
              let floatingTabBar = object as? UIView,
              let collectionView = collectionView(in: floatingTabBar),
              let interaction = edgeEffectInteraction(
                in: collectionView
              ),
              interaction.responds(to: updateSelector) else {
            return false
        }

        _ = unsafe interaction.perform(updateSelector)
        return true
    }

    private static func installExpandedEdgeGeometry(
        in object: AnyObject
    ) -> Bool {
        guard #available(iOS 26.0, *),
              let floatingTabBar = object as? UIView,
              let collectionView = collectionView(in: floatingTabBar),
              let interaction = edgeEffectInteraction(
                in: collectionView
              ),
              let effectView = view(
                from: interaction,
                selector: PrivateUIKitRuntimeNames.edgeEffectViewSelector
              ),
              let captureView = view(
                from: interaction,
                selector: PrivateUIKitRuntimeNames.edgeCaptureViewSelector
              ),
              effectView !== captureView else {
            return false
        }

        return installExpandedEdgeGeometryClass(
            on: effectView,
            className: expandedEdgeEffectViewClassName
        ) && installExpandedEdgeGeometryClass(
            on: captureView,
            className: expandedEdgeCaptureViewClassName
        )
    }

    private static func installExpandedEdgeGeometryClass(
        on view: UIView,
        className: String
    ) -> Bool {
        guard let currentClass = object_getClass(view) else {
            return false
        }
        if NSStringFromClass(currentClass) == className {
            return true
        }
        guard let geometryClass = makeExpandedEdgeGeometryClass(
            baseClass: currentClass,
            className: className
        ) else {
            return false
        }
        let previousClass: AnyClass? = object_setClass(
            view,
            geometryClass
        )
        return previousClass === currentClass
    }

    private static func makeExpandedEdgeGeometryClass(
        baseClass: AnyClass,
        className: String
    ) -> AnyClass? {
        if let existingClass = NSClassFromString(className) {
            guard class_getSuperclass(existingClass) === baseClass else {
                scrollableTabBarLogger.fault(
                    "The ScrollableTabBar edge geometry class has an unexpected superclass."
                )
                return nil
            }
            return existingClass
        }

        let setFrameSelector = #selector(setter: UIView.frame)
        guard let setFrameMethod = unsafe verifiedMethod(
            on: baseClass,
            selector: setFrameSelector,
            typeEncoding: expectedSetFrameTypeEncoding
        ) else {
            return nil
        }
        let originalSetFrameImplementation =
            unsafe method_getImplementation(setFrameMethod)
        let setFrameBlock:
            @convention(block) (AnyObject, CGRect) -> Void = {
                object,
                proposedFrame in
                let frame = if let view = object as? UIView {
                    expandedEdgeGeometryFrame(
                        proposedFrame,
                        for: view
                    ) ?? proposedFrame
                } else {
                    proposedFrame
                }
                let implementation = unsafe unsafeBitCast(
                    originalSetFrameImplementation,
                    to: SetFrameImplementation.self
                )
                implementation(object, setFrameSelector, frame)
            }
        let setFrameOverride = unsafe imp_implementationWithBlock(
            setFrameBlock
        )

        guard let subclass = unsafe objc_allocateClassPair(
            baseClass,
            className,
            0
        ) else {
            unsafe imp_removeBlock(setFrameOverride)
            return nil
        }
        guard unsafe class_addMethod(
            subclass,
            setFrameSelector,
            setFrameOverride,
            method_getTypeEncoding(setFrameMethod)
        ) else {
            unsafe imp_removeBlock(setFrameOverride)
            objc_disposeClassPair(subclass)
            return nil
        }
        objc_registerClassPair(subclass)
        return subclass
    }

    private static func expandedEdgeGeometryFrame(
        _ proposedFrame: CGRect,
        for view: UIView
    ) -> CGRect? {
        guard let container = view.superview,
              let collectionView = ancestorCollectionView(of: view),
              let floatingTabBar = floatingTabBar(
                for: collectionView
              ) else {
            return nil
        }

        let floatingFrame = floatingTabBar.convert(
            floatingTabBar.bounds,
            to: container
        )
        guard floatingFrame.minX.isFinite,
              floatingFrame.width.isFinite,
              floatingFrame.width > 0 else {
            return nil
        }

        // The page buttons are siblings outside the native collection frame.
        // Extend only the effect capture beneath those overlays; expanding the
        // collection itself changes item exposure, paging, and accessibility.
        var frame = proposedFrame
        frame.origin.x = floatingFrame.minX
        frame.size.width = floatingFrame.width
        return frame
    }

    private static func forceEdgeEffectPockets(
        in object: AnyObject
    ) -> Bool {
        let forceSelector =
            PrivateUIKitRuntimeNames.forceEdgeEffectPocketSelector
        guard #available(iOS 26.0, *),
              let floatingTabBar = object as? UIView,
              let collectionView = collectionView(in: floatingTabBar),
              let interaction = edgeEffectInteraction(
                in: collectionView
              ),
              interaction.responds(to: forceSelector) else {
            return false
        }

        let implementation = unsafe unsafeBitCast(
            interaction.method(for: forceSelector),
            to: ForceEdgeEffectPocketImplementation.self
        )
        for edge: UIRectEdge in [.left, .right] {
            guard let pocket = implementation(
                interaction,
                forceSelector,
                edge.rawValue
            ) as? UIView,
                  installAlignedEdgeEffectPocketClass(
                    on: pocket,
                    edge: edge
                  ) else {
                return false
            }
        }
        return true
    }

    private static func installAlignedEdgeEffectPocketClass(
        on pocket: UIView,
        edge: UIRectEdge
    ) -> Bool {
        let className = alignedEdgeEffectPocketClassName(for: edge)
        guard let currentClass = object_getClass(pocket) else {
            return false
        }
        if NSStringFromClass(currentClass) == className {
            return true
        }
        guard let pocketClass = makeAlignedEdgeEffectPocketClass(
            baseClass: currentClass,
            edge: edge
        ) else {
            return false
        }
        let previousClass: AnyClass? = object_setClass(
            pocket,
            pocketClass
        )
        return previousClass === currentClass
    }

    private static func makeAlignedEdgeEffectPocketClass(
        baseClass: AnyClass,
        edge: UIRectEdge
    ) -> AnyClass? {
        let className = alignedEdgeEffectPocketClassName(for: edge)
        if let existingClass = NSClassFromString(className) {
            guard class_getSuperclass(existingClass) === baseClass else {
                scrollableTabBarLogger.fault(
                    "The ScrollableTabBar edge-effect pocket class has an unexpected superclass."
                )
                return nil
            }
            return existingClass
        }

        let setFrameSelector = #selector(setter: UIView.frame)
        guard let setFrameMethod = unsafe verifiedMethod(
            on: baseClass,
            selector: setFrameSelector,
            typeEncoding: expectedSetFrameTypeEncoding
        ) else {
            return nil
        }
        let originalSetFrameImplementation =
            unsafe method_getImplementation(setFrameMethod)
        let setFrameBlock:
            @convention(block) (AnyObject, CGRect) -> Void = {
                object,
                proposedFrame in
                let frame = if let pocket = object as? UIView {
                    alignedEdgeEffectPocketFrame(
                        proposedFrame,
                        for: pocket,
                        edge: edge
                    ) ?? proposedFrame
                } else {
                    proposedFrame
                }
                let implementation = unsafe unsafeBitCast(
                    originalSetFrameImplementation,
                    to: SetFrameImplementation.self
                )
                implementation(object, setFrameSelector, frame)
            }
        let setFrameOverride = unsafe imp_implementationWithBlock(
            setFrameBlock
        )

        guard let subclass = unsafe objc_allocateClassPair(
            baseClass,
            className,
            0
        ) else {
            unsafe imp_removeBlock(setFrameOverride)
            return nil
        }
        guard unsafe class_addMethod(
            subclass,
            setFrameSelector,
            setFrameOverride,
            method_getTypeEncoding(setFrameMethod)
        ) else {
            unsafe imp_removeBlock(setFrameOverride)
            objc_disposeClassPair(subclass)
            return nil
        }
        objc_registerClassPair(subclass)
        return subclass
    }

    private static func alignedEdgeEffectPocketClassName(
        for edge: UIRectEdge
    ) -> String {
        edge == .left
            ? leftAlignedEdgeEffectPocketClassName
            : rightAlignedEdgeEffectPocketClassName
    }

    private static func alignedEdgeEffectPocketFrame(
        _ proposedFrame: CGRect,
        for pocket: UIView,
        edge: UIRectEdge
    ) -> CGRect? {
        guard proposedFrame.width.isFinite,
              proposedFrame.width > 0,
              proposedFrame.height.isFinite,
              proposedFrame.height > 0,
              let pocketContainer = pocket.superview,
              let collectionView = ancestorCollectionView(of: pocket),
              let floatingTabBar = floatingTabBar(
                for: collectionView
              ),
              let pageButton = view(
                from: floatingTabBar,
                selector: edge == .left
                    ? PrivateUIKitRuntimeNames.leftArrowButtonSelector
                    : PrivateUIKitRuntimeNames.rightArrowButtonSelector
              ),
              let button = view(
                from: pageButton,
                selector: PrivateUIKitRuntimeNames.pageButtonButtonSelector
              ) else {
            return nil
        }

        let buttonFrame = button.convert(
            button.bounds,
            to: pocketContainer
        )
        guard buttonFrame.minX.isFinite,
              buttonFrame.maxX.isFinite,
              buttonFrame.width.isFinite,
              buttonFrame.width > 0 else {
            return nil
        }

        // The native collection viewport ends before its sibling page button.
        // Do not adopt iOS 27's wider automatic field in this compact bar: one
        // bar radius beyond the native arrow preserves the iOS 26 falloff
        // without obscuring the adjacent item. UIKit still owns blur strength
        // and vertical geometry while scrolling.
        var frame = proposedFrame
        frame.size.width = buttonFrame.width + proposedFrame.height / 2
        frame.origin.x = edge == .left
            ? buttonFrame.minX
            : buttonFrame.maxX - frame.width
        return frame
    }

    private static func ancestorCollectionView(
        of view: UIView
    ) -> UICollectionView? {
        var ancestor = view.superview
        while let current = ancestor {
            if let collectionView = current as? UICollectionView {
                return collectionView
            }
            ancestor = current.superview
        }
        return nil
    }

    private static func floatingTabBar(
        for collectionView: UICollectionView
    ) -> UIView? {
        let layout = collectionView.collectionViewLayout
        guard layout.responds(
            to: PrivateUIKitRuntimeNames.floatingTabBarSelector
        ) else {
            return nil
        }
        return unsafe layout
            .perform(PrivateUIKitRuntimeNames.floatingTabBarSelector)?
            .takeUnretainedValue() as? UIView
    }

    private static func pageButtonContentOpacity(
        of pageButton: UIView
    ) -> CGFloat? {
        let selector =
            PrivateUIKitRuntimeNames.pageButtonContentOpacitySelector
        guard pageButton.responds(to: selector) else {
            return nil
        }
        let implementation = unsafe unsafeBitCast(
            pageButton.method(for: selector),
            to: PageButtonContentOpacityImplementation.self
        )
        let opacity = implementation(pageButton, selector)
        guard opacity.isFinite else {
            return nil
        }
        return opacity
    }

    private static func view(
        from object: AnyObject,
        selector: Selector
    ) -> UIView? {
        guard object.responds(to: selector) else {
            return nil
        }
        return unsafe object.perform(selector)?
            .takeUnretainedValue() as? UIView
    }

    private static func visibleItemIndexPath(
        at point: CGPoint,
        in collectionView: UICollectionView
    ) -> IndexPath? {
        collectionView.indexPathForItem(at: point)
    }

    private static func visibleItemIndexPath(
        for gestureRecognizer: UIGestureRecognizer,
        in collectionView: UICollectionView,
        within floatingTabBar: UIView
    ) -> IndexPath? {
        let locationInFloatingTabBar = gestureRecognizer.location(
            in: floatingTabBar
        )
        guard floatingTabBar.bounds.contains(locationInFloatingTabBar),
              isInsideVisiblePageButton(
                gestureRecognizer,
                in: floatingTabBar
              ) == false else {
            return nil
        }

        // UIKit intentionally draws cells beyond the collection bounds.
        // Use the floating bar and page-button hit regions as the interaction
        // boundary so every rendered sliver remains selectable.
        let location = gestureRecognizer.location(in: collectionView)
        return visibleItemIndexPath(
            at: CGPoint(
                x: location.x,
                y: collectionView.bounds.midY
            ),
            in: collectionView
        )
    }

    private static func isInsideVisiblePageButton(
        _ gestureRecognizer: UIGestureRecognizer,
        in floatingTabBar: UIView
    ) -> Bool {
        let selectors = [
            PrivateUIKitRuntimeNames.leftArrowButtonSelector,
            PrivateUIKitRuntimeNames.rightArrowButtonSelector,
        ]
        return selectors.contains { selector in
            guard let pageButton = view(
                from: floatingTabBar,
                selector: selector
            ),
                  let opacity = pageButtonContentOpacity(
                    of: pageButton
                  ),
                  opacity > minimumVisiblePageButtonOpacity else {
                return false
            }
            let location = gestureRecognizer.location(in: pageButton)
            return pageButton.bounds.contains(location)
        }
    }

    private static func restoreItemContentAlpha(
        at indexPath: IndexPath,
        in object: AnyObject
    ) {
        guard let floatingTabBar = object as? UIView,
              let collectionView = collectionView(in: floatingTabBar),
              let cell = collectionView.cellForItem(at: indexPath) else {
            return
        }
        cell.contentView.alpha = 1
    }

    private static func collectionView(
        in floatingTabBar: UIView
    ) -> UICollectionView? {
        guard floatingTabBar.responds(
            to: PrivateUIKitRuntimeNames.itemsViewSelector
        ) else {
            return nil
        }
        return unsafe floatingTabBar
            .perform(PrivateUIKitRuntimeNames.itemsViewSelector)?
            .takeUnretainedValue() as? UICollectionView
    }

    private static func originalContentOffsetImplementation(
        for collectionView: UICollectionView
    ) -> IMP? {
        guard let runtimeClass = object_getClass(collectionView),
              let baseClass = class_getSuperclass(runtimeClass),
              let method = unsafe verifiedMethod(
                on: baseClass,
                selector:
                    PrivateUIKitRuntimeNames.contentOffsetForPageSelector,
                typeEncoding: expectedContentOffsetForPageTypeEncoding
              ) else {
            return nil
        }
        return unsafe method_getImplementation(method)
    }

    static func semanticPageModelWidth(
        firstPageOrigin: CGFloat,
        firstPageWidth: CGFloat,
        finalPageOrigin: CGFloat,
        finalPageWidth: CGFloat
    ) -> CGFloat? {
        let dimensions = [
            firstPageOrigin,
            firstPageWidth,
            finalPageOrigin,
            finalPageWidth,
        ]
        guard dimensions.allSatisfy(\.isFinite),
              firstPageWidth >= 0,
              finalPageWidth >= 0 else {
            return nil
        }

        let lowerBound = min(firstPageOrigin, finalPageOrigin)
        let upperBound = max(
            firstPageOrigin + firstPageWidth,
            finalPageOrigin + finalPageWidth
        )
        let width = upperBound - lowerBound
        guard width.isFinite, width >= 0 else {
            return nil
        }
        return width
    }

    private static func semanticContentWidth(
        in collectionView: UICollectionView,
        originalContentOffsetImplementation: IMP,
        contentOffsetSelector: Selector
    ) -> CGFloat? {
        guard collectionView.responds(
            to: PrivateUIKitRuntimeNames.pagesSelector
        ),
              let pages = unsafe collectionView
                .perform(PrivateUIKitRuntimeNames.pagesSelector)?
                .takeUnretainedValue() as? NSArray,
              pages.count > 0 else {
            return nil
        }

        let originalContentOffset = unsafe unsafeBitCast(
            originalContentOffsetImplementation,
            to: ContentOffsetForPageImplementation.self
        )
        // UICollectionView materializes its content extent lazily. UIKit's
        // page model already owns the complete boundary-page geometry.
        let firstPageIndex = 0
        let finalPageIndex = pages.count - 1
        let pageGeometry: (Int) -> (origin: CGFloat, width: CGFloat)? = {
            pageIndex in
            let page = pages[pageIndex] as AnyObject
            guard let widthMethod = unsafe verifiedMethod(
                on: type(of: page),
                selector: PrivateUIKitRuntimeNames.pageWidthSelector,
                typeEncoding: expectedPageWidthTypeEncoding
            ) else {
                return nil
            }
            let width = unsafe unsafeBitCast(
                method_getImplementation(widthMethod),
                to: PageWidthImplementation.self
            )(
                page,
                PrivateUIKitRuntimeNames.pageWidthSelector
            )
            let origin = originalContentOffset(
                collectionView,
                contentOffsetSelector,
                pageIndex
            ).x
            guard origin.isFinite,
                  width.isFinite,
                  width >= 0 else {
                return nil
            }
            return (origin, width)
        }
        guard let firstPage = pageGeometry(firstPageIndex),
              let finalPage = pageGeometry(finalPageIndex),
              let semanticWidth = semanticPageModelWidth(
                firstPageOrigin: firstPage.origin,
                firstPageWidth: firstPage.width,
                finalPageOrigin: finalPage.origin,
                finalPageWidth: finalPage.width
              ) else {
            return nil
        }
        return max(collectionView.contentSize.width, semanticWidth)
    }

    private static func alignDecelerationTarget(
        _ targetContentOffset: UnsafeMutablePointer<CGPoint>,
        for scrollView: UIScrollView,
        in object: AnyObject
    ) {
        guard let floatingTabBar = object as? UIView,
              let collectionView = collectionView(in: floatingTabBar),
              collectionView === scrollView,
              collectionView.responds(
                to: PrivateUIKitRuntimeNames.pagesSelector
              ),
              let pages = unsafe collectionView
                .perform(PrivateUIKitRuntimeNames.pagesSelector)?
                .takeUnretainedValue() as? NSArray,
              pages.count > 0,
              let originalContentOffsetImplementation =
                originalContentOffsetImplementation(
                    for: collectionView
                ) else {
            return
        }

        // Paging is disabled for continuous dragging, so UIKit leaves the
        // predicted endpoint based on the viewport that is visible at release.
        // Clamp only predictions beyond the semantic first or final edge now;
        // otherwise releasing the trailing arrow reservation causes a second
        // correction in a later layout pass.
        targetContentOffset.pointee = clampedContentOffset(
            targetContentOffset.pointee,
            forPage: pages.count - 1,
            in: collectionView,
            originalContentOffsetImplementation:
                originalContentOffsetImplementation,
            contentOffsetSelector:
                PrivateUIKitRuntimeNames.contentOffsetForPageSelector
        )
    }

    private static func clampedContentOffset(
        _ contentOffset: CGPoint,
        forPage page: Int,
        in collectionView: UICollectionView,
        originalContentOffsetImplementation: IMP,
        contentOffsetSelector: Selector
    ) -> CGPoint {
        let viewportWidth = pageViewportWidth(
            for: collectionView,
            pageProgress: CGFloat(page)
        ) ?? collectionView.bounds.width
        let contentWidth = semanticContentWidth(
            in: collectionView,
            originalContentOffsetImplementation:
                originalContentOffsetImplementation,
            contentOffsetSelector: contentOffsetSelector
        ) ?? collectionView.contentSize.width
        guard let range = naturalHorizontalScrollRange(
            in: collectionView,
            viewportWidth: viewportWidth,
            contentWidth: contentWidth
        ) else {
            return contentOffset
        }
        return CGPoint(
            x: min(max(contentOffset.x, range.lowerBound), range.upperBound),
            y: contentOffset.y
        )
    }

    private static func pageProgress(
        for contentOffset: CGPoint,
        in collectionView: UICollectionView,
        originalContentOffsetImplementation: IMP,
        contentOffsetSelector: Selector,
        clamped: Bool
    ) -> CGFloat? {
        guard collectionView.responds(
            to: PrivateUIKitRuntimeNames.pagesSelector
        ),
              let pages = unsafe collectionView
                .perform(PrivateUIKitRuntimeNames.pagesSelector)?
                .takeUnretainedValue() as? NSArray,
              pages.count > 0 else {
            return nil
        }

        let originalContentOffset = unsafe unsafeBitCast(
            originalContentOffsetImplementation,
            to: ContentOffsetForPageImplementation.self
        )
        let targets = (0..<pages.count).map { page in
            let originalTarget = originalContentOffset(
                collectionView,
                contentOffsetSelector,
                page
            )
            return clampedContentOffset(
                originalTarget,
                forPage: page,
                in: collectionView,
                originalContentOffsetImplementation:
                    originalContentOffsetImplementation,
                contentOffsetSelector: contentOffsetSelector
            ).x
        }
        guard targets.count > 1 else {
            return 0
        }

        let increasing = targets[0] < targets[targets.count - 1]
        guard zip(targets, targets.dropFirst()).allSatisfy({
            increasing ? $0.0 < $0.1 : $0.0 > $0.1
        }) else {
            return nil
        }

        let lastIndex = CGFloat(targets.count - 1)
        let isBeforeFirstTarget = increasing
            ? contentOffset.x <= targets[0]
            : contentOffset.x >= targets[0]
        let progress: CGFloat
        if isBeforeFirstTarget {
            progress = 0
        } else if let segment = targets.indices.dropLast().first(
            where: {
                increasing
                    ? contentOffset.x <= targets[$0 + 1]
                    : contentOffset.x >= targets[$0 + 1]
            }
        ) {
            let lowerTarget = targets[segment]
            let upperTarget = targets[segment + 1]
            progress = CGFloat(segment)
                + (contentOffset.x - lowerTarget)
                    / (upperTarget - lowerTarget)
        } else {
            let lastTarget = targets[targets.count - 1]
            let overshoot = increasing
                ? contentOffset.x - lastTarget
                : lastTarget - contentOffset.x
            let trailingDistance = collectionView.bounds.width
            guard trailingDistance.isFinite,
                  trailingDistance > 0 else {
                return nil
            }
            progress = lastIndex + min(
                max(overshoot / trailingDistance, 0),
                1
            )
        }

        guard progress.isFinite else {
            return nil
        }
        if clamped {
            return min(max(progress, 0), lastIndex)
        }
        return progress
    }

    private static func naturalHorizontalScrollRange(
        in collectionView: UICollectionView,
        viewportWidth: CGFloat,
        contentWidth: CGFloat? = nil
    ) -> ClosedRange<CGFloat>? {
        let systemLeftInset =
            collectionView.adjustedContentInset.left
            - collectionView.contentInset.left
        let systemRightInset =
            collectionView.adjustedContentInset.right
            - collectionView.contentInset.right
        let resolvedContentWidth =
            contentWidth ?? collectionView.contentSize.width
        let dimensions = [
            resolvedContentWidth,
            viewportWidth,
            systemLeftInset,
            systemRightInset,
        ]
        guard dimensions.allSatisfy(\.isFinite),
              dimensions[0] >= 0,
              dimensions[1] > 0 else {
            return nil
        }

        let minimumOffset = -systemLeftInset
        let maximumOffset = max(
            resolvedContentWidth
                - viewportWidth
                + systemRightInset,
            minimumOffset
        )
        return minimumOffset...maximumOffset
    }

    private static func pageViewportWidth(
        for collectionView: UICollectionView,
        pageProgress: CGFloat
    ) -> CGFloat? {
        guard pageProgress.isFinite,
              collectionView.responds(
                to: PrivateUIKitRuntimeNames.pagesSelector
              ),
              let pages = unsafe collectionView
                .perform(PrivateUIKitRuntimeNames.pagesSelector)?
                .takeUnretainedValue() as? NSArray,
              pages.count > 0 else {
            return nil
        }

        let layout = collectionView.collectionViewLayout
        guard layout.responds(
            to: PrivateUIKitRuntimeNames.floatingTabBarSelector
        ),
              let floatingTabBar = unsafe layout
                .perform(PrivateUIKitRuntimeNames.floatingTabBarSelector)?
                .takeUnretainedValue() as? UIView,
              floatingTabBar.responds(
                to: PrivateUIKitRuntimeNames.leftArrowButtonSelector
              ),
              floatingTabBar.responds(
                to: PrivateUIKitRuntimeNames.rightArrowButtonSelector
              ),
              floatingTabBar.responds(
                to: PrivateUIKitRuntimeNames.currentPlatformMetricsSelector
              ),
              let leftArrowButton = unsafe floatingTabBar
                .perform(PrivateUIKitRuntimeNames.leftArrowButtonSelector)?
                .takeUnretainedValue() as? UIView,
              let rightArrowButton = unsafe floatingTabBar
                .perform(PrivateUIKitRuntimeNames.rightArrowButtonSelector)?
                .takeUnretainedValue() as? UIView,
              let metrics = unsafe floatingTabBar
                .perform(PrivateUIKitRuntimeNames.currentPlatformMetricsSelector)?
                .takeUnretainedValue() as? NSObject,
              metrics.responds(
                to: PrivateUIKitRuntimeNames.backgroundInsetsSelector
              ) else {
            return nil
        }

        let backgroundInsetsImplementation = unsafe unsafeBitCast(
            metrics.method(
                for: PrivateUIKitRuntimeNames.backgroundInsetsSelector
            ),
            to: BackgroundInsetsImplementation.self
        )
        let backgroundInsets = backgroundInsetsImplementation(
            metrics,
            PrivateUIKitRuntimeNames.backgroundInsetsSelector
        )
        let outerWidth = floatingTabBar.bounds.width
        let leftArrowWidth = leftArrowButton.bounds.width
        let rightArrowWidth = rightArrowButton.bounds.width
        let dimensions = [
            outerWidth,
            leftArrowWidth,
            rightArrowWidth,
            backgroundInsets.left,
            backgroundInsets.right,
        ]
        guard dimensions.allSatisfy(\.isFinite),
              dimensions.allSatisfy({ $0 >= 0 }),
              outerWidth > 0 else {
            return nil
        }

        let displayScale = max(
            floatingTabBar.traitCollection.displayScale,
            1
        )
        guard abs(leftArrowWidth - rightArrowWidth)
                <= 1 / displayScale else {
            return nil
        }

        let lastPage = CGFloat(pages.count - 1)
        let clampedProgress = min(max(pageProgress, 0), lastPage)
        let visibleArrowUnits: CGFloat
        if pages.count == 1 {
            visibleArrowUnits = 0
        } else {
            visibleArrowUnits =
                min(clampedProgress, 1)
                + min(lastPage - clampedProgress, 1)
        }

        let viewportWidth =
            outerWidth
            - backgroundInsets.left
            - backgroundInsets.right
            - max(leftArrowWidth, rightArrowWidth) * visibleArrowUnits
        guard viewportWidth.isFinite, viewportWidth > 0 else {
            return nil
        }
        return viewportWidth
    }

    private static func verifiedBackgroundInsetsMethod() -> Bool {
        guard let metricsClass = verifiedPlatformMetricsBaseClass() else {
            return false
        }
        return unsafe verifiedMethod(
            on: metricsClass,
            selector: PrivateUIKitRuntimeNames.backgroundInsetsSelector,
            typeEncoding: expectedBackgroundInsetsTypeEncoding
        ) != nil
    }

    private static func verifiedMethod(
        on type: AnyClass,
        selector: Selector,
        typeEncoding expectedTypeEncoding: String
    ) -> Method? {
        guard let method = unsafe class_getInstanceMethod(type, selector),
              let typeEncoding = unsafe method_getTypeEncoding(method),
              unsafe String(cString: typeEncoding)
                == expectedTypeEncoding else {
            return nil
        }
        return unsafe method
    }
}
