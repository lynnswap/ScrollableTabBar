import Foundation
import ObjectiveC
import Testing
@testable import ScrollableTabBar

struct PrivateUIKitRuntimeNamesTests {
    @Test
    func catalogDecodesEveryRuntimeIdentifier() {
        typealias Names = PrivateUIKitRuntimeNames

        #expect(Names.floatingTabBarClassName == "_UIFloatingTabBar")
        #expect(
            Names.floatingTabBarPlatformMetricsBaseClassName
                == "_UIFloatingTabBarPlatformMetrics"
        )
        #expect(
            Names.floatingTabBarPlatformMetricsGlassBaseClassName
                == "_UIFloatingTabBarPlatformMetrics_Glass"
        )
        #expect(Names.floatingTabBarItemViewClassName == "_UIFloatingTabBarItemView")
        #expect(Names.liquidLensViewClassName == "_UILiquidLensView")

        #expect(Names.layerFiltersKey == "filters")
        #expect(Names.filterTypeKey == "type")
        #expect(Names.variableBlurFilterType == "variableBlur")
        #expect(Names.filterInputMaskImageKey == "inputMaskImage")

        let selectors: [(Selector, String)] = [
            (Names.itemWriteSelector, "setItem:"),
            (Names.currentPlatformMetricsSelector, "_currentPlatformMetrics"),
            (Names.maximumContainerSizeSelector, "_maximumContainerSizeForPagination"),
            (Names.pageViewportWidthSelector, "viewWidthForPageProgress:"),
            (Names.pagesSelector, "pages"),
            (Names.currentPageSelector, "currentPage"),
            (Names.pageWidthSelector, "width"),
            (Names.leftArrowButtonSelector, "leftArrowButton"),
            (Names.rightArrowButtonSelector, "rightArrowButton"),
            (Names.backgroundInsetsSelector, "backgroundInsets"),
            (Names.floatingTabBarSelector, "floatingTabBar"),
            (Names.itemModelReadSelector, "_tabModel"),
            (Names.attachedModelWriteSelector, "setTabModel:"),
            (Names.itemsViewSelector, "collectionView"),
            (Names.sidebarVisibilitySelector, "showsSidebarButton"),
            (Names.updateItemContentAlphaSelector, "_updateContentAlphaForItemAtIndexPath:"),
            (Names.gestureIndexPathSelector, "_indexPathForGestureRecognizer:"),
            (Names.contentOffsetForPageSelector, "contentOffsetForPage:"),
            (
                Names.pageProgressForContentOffsetSelector,
                "pageProgressForContentOffset:clamped:"
            ),
            (Names.edgeEffectGeometryViewWriteSelector, "_setOverrideGeometryView:"),
            (Names.edgeEffectViewInteractionSelector, "_edgeEffectViewInteraction"),
            (Names.edgeEffectViewSelector, "effectView"),
            (Names.edgeCaptureViewSelector, "captureView"),
            (Names.pageButtonButtonSelector, "button"),
            (Names.forceEdgeEffectPocketSelector, "forcingPocketFor:"),
            (Names.edgeEffectUpdateSelector, "update"),
            (Names.pageButtonContentOpacitySelector, "contentOpacity"),
        ]
        for (selector, name) in selectors {
            #expect(NSStringFromSelector(selector) == name)
        }
    }
}
