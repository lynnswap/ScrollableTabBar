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
        #expect(PrivateUIKitRuntimeNames.tabModelGetterKey == "_tabModel")
        #expect(PrivateUIKitRuntimeNames.attachedTabModelKey == "tabModel")
        #expect(PrivateUIKitRuntimeNames.tabModelSetterSelectorName == "setTabModel:")
        #expect(PrivateUIKitRuntimeNames.collectionViewKey == "collectionView")
        #expect(PrivateUIKitRuntimeNames.showsSidebarButtonKey == "showsSidebarButton")

        #expect(
            NSStringFromSelector(PrivateUIKitRuntimeNames.currentPlatformMetricsSelector)
                == PrivateUIKitRuntimeNames.currentPlatformMetricsSelectorName
        )
        #expect(
            NSStringFromSelector(PrivateUIKitRuntimeNames.maximumContainerSizeSelector)
                == PrivateUIKitRuntimeNames.maximumContainerSizeSelectorName
        )
        #expect(
            NSStringFromSelector(PrivateUIKitRuntimeNames.tabModelGetterSelector)
                == PrivateUIKitRuntimeNames.tabModelGetterKey
        )
        #expect(
            NSStringFromSelector(PrivateUIKitRuntimeNames.tabModelSetterSelector)
                == PrivateUIKitRuntimeNames.tabModelSetterSelectorName
        )
        #expect(
            NSStringFromSelector(PrivateUIKitRuntimeNames.collectionViewSelector)
                == PrivateUIKitRuntimeNames.collectionViewKey
        )
        #expect(
            NSStringFromSelector(PrivateUIKitRuntimeNames.showsSidebarButtonSelector)
                == PrivateUIKitRuntimeNames.showsSidebarButtonKey
        )
    }
}
