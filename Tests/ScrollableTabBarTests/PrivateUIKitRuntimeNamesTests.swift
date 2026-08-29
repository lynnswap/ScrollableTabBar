import Foundation
import ObjectiveC
import Testing
@testable import ScrollableTabBar

struct PrivateUIKitRuntimeNamesTests {
    @Test
    func decodesXORCatalogBytes() {
        #expect(
            PrivateUIKitRuntimeNames.decodedString([
                0xF3, 0xC2, 0xD4, 0xD3,
            ]) == "Test"
        )
    }

    @Test
    func catalogDecodesEveryRuntimeIdentifier() {
        #expect(PrivateUIKitRuntimeNames.floatingTabBarClassName == "_UIFloatingTabBar")
        #expect(
            PrivateUIKitRuntimeNames.floatingTabBarPlatformMetricsGlassBaseClassName
                == "_UIFloatingTabBarPlatformMetrics_Glass"
        )
        #expect(
            PrivateUIKitRuntimeNames.liquidLensViewClassName
                == "_UILiquidLensView"
        )
        #expect(
            PrivateUIKitRuntimeNames.currentPlatformMetricsSelectorName
                == "_currentPlatformMetrics"
        )
        #expect(
            PrivateUIKitRuntimeNames.maximumContainerSizeSelectorName
                == "_maximumContainerSizeForPagination"
        )
        #expect(
            PrivateUIKitRuntimeNames.pageViewportWidthSelectorName
                == "viewWidthForPageProgress:"
        )
        #expect(PrivateUIKitRuntimeNames.pagesSelectorName == "pages")
        #expect(
            PrivateUIKitRuntimeNames.currentPageSelectorName
                == "currentPage"
        )
        #expect(
            PrivateUIKitRuntimeNames.leftArrowButtonSelectorName
                == "leftArrowButton"
        )
        #expect(
            PrivateUIKitRuntimeNames.rightArrowButtonSelectorName
                == "rightArrowButton"
        )
        #expect(
            PrivateUIKitRuntimeNames.backgroundInsetsSelectorName
                == "backgroundInsets"
        )
        #expect(
            PrivateUIKitRuntimeNames.floatingTabBarSelectorName
                == "floatingTabBar"
        )
        #expect(PrivateUIKitRuntimeNames.itemModelReadKey == "_tabModel")
        #expect(PrivateUIKitRuntimeNames.attachedModelKey == "tabModel")
        #expect(PrivateUIKitRuntimeNames.attachedModelWriteSelectorName == "setTabModel:")
        #expect(PrivateUIKitRuntimeNames.itemsViewKey == "collectionView")
        #expect(PrivateUIKitRuntimeNames.sidebarVisibilityKey == "showsSidebarButton")

        #expect(
            NSStringFromSelector(PrivateUIKitRuntimeNames.currentPlatformMetricsSelector)
                == PrivateUIKitRuntimeNames.currentPlatformMetricsSelectorName
        )
        #expect(
            NSStringFromSelector(
                PrivateUIKitRuntimeNames.maximumContainerSizeSelector
            ) == PrivateUIKitRuntimeNames.maximumContainerSizeSelectorName
        )
        #expect(
            NSStringFromSelector(
                PrivateUIKitRuntimeNames.pageViewportWidthSelector
            ) == PrivateUIKitRuntimeNames.pageViewportWidthSelectorName
        )
        #expect(
            NSStringFromSelector(PrivateUIKitRuntimeNames.pagesSelector)
                == PrivateUIKitRuntimeNames.pagesSelectorName
        )
        #expect(
            NSStringFromSelector(
                PrivateUIKitRuntimeNames.currentPageSelector
            ) == PrivateUIKitRuntimeNames.currentPageSelectorName
        )
        #expect(
            NSStringFromSelector(
                PrivateUIKitRuntimeNames.leftArrowButtonSelector
            ) == PrivateUIKitRuntimeNames.leftArrowButtonSelectorName
        )
        #expect(
            NSStringFromSelector(
                PrivateUIKitRuntimeNames.rightArrowButtonSelector
            ) == PrivateUIKitRuntimeNames.rightArrowButtonSelectorName
        )
        #expect(
            NSStringFromSelector(
                PrivateUIKitRuntimeNames.backgroundInsetsSelector
            ) == PrivateUIKitRuntimeNames.backgroundInsetsSelectorName
        )
        #expect(
            NSStringFromSelector(
                PrivateUIKitRuntimeNames.floatingTabBarSelector
            ) == PrivateUIKitRuntimeNames.floatingTabBarSelectorName
        )
        #expect(
            NSStringFromSelector(PrivateUIKitRuntimeNames.itemModelReadSelector)
                == PrivateUIKitRuntimeNames.itemModelReadKey
        )
        #expect(
            NSStringFromSelector(PrivateUIKitRuntimeNames.attachedModelWriteSelector)
                == PrivateUIKitRuntimeNames.attachedModelWriteSelectorName
        )
        #expect(
            NSStringFromSelector(PrivateUIKitRuntimeNames.itemsViewSelector)
                == PrivateUIKitRuntimeNames.itemsViewKey
        )
        #expect(
            NSStringFromSelector(PrivateUIKitRuntimeNames.sidebarVisibilitySelector)
                == PrivateUIKitRuntimeNames.sidebarVisibilityKey
        )
    }
}
