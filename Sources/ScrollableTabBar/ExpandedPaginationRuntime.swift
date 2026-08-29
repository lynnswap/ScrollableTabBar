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

    private static let expandedFloatingTabBarClassName =
        "ScrollableTabBarFullWidthPaginationFloatingTabBar"
    private static let expandedCollectionViewClassName =
        "ScrollableTabBarFullWidthPaginationCollectionView"
    private static let leftEdgeEffectPocketClassName =
        "ScrollableTabBarLeftEdgeEffectPocketView"
    private static let rightEdgeEffectPocketClassName =
        "ScrollableTabBarRightEdgeEffectPocketView"
    private static let expectedMaximumContainerSizeTypeEncoding =
        "{CGSize=dd}16@0:8"
    private static let expectedLayoutSubviewsTypeEncoding = "v16@0:8"
    private static let expectedSetFrameTypeEncoding =
        "v48@0:8{CGRect={CGPoint=dd}{CGSize=dd}}16"
    private static let expectedPageViewportWidthTypeEncoding = "d24@0:8d16"
    private static let expectedCurrentPageTypeEncoding = "d16@0:8"
    private static let expectedBackgroundInsetsTypeEncoding =
        "{UIEdgeInsets=dddd}16@0:8"
    private static let expectedUpdateItemContentAlphaTypeEncoding =
        "v24@0:8@16"
    private static let expectedGestureIndexPathTypeEncoding =
        "@24@0:8@16"
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
    // Match UIView's effective visibility boundary so the blur and hit region
    // disappear with the native arrow rather than its floating-point tail.
    private static let minimumVisiblePageButtonOpacity: CGFloat = 0.01

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

        guard collectionView.contentInset == .zero,
              configureEdgeEffects(
                on: collectionView,
                in: floatingTabBar
              ) else {
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
        let updateAlphaSelector =
            PrivateUIKitRuntimeNames.updateItemContentAlphaSelector
        let gestureIndexPathSelector =
            PrivateUIKitRuntimeNames.gestureIndexPathSelector
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
            synchronizeCollectionGeometry(in: object)
            synchronizeEdgeEffectVisibility(in: object)
            updateEdgeEffects(in: object)
            synchronizeEdgeEffectPocketGeometry(in: object)
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
                restoreItemContentAlpha(
                    at: indexPath as IndexPath,
                    in: object
                )
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

        guard let subclass = unsafe objc_allocateClassPair(
            baseClass,
            expandedFloatingTabBarClassName,
            0
        ) else {
            unsafe imp_removeBlock(maximumSizeOverride)
            unsafe imp_removeBlock(layoutOverride)
            unsafe imp_removeBlock(updateAlphaOverride)
            unsafe imp_removeBlock(gestureIndexPathOverride)
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
              ) else {
            unsafe imp_removeBlock(maximumSizeOverride)
            unsafe imp_removeBlock(layoutOverride)
            unsafe imp_removeBlock(updateAlphaOverride)
            unsafe imp_removeBlock(gestureIndexPathOverride)
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
                    in: collectionView
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

        guard let subclass = unsafe objc_allocateClassPair(
            baseClass,
            expandedCollectionViewClassName,
            0
        ) else {
            unsafe imp_removeBlock(viewportWidthOverride)
            unsafe imp_removeBlock(contentOffsetOverride)
            unsafe imp_removeBlock(pageProgressOverride)
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
              ) else {
            unsafe imp_removeBlock(viewportWidthOverride)
            unsafe imp_removeBlock(contentOffsetOverride)
            unsafe imp_removeBlock(pageProgressOverride)
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
              let collectionView = collectionView(in: floatingTabBar),
              NSStringFromClass(type(of: collectionView))
                == expandedCollectionViewClassName,
              collectionView.responds(
                to: PrivateUIKitRuntimeNames.currentPageSelector
              ) else {
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
        guard viewportWidth.isFinite, viewportWidth > 0 else {
            return
        }

        let tolerance = 1 / max(
            floatingTabBar.traitCollection.displayScale,
            1
        )
        guard isActivelyRubberBanding(
            collectionView,
            viewportWidth: viewportWidth,
            tolerance: tolerance
        ) == false else {
            return
        }

        if abs(collectionView.contentInset.right) > tolerance {
            var contentInset = collectionView.contentInset
            contentInset.right = 0
            collectionView.contentInset = contentInset
        }

        if abs(collectionView.bounds.width - viewportWidth) > tolerance {
            // UIKit animates the arrow reservation by moving the viewport's
            // origin. Preserve that origin while expanding only its width.
            var frame = collectionView.frame
            frame.size.width = viewportWidth
            collectionView.frame = frame
        }
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
              hasVerifiedEdgeEffectUpdateContract(
                on: collectionView
              ) else {
            return false
        }

        leftEdgeEffect.style = .soft
        rightEdgeEffect.style = .soft
        // The public edge-element interaction does not establish pocket
        // geometry in the floating-tab hierarchy. Anchor the soft effect to
        // UIKit's native page buttons, then explicitly refresh after layout.
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
        synchronizeEdgeEffectVisibility(in: floatingTabBar)
        guard forceEdgeEffectPockets(in: floatingTabBar),
              updateEdgeEffects(in: floatingTabBar) else {
            return false
        }
        synchronizeEdgeEffectPocketGeometry(in: floatingTabBar)
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

    private static func hasVerifiedEdgeEffectUpdateContract(
        on collectionView: UICollectionView
    ) -> Bool {
        let interactionSelector =
            PrivateUIKitRuntimeNames.edgeEffectViewInteractionSelector
        guard let interactionGetter = unsafe verifiedMethod(
            on: type(of: collectionView),
            selector: interactionSelector,
            typeEncoding: expectedObjectGetterTypeEncoding
        ),
              let interaction = unsafe unsafeBitCast(
                method_getImplementation(interactionGetter),
                to: ObjectGetterImplementation.self
              )(
                collectionView,
                interactionSelector
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
                selector: PrivateUIKitRuntimeNames.leftEdgeEffectPocketSelector,
                typeEncoding: expectedObjectGetterTypeEncoding
              ) != nil,
              unsafe verifiedMethod(
                on: interactionType,
                selector: PrivateUIKitRuntimeNames.rightEdgeEffectPocketSelector,
                typeEncoding: expectedObjectGetterTypeEncoding
              ) != nil,
              unsafe verifiedMethod(
                on: interactionType,
                selector: PrivateUIKitRuntimeNames.forceEdgeEffectPocketSelector,
                typeEncoding: expectedForceEdgeEffectPocketTypeEncoding
              ) != nil else {
            return false
        }
        return true
    }

    @discardableResult
    private static func updateEdgeEffects(
        in object: AnyObject
    ) -> Bool {
        let interactionSelector =
            PrivateUIKitRuntimeNames.edgeEffectViewInteractionSelector
        let updateSelector =
            PrivateUIKitRuntimeNames.edgeEffectUpdateSelector
        guard #available(iOS 26.0, *),
              let floatingTabBar = object as? UIView,
              let collectionView = collectionView(in: floatingTabBar),
              collectionView.responds(to: interactionSelector),
              let interaction = unsafe collectionView
                .perform(interactionSelector)?
                .takeUnretainedValue(),
              interaction.responds(to: updateSelector) else {
            return false
        }

        _ = unsafe interaction.perform(updateSelector)
        return true
    }

    private static func forceEdgeEffectPockets(
        in object: AnyObject
    ) -> Bool {
        let interactionSelector =
            PrivateUIKitRuntimeNames.edgeEffectViewInteractionSelector
        let forceSelector =
            PrivateUIKitRuntimeNames.forceEdgeEffectPocketSelector
        guard #available(iOS 26.0, *),
              let floatingTabBar = object as? UIView,
              let collectionView = collectionView(in: floatingTabBar),
              collectionView.responds(to: interactionSelector),
              let interaction = unsafe collectionView
                .perform(interactionSelector)?
                .takeUnretainedValue(),
              interaction.responds(to: forceSelector) else {
            return false
        }

        let implementation = unsafe unsafeBitCast(
            interaction.method(for: forceSelector),
            to: ForceEdgeEffectPocketImplementation.self
        )
        for edge: UIRectEdge in [.left, .right] {
            let result = implementation(
                interaction,
                forceSelector,
                edge.rawValue
            )
            guard let pocket = result as? UIView,
                  installEdgeEffectPocketClass(
                    on: pocket,
                    edge: edge
                  ) else {
                return false
            }
        }
        return true
    }

    @discardableResult
    private static func synchronizeEdgeEffectPocketGeometry(
        in object: AnyObject
    ) -> Bool {
        let interactionSelector =
            PrivateUIKitRuntimeNames.edgeEffectViewInteractionSelector
        guard #available(iOS 26.0, *),
              let floatingTabBar = object as? UIView,
              let collectionView = collectionView(in: floatingTabBar),
              collectionView.responds(to: interactionSelector),
              let interaction = unsafe collectionView
                .perform(interactionSelector)?
                .takeUnretainedValue(),
              let leftPageButton = view(
                from: floatingTabBar,
                selector: PrivateUIKitRuntimeNames.leftArrowButtonSelector
              ),
              let rightPageButton = view(
                from: floatingTabBar,
                selector: PrivateUIKitRuntimeNames.rightArrowButtonSelector
              ),
              let leftOpacity = pageButtonContentOpacity(
                of: leftPageButton
              ),
              let rightOpacity = pageButtonContentOpacity(
                of: rightPageButton
              ) else {
            return false
        }

        let configurations: [(Selector, UIRectEdge, CGFloat)] = [
            (
                PrivateUIKitRuntimeNames.leftEdgeEffectPocketSelector,
                .left,
                leftOpacity
            ),
            (
                PrivateUIKitRuntimeNames.rightEdgeEffectPocketSelector,
                .right,
                rightOpacity
            ),
        ]
        for (selector, edge, opacity) in configurations {
            guard let pocket = view(
                from: interaction,
                selector: selector
            ) else {
                if opacity > minimumVisiblePageButtonOpacity {
                    return false
                }
                continue
            }
            guard alignEdgeEffectPocket(
                pocket,
                edge: edge
            ) else {
                return false
            }
        }
        return true
    }

    private static func alignEdgeEffectPocket(
        _ pocket: UIView,
        edge: UIRectEdge
    ) -> Bool {
        guard installEdgeEffectPocketClass(
            on: pocket,
            edge: edge
        ) else {
            return false
        }

        guard let targetFrame = pageButtonFrame(
            for: pocket,
            edge: edge
        ) else {
            return false
        }
        pocket.frame = targetFrame
        let tolerance = 1 / max(
            pocket.traitCollection.displayScale,
            1
        )
        return abs(pocket.frame.minX - targetFrame.minX) <= tolerance
            && abs(pocket.frame.minY - targetFrame.minY) <= tolerance
            && abs(pocket.frame.width - targetFrame.width) <= tolerance
            && abs(pocket.frame.height - targetFrame.height) <= tolerance
    }

    private static func installEdgeEffectPocketClass(
        on pocket: UIView,
        edge: UIRectEdge
    ) -> Bool {
        let className = edgeEffectPocketClassName(for: edge)
        guard let currentClass = object_getClass(pocket) else {
            return false
        }
        if NSStringFromClass(currentClass) == className {
            return true
        }
        guard let pocketClass = makeEdgeEffectPocketClass(
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

    private static func makeEdgeEffectPocketClass(
        baseClass: AnyClass,
        edge: UIRectEdge
    ) -> AnyClass? {
        let className = edgeEffectPocketClassName(for: edge)
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
        // UIKit owns the floating bar and collection geometry, and rewrites
        // each pocket during scrolling. Constrain that native artifact at its
        // frame owner instead of introducing a second inset or a moving mask.
        let setFrameBlock:
            @convention(block) (AnyObject, CGRect) -> Void = {
                object,
                proposedFrame in
                var frame = proposedFrame
                if let pocket = object as? UIView,
                   let targetFrame = pageButtonFrame(
                    for: pocket,
                    edge: edge
                   ) {
                    frame = targetFrame
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

    private static func edgeEffectPocketClassName(
        for edge: UIRectEdge
    ) -> String {
        edge == .left
            ? leftEdgeEffectPocketClassName
            : rightEdgeEffectPocketClassName
    }

    private static func pageButtonFrame(
        for pocket: UIView,
        edge: UIRectEdge
    ) -> CGRect? {
        guard let pocketContainer = pocket.superview,
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

        let frame = button.convert(
            button.bounds,
            to: pocketContainer
        )
        let geometry = [
            frame.minX,
            frame.minY,
            frame.width,
            frame.height,
        ]
        guard geometry.allSatisfy(\.isFinite),
              frame.width > 0,
              frame.height > 0 else {
            return nil
        }
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

    private static func clampedContentOffset(
        _ contentOffset: CGPoint,
        forPage page: Int,
        in collectionView: UICollectionView
    ) -> CGPoint {
        let viewportWidth = pageViewportWidth(
            for: collectionView,
            pageProgress: CGFloat(page)
        ) ?? collectionView.bounds.width
        guard let range = naturalHorizontalScrollRange(
            in: collectionView,
            viewportWidth: viewportWidth
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
                in: collectionView
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
        viewportWidth: CGFloat
    ) -> ClosedRange<CGFloat>? {
        let systemLeftInset =
            collectionView.adjustedContentInset.left
            - collectionView.contentInset.left
        let systemRightInset =
            collectionView.adjustedContentInset.right
            - collectionView.contentInset.right
        let dimensions = [
            collectionView.contentSize.width,
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
            collectionView.contentSize.width
                - viewportWidth
                + systemRightInset,
            minimumOffset
        )
        return minimumOffset...maximumOffset
    }

    private static func isActivelyRubberBanding(
        _ collectionView: UICollectionView,
        viewportWidth: CGFloat,
        tolerance: CGFloat
    ) -> Bool {
        guard collectionView.isTracking
                || collectionView.isDragging
                || collectionView.isDecelerating,
              let range = naturalHorizontalScrollRange(
                in: collectionView,
                viewportWidth: viewportWidth
              ) else {
            return false
        }
        return collectionView.contentOffset.x
                < range.lowerBound - tolerance
            || collectionView.contentOffset.x
                > range.upperBound + tolerance
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
