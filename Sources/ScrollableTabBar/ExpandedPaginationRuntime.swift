import ObjectiveC
import UIKit

@MainActor
enum ExpandedPaginationRuntime {
    private typealias MaximumContainerSizeImplementation =
        @convention(c) (AnyObject, Selector) -> CGSize
    private typealias LayoutSubviewsImplementation =
        @convention(c) (AnyObject, Selector) -> Void
    private typealias PageViewportWidthImplementation =
        @convention(c) (AnyObject, Selector, CGFloat) -> CGFloat
    private typealias CurrentPageImplementation =
        @convention(c) (AnyObject, Selector) -> CGFloat
    private typealias BackgroundInsetsImplementation =
        @convention(c) (AnyObject, Selector) -> UIEdgeInsets

    private static let expandedFloatingTabBarClassName =
        "ScrollableTabBarFullWidthPaginationFloatingTabBar"
    private static let expandedCollectionViewClassName =
        "ScrollableTabBarFullWidthPaginationCollectionView"
    private static let expectedMaximumContainerSizeTypeEncoding =
        "{CGSize=dd}16@0:8"
    private static let expectedLayoutSubviewsTypeEncoding = "v16@0:8"
    private static let expectedPageViewportWidthTypeEncoding = "d24@0:8d16"
    private static let expectedCurrentPageTypeEncoding = "d16@0:8"
    private static let expectedBackgroundInsetsTypeEncoding =
        "{UIEdgeInsets=dddd}16@0:8"

