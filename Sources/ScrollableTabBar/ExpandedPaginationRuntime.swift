import ABIBridge
import ObjectiveC
import UIKit

@MainActor
enum ExpandedPaginationRuntime {
    private typealias ContentOffsetImplementation = NativeObjCImplementation<CGPoint, Int>
    private static var hooksByClass: [String: [NativeObjCMethodHook]] = [:]

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
    private static let legacyProgressiveEdgeMaskLayerName =
        "ScrollableTabBarLegacyProgressiveEdgeMask"
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
        guard
            let metrics = value(
                in: expandedTabBar,
                selector: PrivateUIKitRuntimeNames.currentPlatformMetricsSelector,
                as: AnyObject.self
            )
        else {
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
        guard
            let layoutOwner = view(
                from: layout, selector: PrivateUIKitRuntimeNames.floatingTabBarSelector),
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
        guard
            let method = try? ABIRuntime.shared.object(floatingTabBar).method(
                selector: PrivateUIKitRuntimeNames.maximumContainerSizeSelector,
                as: (() -> CGSize).self
            )
        else { return nil }
        return try? unsafe method.unsafeInvoke()
    }

    private static func makeExpandedFloatingTabBarClass(baseClass: UIView.Type) -> UIView.Type? {
        makeSubclass(of: baseClass, named: expandedFloatingTabBarClassName) { subclass in
            [
                unsafe .mainActorMethod(
                    on: subclass,
                    selector: PrivateUIKitRuntimeNames.maximumContainerSizeSelector,
                    as: (() -> CGSize).self,
                    onFailure: reportHookFailure
                ) { call in
                    let originalSize = try call.proceed()
                    guard let view = try call.receiver as? UIView,
                        view.bounds.width.isFinite, view.bounds.width > 0,
                        originalSize.height.isFinite, originalSize.height > 0
                    else {
                        return originalSize
                    }
                    return CGSize(width: view.bounds.width, height: originalSize.height)
                },
                unsafe .mainActorMethod(
                    on: subclass, selector: #selector(UIView.layoutSubviews),
                    as: (() -> Void).self, onFailure: reportHookFailure
                ) { call in
                    try call.proceed()
                    synchronizeEdgeEffectVisibility(in: try call.receiver)
                },
                unsafe .mainActorMethod(
                    on: subclass,
                    selector: PrivateUIKitRuntimeNames.updateItemContentAlphaSelector,
                    as: ((NSIndexPath) -> Void).self, onFailure: reportHookFailure
                ) { call, indexPath in
                    try call.proceed(indexPath)
                    if #available(iOS 26.0, *) {
                        restoreItemContentAlpha(at: indexPath as IndexPath, in: try call.receiver)
                    }
                },
                unsafe .mainActorMethod(
                    on: subclass,
                    selector: PrivateUIKitRuntimeNames.gestureIndexPathSelector,
                    as: ((UIGestureRecognizer) -> NSIndexPath?).self,
                    onFailure: reportHookFailure
                ) { call, gesture in
                    if let original = try call.proceed(gesture) { return original }
                    guard let floatingTabBar = try call.receiver as? UIView,
                        let collectionView = collectionView(in: floatingTabBar),
                        let indexPath = visibleItemIndexPath(
                            for: gesture, in: collectionView, within: floatingTabBar)
                    else {
                        return nil
                    }
                    return indexPath as NSIndexPath
                },
                unsafe .mainActorMethod(
                    on: subclass,
                    selector: #selector(
                        UIScrollViewDelegate.scrollViewWillEndDragging(
                            _:withVelocity:targetContentOffset:)),
                    as: ((UIScrollView, CGPoint, UnsafeMutablePointer<CGPoint>) -> Void).self,
                    onFailure: reportHookFailure
                ) { call, scrollView, velocity, target in
                    try unsafe call.proceed(scrollView, velocity, target)
                    unsafe alignDecelerationTarget(target, for: scrollView, in: try call.receiver)
                },
            ]
        } as? UIView.Type
    }

    private static func makeExpandedCollectionViewClass(baseClass: AnyClass) -> AnyClass? {
        makeSubclass(of: baseClass, named: expandedCollectionViewClassName) { subclass in
            let originalContentOffset = try ABIRuntime.shared.objcImplementation(
                on: baseClass, selector: PrivateUIKitRuntimeNames.contentOffsetForPageSelector,
                as: ((Int) -> CGPoint).self
            )
            let currentPage = try ABIRuntime.shared.objcMethod(
                on: baseClass, selector: PrivateUIKitRuntimeNames.currentPageSelector,
                as: (() -> CGFloat).self
            )
            return [
                unsafe .mainActorMethod(
                    on: subclass, selector: PrivateUIKitRuntimeNames.pageViewportWidthSelector,
                    as: ((CGFloat) -> CGFloat).self, onFailure: reportHookFailure
                ) { call, progress in
                    let originalWidth = try call.proceed(progress)
                    guard let collectionView = try call.receiver as? UICollectionView,
                        let width = pageViewportWidth(for: collectionView, pageProgress: progress),
                        width >= originalWidth
                    else { return originalWidth }
                    return width
                },
                unsafe .mainActorMethod(
                    on: subclass, selector: PrivateUIKitRuntimeNames.contentOffsetForPageSelector,
                    as: ((Int) -> CGPoint).self, onFailure: reportHookFailure
                ) { call, page in
                    let originalOffset = try call.proceed(page)
                    guard let collectionView = try call.receiver as? UICollectionView else {
                        return originalOffset
                    }
                    // Keep this mapping and pageProgressForContentOffset: as an
                    // inverse pair. Insets would expose empty scrollable content.
                    return clampedContentOffset(
                        originalOffset, forPage: page, in: collectionView,
                        originalContentOffsetImplementation: originalContentOffset
                    )
                },
                unsafe .mainActorMethod(
                    on: subclass,
                    selector: PrivateUIKitRuntimeNames.pageProgressForContentOffsetSelector,
                    as: ((CGPoint, Bool) -> CGFloat).self, onFailure: reportHookFailure
                ) { call, offset, clamped in
                    guard let collectionView = try call.receiver as? UICollectionView,
                        let progress = pageProgress(
                            for: offset, in: collectionView,
                            originalContentOffsetImplementation: originalContentOffset,
                            clamped: clamped
                        )
                    else { return try call.proceed(offset, clamped) }
                    return progress
                },
                unsafe .mainActorMethod(
                    on: subclass, selector: #selector(setter: UIView.frame),
                    as: ((CGRect) -> Void).self, onFailure: reportHookFailure
                ) { call, proposedFrame in
                    guard let collectionView = try call.receiver as? UICollectionView else {
                        return try call.proceed(proposedFrame)
                    }
                    let progress = try unsafe currentPage.unsafeInvoke(on: collectionView)
                    guard progress.isFinite,
                        let viewportWidth = pageViewportWidth(
                            for: collectionView, pageProgress: progress)
                    else {
                        return try call.proceed(proposedFrame)
                    }
                    // setFrame: clamps contentOffset even when only the origin
                    // moves. Preserve rubber-banding by updating center separately.
                    var frame = proposedFrame
                    frame.size.width = max(proposedFrame.width, viewportWidth)
                    if collectionView.bounds.size != frame.size {
                        collectionView.bounds.size = frame.size
                    }
                    collectionView.center = CGPoint(x: frame.midX, y: frame.midY)
                },
                unsafe .mainActorMethod(
                    on: subclass, selector: #selector(setter: UIScrollView.contentInset),
                    as: ((UIEdgeInsets) -> Void).self, onFailure: reportHookFailure
                ) { call, proposedInset in
                    // The page mapping owns the horizontal range. System safe-area
                    // adjustments remain in adjustedContentInset.
                    var inset = proposedInset
                    inset.left = 0
                    inset.right = 0
                    try call.proceed(inset)
                },
            ]
        }
    }

    @available(iOS 26.0, *)
    private static func configureEdgeEffects(
        on collectionView: UICollectionView,
        in floatingTabBar: UIView
    ) -> Bool {
        guard
            let leftArrowButton = view(
                from: floatingTabBar, selector: PrivateUIKitRuntimeNames.leftArrowButtonSelector),
            let rightArrowButton = view(
                from: floatingTabBar, selector: PrivateUIKitRuntimeNames.rightArrowButtonSelector),
            pageButtonContentOpacity(of: leftArrowButton) != nil,
            pageButtonContentOpacity(of: rightArrowButton) != nil,
            view(from: leftArrowButton, selector: PrivateUIKitRuntimeNames.pageButtonButtonSelector)
                != nil,
            view(
                from: rightArrowButton, selector: PrivateUIKitRuntimeNames.pageButtonButtonSelector)
                != nil,
            hasVerifiedEdgeEffectActivationContract(on: collectionView)
        else { return false }

        let leftEdgeEffect = collectionView.leftEdgeEffect
        let rightEdgeEffect = collectionView.rightEdgeEffect
        do {
            let leftGeometry = try ABIRuntime.shared.object(leftEdgeEffect).method(
                selector: PrivateUIKitRuntimeNames.edgeEffectGeometryViewWriteSelector,
                as: ((UIView?) -> Void).self
            )
            let rightGeometry = try ABIRuntime.shared.object(rightEdgeEffect).method(
                selector: PrivateUIKitRuntimeNames.edgeEffectGeometryViewWriteSelector,
                as: ((UIView?) -> Void).self
            )
            try unsafe leftGeometry.unsafeInvoke(leftArrowButton)
            try unsafe rightGeometry.unsafeInvoke(rightArrowButton)
        } catch {
            scrollableTabBarLogger.error("UIKit's edge geometry is unavailable: \(error)")
            return false
        }
        configureEdgeElementContainer(on: leftArrowButton, edge: .left, for: collectionView)
        configureEdgeElementContainer(on: rightArrowButton, edge: .right, for: collectionView)
        leftEdgeEffect.style = .soft
        rightEdgeEffect.style = .soft
        synchronizeEdgeEffectVisibility(in: floatingTabBar)
        // This floating hierarchy does not request pockets from the public
        // overlay interaction alone. Force initial creation, extend only the
        // effect capture beneath the sibling arrows, and anchor each pocket to
        // the corresponding physical edge.
        return installExpandedEdgeGeometry(in: floatingTabBar)
            && forceEdgeEffectPockets(in: floatingTabBar)
            && updateEdgeEffects(in: floatingTabBar)
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

    private static func hasVerifiedEdgeEffectActivationContract(on collectionView: UICollectionView)
        -> Bool
    {
        guard let interaction = edgeEffectInteraction(in: collectionView) else { return false }
        do {
            let type: AnyClass = type(of: interaction)
            _ = try ABIRuntime.shared.objcMethod(
                on: type, selector: PrivateUIKitRuntimeNames.edgeEffectUpdateSelector,
                as: (() -> Void).self
            )
            _ = try ABIRuntime.shared.objcMethod(
                on: type, selector: PrivateUIKitRuntimeNames.forceEdgeEffectPocketSelector,
                as: ((UInt) -> UIView?).self
            )
            _ = try ABIRuntime.shared.objcMethod(
                on: type, selector: PrivateUIKitRuntimeNames.edgeEffectViewSelector,
                as: (() -> UIView?).self
            )
            _ = try ABIRuntime.shared.objcMethod(
                on: type, selector: PrivateUIKitRuntimeNames.edgeCaptureViewSelector,
                as: (() -> UIView?).self
            )
            return true
        } catch { return false }
    }

    private static func edgeEffectInteraction(in collectionView: UICollectionView) -> AnyObject? {
        value(
            in: collectionView,
            selector: PrivateUIKitRuntimeNames.edgeEffectViewInteractionSelector, as: AnyObject.self
        )
    }

    @discardableResult
    private static func updateEdgeEffects(in object: AnyObject) -> Bool {
        guard #available(iOS 26.0, *),
              let floatingTabBar = object as? UIView,
              let collectionView = collectionView(in: floatingTabBar),
            let interaction = edgeEffectInteraction(in: collectionView)
        else { return false }
        return value(
            in: interaction, selector: PrivateUIKitRuntimeNames.edgeEffectUpdateSelector,
            as: Void.self) != nil
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

    private static func makeExpandedEdgeGeometryClass(baseClass: AnyClass, className: String)
        -> AnyClass?
    {
        makeSubclass(of: baseClass, named: className) { subclass in
            [
                unsafe .mainActorMethod(
                    on: subclass, selector: #selector(setter: UIView.frame),
                    as: ((CGRect) -> Void).self, onFailure: reportHookFailure
                ) { call, proposedFrame in
                    let frame =
                        if let view = try call.receiver as? UIView {
                            expandedEdgeGeometryFrame(proposedFrame, for: view) ?? proposedFrame
                        } else { proposedFrame }
                    try call.proceed(frame)
                }
            ]
        }
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

    private static func forceEdgeEffectPockets(in object: AnyObject) -> Bool {
        guard #available(iOS 26.0, *),
              let floatingTabBar = object as? UIView,
              let collectionView = collectionView(in: floatingTabBar),
            let interaction = edgeEffectInteraction(in: collectionView),
            let forcePocket = try? ABIRuntime.shared.object(interaction).method(
                selector: PrivateUIKitRuntimeNames.forceEdgeEffectPocketSelector,
                as: ((UInt) -> UIView?).self
            )
        else { return false }
        for edge: UIRectEdge in [.left, .right] {
            guard let pocket = try? unsafe forcePocket.unsafeInvoke(edge.rawValue),
                installAlignedEdgeEffectPocketClass(on: pocket, edge: edge)
            else { return false }
        }
        return true
    }

    private static func applyLegacyProgressiveBlurMask(
        in pocket: UIView,
        edge: UIRectEdge
    ) -> Bool {
        if #available(iOS 27.0, *) {
            return true
        }
        guard let blurView = firstVariableBlurView(in: pocket),
              applyLegacyProgressiveBlurMask(
                to: blurView,
                edge: edge
              ),
              applyLegacyProgressiveEdgeMask(
                to: pocket,
                edge: edge
              ) else {
            return false
        }
        return true
    }

    private static func applyLegacyProgressiveBlurMask(
        to blurView: UIView,
        edge: UIRectEdge
    ) -> Bool {
        let maskKey = PrivateUIKitRuntimeNames.filterInputMaskImageKey
        guard let variableBlur = variableBlurFilter(in: blurView),
              blurView.bounds.width.isFinite,
              blurView.bounds.height.isFinite else {
            return false
        }

        let width = Int(blurView.bounds.width.rounded(.up))
        let height = Int(blurView.bounds.height.rounded(.up))
        guard width > 0, height > 0 else {
            return false
        }
        if let currentMask = cgImage(
            from: variableBlur.value(forKey: maskKey)
        ),
           currentMask.width == width,
           currentMask.height == height {
            return true
        }
        guard let mask = legacyProgressiveBlurMask(
            width: width,
            height: height,
            edge: edge
        ) else {
            return false
        }
        variableBlur.setValue(mask, forKey: maskKey)
        return cgImage(
            from: variableBlur.value(forKey: maskKey)
        ) != nil
    }

    private static func firstVariableBlurView(
        in view: UIView
    ) -> UIView? {
        for subview in view.subviews {
            if variableBlurFilter(in: subview) != nil {
                return subview
            }
            if let match = firstVariableBlurView(in: subview) {
                return match
            }
        }
        return nil
    }

    private static func variableBlurFilter(
        in view: UIView
    ) -> NSObject? {
        let filtersKey = PrivateUIKitRuntimeNames.layerFiltersKey
        let typeKey = PrivateUIKitRuntimeNames.filterTypeKey
        guard let filters = view.layer.value(
            forKey: filtersKey
        ) as? [NSObject] else {
            return nil
        }
        return filters.first {
            $0.value(forKey: typeKey) as? String
                == PrivateUIKitRuntimeNames.variableBlurFilterType
        }
    }

    private static func applyLegacyProgressiveEdgeMask(
        to pocket: UIView,
        edge: UIRectEdge
    ) -> Bool {
        let maskLayer: CAGradientLayer
        if let currentMask = pocket.layer.mask {
            guard currentMask.name == legacyProgressiveEdgeMaskLayerName,
                  let currentGradient = currentMask as? CAGradientLayer else {
                return false
            }
            maskLayer = currentGradient
        } else {
            maskLayer = CAGradientLayer()
            maskLayer.name = legacyProgressiveEdgeMaskLayerName
            pocket.layer.mask = maskLayer
        }

        let opaque = CGColor(gray: 1, alpha: 1)
        let clear = CGColor(gray: 0, alpha: 0)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        maskLayer.frame = pocket.bounds
        maskLayer.startPoint = CGPoint(x: 0, y: 0.5)
        maskLayer.endPoint = CGPoint(x: 1, y: 0.5)
        maskLayer.locations = [0, 0.5, 1]
        maskLayer.colors = edge == .left
            ? [opaque, clear, clear]
            : [clear, clear, opaque]
        CATransaction.commit()
        return true
    }

    private static func cgImage(from value: Any?) -> CGImage? {
        guard let value else {
            return nil
        }
        let object = value as AnyObject
        guard CFGetTypeID(object) == CGImage.typeID else {
            return nil
        }
        return unsafe unsafeDowncast(object, to: CGImage.self)
    }

    private static func legacyProgressiveBlurMask(
        width: Int,
        height: Int,
        edge: UIRectEdge
    ) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = unsafe CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return nil
        }

        // iOS 27's V8 pocket uses a 59-point nonlinear mask with a 1.5-point
        // blur radius. iOS 26 exposes a 1-point variable blur with no mask, so
        // these intensities are V8's sampled curve multiplied by 1.5. Keep the
        // full pocket for a continuous edge, but compress both masks into the
        // outer half where the arrow overlays scrolling content.
        let v8ReferenceWidth: CGFloat = 59
        let referenceProfile: [(position: CGFloat, intensity: CGFloat)] = [
            (0, 255),
            (5, 224),
            (10, 189),
            (15, 156),
            (20, 124),
            (25, 94),
            (30, 69),
            (35, 46),
            (40, 28),
            (45, 15),
            (50, 6),
            (55, 0),
            (59, 0),
        ]
        let blurWidthFraction: CGFloat = 0.5
        let locations: [CGFloat]
        let intensities: [CGFloat]
        if edge == .left {
            locations = referenceProfile.map {
                $0.position / v8ReferenceWidth * blurWidthFraction
            } + [1]
            intensities = referenceProfile.map(\.intensity) + [0]
        } else {
            locations = [0] + referenceProfile.map {
                1 - blurWidthFraction
                    + $0.position / v8ReferenceWidth * blurWidthFraction
            }
            intensities = [0]
                + referenceProfile.reversed().map(\.intensity)
        }
        let colors = intensities.map {
            CGColor(gray: $0 / 255, alpha: 1)
        }
        guard let gradient = unsafe CGGradient(
            colorsSpace: colorSpace,
            colors: colors as CFArray,
            locations: locations
        ) else {
            return nil
        }
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: 0),
            end: CGPoint(x: width, y: 0),
            options: []
        )
        return context.makeImage()
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

    private static func makeAlignedEdgeEffectPocketClass(baseClass: AnyClass, edge: UIRectEdge)
        -> AnyClass?
    {
        makeSubclass(of: baseClass, named: alignedEdgeEffectPocketClassName(for: edge)) {
            subclass in
            var requests = [
                unsafe NativeObjCHookRequest.mainActorMethod(
                    on: subclass, selector: #selector(setter: UIView.frame),
                    as: ((CGRect) -> Void).self, onFailure: reportHookFailure
                ) { call, proposedFrame in
                    let frame =
                        if let pocket = try call.receiver as? UIView {
                            alignedEdgeEffectPocketFrame(proposedFrame, for: pocket, edge: edge)
                                ?? proposedFrame
                        } else { proposedFrame }
                    try call.proceed(frame)
                }
            ]
            if #unavailable(iOS 27.0) {
                requests.append(
                    unsafe .mainActorMethod(
                        on: subclass, selector: #selector(UIView.layoutSubviews),
                        as: (() -> Void).self, onFailure: reportHookFailure
                    ) { call in
                        try call.proceed()
                        if let pocket = try call.receiver as? UIView {
                            _ = applyLegacyProgressiveBlurMask(in: pocket, edge: edge)
                        }
                    })
            }
            return requests
        }
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
        // Keep the legacy pocket tall and square so its internal layers are not
        // clipped. The masks above independently constrain the visible effect.
        var frame = proposedFrame
        if #available(iOS 27.0, *) {
            frame.size.width = buttonFrame.width + proposedFrame.height / 2
        } else {
            frame.size.width = max(buttonFrame.width, proposedFrame.height)
        }
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

    private static func floatingTabBar(for collectionView: UICollectionView) -> UIView? {
        view(
            from: collectionView.collectionViewLayout,
            selector: PrivateUIKitRuntimeNames.floatingTabBarSelector)
    }

    private static func pageButtonContentOpacity(of pageButton: UIView) -> CGFloat? {
        guard
            let opacity = value(
                in: pageButton, selector: PrivateUIKitRuntimeNames.pageButtonContentOpacitySelector,
                as: CGFloat.self
            ), opacity.isFinite
        else { return nil }
        return opacity
    }

    private static func view(from object: AnyObject, selector: Selector) -> UIView? {
        value(in: object, selector: selector, as: UIView.self)
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

    private static func collectionView(in floatingTabBar: UIView) -> UICollectionView? {
        value(
            in: floatingTabBar, selector: PrivateUIKitRuntimeNames.itemsViewSelector,
            as: UICollectionView.self)
    }

    private static func originalContentOffsetImplementation(for collectionView: UICollectionView)
        -> ContentOffsetImplementation?
    {
        guard let runtimeClass = object_getClass(collectionView),
            let baseClass = class_getSuperclass(runtimeClass)
        else { return nil }
        return try? ABIRuntime.shared.objcImplementation(
            on: baseClass, selector: PrivateUIKitRuntimeNames.contentOffsetForPageSelector,
            as: ((Int) -> CGPoint).self
        )
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
        originalContentOffsetImplementation: ContentOffsetImplementation
    ) -> CGFloat? {
        guard
            let pages = value(
                in: collectionView, selector: PrivateUIKitRuntimeNames.pagesSelector,
                as: NSArray.self),
            pages.count > 0
        else { return nil }
        // UICollectionView materializes its content extent lazily. UIKit's
        // page model already owns the complete boundary-page geometry.
        let pageGeometry: (Int) -> (origin: CGFloat, width: CGFloat)? = { pageIndex in
            let page = pages[pageIndex] as AnyObject
            guard
                let width = value(
                    in: page, selector: PrivateUIKitRuntimeNames.pageWidthSelector, as: CGFloat.self
                ),
                let offset = try? unsafe originalContentOffsetImplementation.unsafeInvoke(
                    on: collectionView, pageIndex),
                offset.x.isFinite, width.isFinite, width >= 0
            else { return nil }
            return (offset.x, width)
        }
        guard let firstPage = pageGeometry(0),
            let finalPage = pageGeometry(pages.count - 1),
              let semanticWidth = semanticPageModelWidth(
                firstPageOrigin: firstPage.origin, firstPageWidth: firstPage.width,
                finalPageOrigin: finalPage.origin, finalPageWidth: finalPage.width
            )
        else { return nil }
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
            let pages = value(
                in: collectionView, selector: PrivateUIKitRuntimeNames.pagesSelector,
                as: NSArray.self),
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
        unsafe targetContentOffset.pointee = clampedContentOffset(
            unsafe targetContentOffset.pointee,
            forPage: pages.count - 1,
            in: collectionView,
            originalContentOffsetImplementation:
                originalContentOffsetImplementation
        )
    }

    private static func clampedContentOffset(
        _ contentOffset: CGPoint,
        forPage page: Int,
        in collectionView: UICollectionView,
        originalContentOffsetImplementation: ContentOffsetImplementation
    ) -> CGPoint {
        let viewportWidth = pageViewportWidth(
            for: collectionView,
            pageProgress: CGFloat(page)
        ) ?? collectionView.bounds.width
        let contentWidth = semanticContentWidth(
            in: collectionView,
            originalContentOffsetImplementation:
                    originalContentOffsetImplementation
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
        originalContentOffsetImplementation: ContentOffsetImplementation,
        clamped: Bool
    ) -> CGFloat? {
        guard
            let pages = value(
                in: collectionView, selector: PrivateUIKitRuntimeNames.pagesSelector,
                as: NSArray.self),
              pages.count > 0 else {
            return nil
        }

        guard
            let targets = try? (0..<pages.count).map({ page in
                let originalTarget = try unsafe originalContentOffsetImplementation.unsafeInvoke(
                    on: collectionView, page)
            return clampedContentOffset(
                    originalTarget, forPage: page, in: collectionView,
                    originalContentOffsetImplementation: originalContentOffsetImplementation
            ).x
            })
        else { return nil }
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
            let pages = value(
                in: collectionView, selector: PrivateUIKitRuntimeNames.pagesSelector,
                as: NSArray.self),
              pages.count > 0 else {
            return nil
        }

        guard let floatingTabBar = floatingTabBar(for: collectionView),
            let leftArrowButton = view(
                from: floatingTabBar, selector: PrivateUIKitRuntimeNames.leftArrowButtonSelector),
            let rightArrowButton = view(
                from: floatingTabBar, selector: PrivateUIKitRuntimeNames.rightArrowButtonSelector),
            let metrics = value(
                in: floatingTabBar,
                selector: PrivateUIKitRuntimeNames.currentPlatformMetricsSelector,
                as: AnyObject.self),
            let backgroundInsets = value(
                in: metrics, selector: PrivateUIKitRuntimeNames.backgroundInsetsSelector,
                as: UIEdgeInsets.self)
        else {
            return nil
        }
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

    private static func makeSubclass(
        of baseClass: AnyClass,
        named name: String,
        requests: (AnyClass) throws -> [NativeObjCHookRequest]
    ) -> AnyClass? {
        let subclass: AnyClass
        if let existing = NSClassFromString(name) {
            guard class_getSuperclass(existing) === baseClass else {
                scrollableTabBarLogger.fault(
                    "The ScrollableTabBar runtime class has an unexpected superclass.")
                return nil
            }
            subclass = existing
        } else {
            guard let allocated = unsafe objc_allocateClassPair(baseClass, name, 0) else {
                return nil
            }
            objc_registerClassPair(allocated)
            subclass = allocated
        }
        if hooksByClass[name] == nil {
            do {
                hooksByClass[name] = try unsafe ABIRuntime.shared.installHooks(requests(subclass))
            } catch {
                // Published ABIBridge dispatchers retain their class for the process
                // lifetime, even after a failed batch invalidates its registrations.
                scrollableTabBarLogger.error(
                    "Could not prepare UIKit pagination overrides: \(error)")
                return nil
            }
        }
        return subclass
    }

    nonisolated private static func reportHookFailure(_ error: any Error) {
        scrollableTabBarLogger.error("UIKit pagination override failed: \(error)")
    }

    private static func value<Value>(in object: AnyObject, selector: Selector, as type: Value.Type)
        -> Value?
    {
        guard
            let getter = try? ABIRuntime.shared.object(object).method(
                selector: selector, as: (() -> Value).self)
        else {
            return nil
        }
        return try? unsafe getter.unsafeInvoke()
    }
}
