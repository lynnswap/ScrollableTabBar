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
            PrivateUIKitRuntimeNames.floatingTabBarPlatformMetricsGlassClassName
                == "_UIFloatingTabBarPlatformMetrics_Glass"
        )
        #expect(PrivateUIKitRuntimeNames.liquidLensViewClassName == "_UILiquidLensView")
        #expect(PrivateUIKitRuntimeNames.currentPlatformMetricsSelectorName == "_currentPlatformMetrics")
        #expect(PrivateUIKitRuntimeNames.maximumContainerSizeSelectorName == "_maximumContainerSizeForPagination")
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
            NSStringFromSelector(PrivateUIKitRuntimeNames.maximumContainerSizeSelector)
                == PrivateUIKitRuntimeNames.maximumContainerSizeSelectorName
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
