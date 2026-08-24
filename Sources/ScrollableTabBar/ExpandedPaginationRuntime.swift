import ObjectiveC
import UIKit

@MainActor
enum ExpandedPaginationRuntime {
    private typealias MaximumContainerSizeImplementation =
        @convention(c) (AnyObject, Selector) -> CGSize

    private static let expandedFloatingTabBarClassName =
        "ScrollableTabBarExpandedPaginationFloatingTabBar"
    private static let expectedMaximumContainerSizeTypeEncoding =
        "{CGSize=dd}16@0:8"
    // The verified phone implementation applies this scale after its standard
    // horizontal margins. Its 600pt platform maximum is already non-binding,
    // so only the per-instance pagination result is widened.
    private static let normalPaginationWidthScale: CGFloat = 0.65

    static func makeFloatingTabBar(
        baseClass: UIView.Type
    ) -> UIView {
        guard #available(iOS 26.0, *),
              let expandedClass = makeExpandedFloatingTabBarClass(baseClass: baseClass) else {
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
        guard NSStringFromClass(type(of: metrics))
            == PrivateUIKitRuntimeNames.floatingTabBarPlatformMetricsGlassClassName else {
            scrollableTabBarLogger.error(
                "UIKit's floating tab metrics are not the verified Glass implementation; retaining the standard pagination width."
            )
            return baseClass.init(frame: .zero)
        }
        return expandedTabBar
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
        if let existingClass = NSClassFromString(expandedFloatingTabBarClassName) {
            guard class_getSuperclass(existingClass) === baseClass else {
                scrollableTabBarLogger.fault(
                    "The ScrollableTabBar runtime class has an unexpected superclass."
                )
                return nil
            }
            return existingClass as? UIView.Type
        }

        let selector = PrivateUIKitRuntimeNames.maximumContainerSizeSelector
        guard let method = unsafe class_getInstanceMethod(baseClass, selector),
              let typeEncoding = unsafe method_getTypeEncoding(method),
              unsafe String(cString: typeEncoding)
                == expectedMaximumContainerSizeTypeEncoding else {
            scrollableTabBarLogger.error(
                "UIKit's floating-tab pagination signature changed; retaining the standard pagination width."
            )
            return nil
        }

        let originalImplementation = unsafe method_getImplementation(method)
        let block: @convention(block) (AnyObject) -> CGSize = { object in
            let implementation = unsafe unsafeBitCast(
                originalImplementation,
                to: MaximumContainerSizeImplementation.self
            )
            let originalSize = implementation(object, selector)
            guard let view = object as? UIView,
                  view.bounds.width > 0,
                  originalSize.width > 0 else {
                return originalSize
            }

            let unscaledWidth = originalSize.width / normalPaginationWidthScale
            let inferredHorizontalMargin = (view.bounds.width - unscaledWidth) / 2
            guard (12...24).contains(inferredHorizontalMargin) else {
                return originalSize
            }
            return CGSize(width: unscaledWidth, height: originalSize.height)
        }
        let overrideImplementation = unsafe imp_implementationWithBlock(block)

        guard let subclass = unsafe objc_allocateClassPair(
            baseClass,
            expandedFloatingTabBarClassName,
            0
        ) else {
            unsafe imp_removeBlock(overrideImplementation)
            scrollableTabBarLogger.error(
                "UIKit's floating-tab pagination subclass could not be allocated."
            )
            return nil
        }
        guard unsafe class_addMethod(
            subclass,
            selector,
            overrideImplementation,
            typeEncoding
        ) else {
            unsafe imp_removeBlock(overrideImplementation)
            objc_disposeClassPair(subclass)
            scrollableTabBarLogger.error(
                "UIKit's floating-tab pagination override could not be installed."
            )
            return nil
        }
        objc_registerClassPair(subclass)
        return subclass as? UIView.Type
    }
}