    static func makeFloatingTabBar(
        baseClass: UIView.Type
    ) -> UIView {
        guard #available(iOS 26.0, *),
              let expandedClass = makeExpandedFloatingTabBarClass(
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
        guard let glassMetricsBaseClass = NSClassFromString(
            PrivateUIKitRuntimeNames.floatingTabBarPlatformMetricsGlassBaseClassName
        ),
              isVerifiedGlassMetrics(
                metrics,
                baseClass: glassMetricsBaseClass
              ) else {
            scrollableTabBarLogger.error(
                "UIKit's floating tab metrics are not the verified Glass implementation; retaining the standard pagination width."
            )
            return baseClass.init(frame: .zero)
        }
        return expandedTabBar
    }

    static func prepareCollectionView(
        _ collectionView: UICollectionView,
        in floatingTabBar: UIView
    ) -> Bool {
        guard #available(iOS 26.0, *),
              NSStringFromClass(type(of: floatingTabBar))
                == expandedFloatingTabBarClassName else {
            return true
        }

        collectionView.isPagingEnabled = false
        if NSStringFromClass(type(of: collectionView))
            == expandedCollectionViewClassName {
            return true
        }

        guard collectionView.contentInset == .zero else {
            scrollableTabBarLogger.error(
                "UIKit's floating-tab collection inset changed; using the public adaptive tab control."
            )
            return false
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

    static func isVerifiedGlassMetrics(
        _ metrics: AnyObject,
        baseClass: AnyClass
    ) -> Bool {
        // UIKit specializes the verified Glass metrics base with device-specific
        // subclasses, so exact type equality would reject compatible runtimes.
        (metrics as? NSObject)?.isKind(of: baseClass) == true
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
        guard let maximumSizeMethod = unsafe verifiedMethod(
            on: baseClass,
            selector: maximumSizeSelector,
            typeEncoding: expectedMaximumContainerSizeTypeEncoding
        ),
              let layoutMethod = unsafe verifiedMethod(
                on: baseClass,
                selector: layoutSelector,
                typeEncoding: expectedLayoutSubviewsTypeEncoding
              ) else {
            scrollableTabBarLogger.error(
                "UIKit's floating-tab layout contract changed; retaining the standard pagination width."
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
            synchronizeCollectionGeometry(in: object)
        }
        let layoutOverride = unsafe imp_implementationWithBlock(layoutBlock)

        guard let subclass = unsafe objc_allocateClassPair(
            baseClass,
            expandedFloatingTabBarClassName,
            0
        ) else {
            unsafe imp_removeBlock(maximumSizeOverride)
            unsafe imp_removeBlock(layoutOverride)
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
              ) else {
            unsafe imp_removeBlock(maximumSizeOverride)
            unsafe imp_removeBlock(layoutOverride)
            objc_disposeClassPair(subclass)
            scrollableTabBarLogger.error(
                "UIKit's floating-tab layout overrides could not be installed."
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

        let selector = PrivateUIKitRuntimeNames.pageViewportWidthSelector
        guard let method = unsafe verifiedMethod(
            on: baseClass,
            selector: selector,
            typeEncoding: expectedPageViewportWidthTypeEncoding
        ),
              unsafe verifiedMethod(
                on: baseClass,
                selector: PrivateUIKitRuntimeNames.currentPageSelector,
                typeEncoding: expectedCurrentPageTypeEncoding
              ) != nil,
              verifiedBackgroundInsetsMethod() else {
            return nil
        }

        let originalImplementation = unsafe method_getImplementation(method)
        let block: @convention(block) (AnyObject, CGFloat) -> CGFloat = {
            object,
            pageProgress in
            let implementation = unsafe unsafeBitCast(
                originalImplementation,
                to: PageViewportWidthImplementation.self
            )
            let originalWidth = implementation(
                object,
                selector,
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
        let overrideImplementation = unsafe imp_implementationWithBlock(block)

        guard let subclass = unsafe objc_allocateClassPair(
            baseClass,
            expandedCollectionViewClassName,
            0
        ) else {
            unsafe imp_removeBlock(overrideImplementation)
            return nil
        }
        guard unsafe class_addMethod(
            subclass,
            selector,
            overrideImplementation,
            method_getTypeEncoding(method)
        ) else {
            unsafe imp_removeBlock(overrideImplementation)
            objc_disposeClassPair(subclass)
            return nil
        }
        objc_registerClassPair(subclass)
        return subclass
    }

    private static func synchronizeCollectionGeometry(
        in object: AnyObject
    ) {
        guard let floatingTabBar = object as? UIView,
              floatingTabBar.responds(
                to: PrivateUIKitRuntimeNames.itemsViewSelector
              ),
              let collectionView = unsafe floatingTabBar
                .perform(PrivateUIKitRuntimeNames.itemsViewSelector)?
                .takeUnretainedValue() as? UICollectionView,
              NSStringFromClass(type(of: collectionView))
                == expandedCollectionViewClassName,
              collectionView.responds(
                to: PrivateUIKitRuntimeNames.currentPageSelector
              ),
              collectionView.responds(
                to: PrivateUIKitRuntimeNames.pagesSelector
              ),
              let pages = unsafe collectionView
                .perform(PrivateUIKitRuntimeNames.pagesSelector)?
                .takeUnretainedValue() as? NSArray,
              pages.count > 0 else {
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
        guard currentPage.isFinite else {
            return
        }

        let viewportWidth = unsafe unsafeBitCast(
            collectionView.method(
                for: PrivateUIKitRuntimeNames.pageViewportWidthSelector
            ),
            to: PageViewportWidthImplementation.self
        )(
            collectionView,
            PrivateUIKitRuntimeNames.pageViewportWidthSelector,
            currentPage
        )
        let lastPage = CGFloat(pages.count - 1)
        guard let originalLastPageWidth = originalPageViewportWidth(
            for: collectionView,
            pageProgress: lastPage
        ),
              let expandedLastPageWidth = pageViewportWidth(
                for: collectionView,
                pageProgress: lastPage
              ),
              viewportWidth.isFinite,
              viewportWidth > 0 else {
            return
        }

        let trailingExpansion = max(
            expandedLastPageWidth - originalLastPageWidth,
            0
        )
        let tolerance = 1 / max(
            floatingTabBar.traitCollection.displayScale,
            1
        )

        if abs(
            collectionView.contentInset.right - trailingExpansion
        ) > tolerance {
            // Expanding the viewport shortens UIScrollView's maximum offset.
            // Restore exactly that lost range so UIKit's page targets remain
            // reachable without changing UIKit's page objects.
            var contentInset = collectionView.contentInset
            contentInset.right = trailingExpansion
            collectionView.contentInset = contentInset
        }

        if abs(collectionView.bounds.width - viewportWidth) > tolerance {
            // Preserve UIKit's origin. It animates the arrow reservation while
            // the viewport follows the current continuous page progress.
            var frame = collectionView.frame
            frame.size.width = viewportWidth
            collectionView.frame = frame
        }
    }

    private static func originalPageViewportWidth(
        for collectionView: UICollectionView,
        pageProgress: CGFloat
    ) -> CGFloat? {
        guard let runtimeClass = object_getClass(collectionView),
              let baseClass = class_getSuperclass(runtimeClass),
              let method = unsafe class_getInstanceMethod(
                baseClass,
                PrivateUIKitRuntimeNames.pageViewportWidthSelector
              ) else {
            return nil
        }
        let implementation = unsafe unsafeBitCast(
            method_getImplementation(method),
            to: PageViewportWidthImplementation.self
        )
        let width = implementation(
            collectionView,
            PrivateUIKitRuntimeNames.pageViewportWidthSelector,
            pageProgress
        )
        guard width.isFinite, width > 0 else {
            return nil
        }
        return width
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
        guard let metricsClass = NSClassFromString(
            PrivateUIKitRuntimeNames.floatingTabBarPlatformMetricsGlassBaseClassName
        ) else {
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
