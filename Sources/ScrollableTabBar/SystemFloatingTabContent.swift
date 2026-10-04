import ABIBridge
import ObjectiveC
import OSLog
import UIKit

let scrollableTabBarLogger = Logger(
    subsystem: "com.lynnswap.ScrollableTabBar",
    category: "ScrollableTabBar.Runtime"
)

@MainActor
struct SystemFloatingTabComponents {
    let tabController: UITabBarController
    let tabs: [UITab]
    let floatingTabBar: UIView
    let tabItemsView: UICollectionView
}

@MainActor
enum SystemFloatingTabRuntime {
    static func makeComponents(
        items: [ScrollableTabBarPresentationItem],
        selectedIndex: Int?
    ) -> SystemFloatingTabComponents? {
        guard !items.isEmpty else { return nil }
        guard let floatingTabBarClass = NSClassFromString(
            PrivateUIKitRuntimeNames.floatingTabBarClassName
        ) as? UIView.Type else {
            scrollableTabBarLogger.error(
                "UIKit's floating tab bar class is unavailable; using the public adaptive tab control."
            )
            return nil
        }

        let tabController = UITabBarController()
        tabController.mode = .tabBar
        let tabs = items.map(makeTab)
        tabController.tabs = tabs
        tabController.selectedTab = selectedIndex.map { tabs[$0] }

        let floatingTabBar = ExpandedPaginationRuntime.makeFloatingTabBar(
            baseClass: floatingTabBarClass)
        guard let tabItemsView = attachModel(from: tabs, to: floatingTabBar) else {
            detachModel(from: floatingTabBar)
            return nil
        }
        return SystemFloatingTabComponents(
            tabController: tabController,
            tabs: tabs,
            floatingTabBar: floatingTabBar,
            tabItemsView: tabItemsView
        )
    }

    static func makeTab(_ item: ScrollableTabBarPresentationItem) -> UITab {
        let tab = UITab(
            title: item.title,
            image: item.image,
            identifier: UUID().uuidString
        ) { _ in UIViewController() }
        tab.preferredPlacement = .fixed
        tab.accessibilityIdentifier = item.accessibilityIdentifier
        return tab
    }

    static func attachModel(from tabs: [UITab], to floatingTabBar: UIView) -> UICollectionView? {
        guard let firstTab = tabs.first else { return nil }
        do {
            let modelGetter = try ABIRuntime.shared.object(firstTab).method(
                selector: PrivateUIKitRuntimeNames.itemModelReadSelector,
                as: (() -> AnyObject?).self
            )
            guard let model = try unsafe modelGetter.unsafeInvoke() else { return nil }
            let setModel = try ABIRuntime.shared.object(floatingTabBar).method(
                selector: PrivateUIKitRuntimeNames.attachedModelWriteSelector,
                as: ((AnyObject?) -> Void).self
            )
            try unsafe setModel.unsafeInvoke(model)
            let sidebar = try ABIRuntime.shared.object(floatingTabBar).method(
                selector: PrivateUIKitRuntimeNames.sidebarVisibilitySelector,
                as: (() -> Bool).self
            )
            let collection = try ABIRuntime.shared.object(floatingTabBar).method(
                selector: PrivateUIKitRuntimeNames.itemsViewSelector,
                as: (() -> UICollectionView?).self
            )
            guard try unsafe !sidebar.unsafeInvoke(),
                let tabItemsView = try unsafe collection.unsafeInvoke(),
                ExpandedPaginationRuntime.prepareCollectionView(tabItemsView, in: floatingTabBar)
            else {
                scrollableTabBarLogger.error(
                    "UIKit's floating tab bar produced an unsupported presentation; using the public adaptive tab control."
                )
                return nil
            }
            return tabItemsView
        } catch {
            scrollableTabBarLogger.error("UIKit's floating tab model is unavailable: \(error)")
            return nil
        }
    }

    static func detachModel(from floatingTabBar: UIView) {
        do {
            let setModel = try ABIRuntime.shared.object(floatingTabBar).method(
                selector: PrivateUIKitRuntimeNames.attachedModelWriteSelector,
                as: ((AnyObject?) -> Void).self
            )
            try unsafe setModel.unsafeInvoke(nil)
        } catch {
            scrollableTabBarLogger.error("Could not detach UIKit's floating tab model: \(error)")
        }
    }
}

@MainActor
final class SystemFloatingTabContent: NSObject,
    ScrollableTabBarContent,
    UITabBarControllerDelegate
{
    var view: UIView { floatingView }
    var selectionHandler: ((AnyHashable) -> Void)?
    var intrinsicHeight: CGFloat { scrollableTabBarMinimumHeight }
    let floatingView: SystemFloatingTabView
    let tabController: UITabBarController
    private(set) var tabs: [UITab]
    private(set) var tabItemsView: UICollectionView
    private var items: [ScrollableTabBarPresentationItem]
    private var renderedIndex: Int?

    static func makeIfAvailable(
        items: [ScrollableTabBarPresentationItem],
        selectedIndex: Int?
    ) -> SystemFloatingTabContent? {
        guard let components = SystemFloatingTabRuntime.makeComponents(
            items: items,
            selectedIndex: selectedIndex
        ) else {
            return nil
        }
        return SystemFloatingTabContent(
            items: items, selectedIndex: selectedIndex, components: components)
    }

    private init(
        items: [ScrollableTabBarPresentationItem],
        selectedIndex: Int?,
        components: SystemFloatingTabComponents
    ) {
        self.items = items
        renderedIndex = selectedIndex
        tabController = components.tabController
        tabs = components.tabs
        tabItemsView = components.tabItemsView
        floatingView = SystemFloatingTabView(
            floatingTabBar: components.floatingTabBar,
            tabController: components.tabController
        )
        super.init()
        tabController.delegate = self
    }

    isolated deinit {
        tabController.delegate = nil
        SystemFloatingTabRuntime.detachModel(from: floatingView.floatingTabBar)
        tabController.tabs = []
    }

    func setItems(_ items: [ScrollableTabBarPresentationItem], selectedIndex: Int?) -> Bool {
        // Removing the selected UITab can synchronously select another tab and
        // call the controller delegate while setTabs is still applying the array.
        tabController.delegate = nil
        defer { tabController.delegate = self }
        let existingTabs = Dictionary(uniqueKeysWithValues: zip(self.items.map(\.id), tabs))
        let tabs = items.map { item in
            let tab = existingTabs[item.id] ?? SystemFloatingTabRuntime.makeTab(item)
            tab.title = item.title
            tab.image = item.image
            tab.accessibilityIdentifier = item.accessibilityIdentifier
            return tab
        }
        self.items = items
        self.tabs = tabs
        renderedIndex = selectedIndex
        tabController.setTabs(tabs, animated: false)
        tabController.selectedTab = selectedIndex.map { tabs[$0] }
        guard
            let tabItemsView = SystemFloatingTabRuntime.attachModel(
                from: tabs, to: floatingView.floatingTabBar)
        else {
            return false
        }
        self.tabItemsView = tabItemsView
        floatingView.setNeedsLayout()
        return true
    }

    func render(
        selectedIndex: Int?,
        isEnabled: Bool,
        accessibilityLabel: String?,
        accessibilityIdentifier: String?
    ) {
        renderedIndex = selectedIndex
        let selectedTab = selectedIndex.map { tabs[$0] }
        if tabController.selectedTab !== selectedTab {
            tabController.selectedTab = selectedTab
        }

        floatingView.isUserInteractionEnabled = isEnabled
        floatingView.alpha = isEnabled ? 1 : 0.5
        floatingView.accessibilityLabel = accessibilityLabel
        floatingView.accessibilityIdentifier = accessibilityIdentifier
        for tab in tabs { tab.isEnabled = isEnabled }
    }

    func heightThatFits(_ size: CGSize) -> CGFloat {
        scrollableTabBarMinimumHeight
    }

    func tabBarController(
        _ tabBarController: UITabBarController,
        didSelectTab selectedTab: UITab,
        previousTab: UITab?
    ) {
        guard let selectedIndex = tabs.firstIndex(where: { $0 === selectedTab }),
            selectedIndex != renderedIndex
        else {
            return
        }
        selectionHandler?(items[selectedIndex].id)
    }
}

@MainActor
final class SystemFloatingTabView: UIView {
    private static var controllerLifetimeKey: UInt8 = 0
    let floatingTabBar: UIView

    init(floatingTabBar: UIView, tabController: UITabBarController) {
        self.floatingTabBar = floatingTabBar
        super.init(frame: .zero)

        // UIKit's cells can release tab-owned child controllers during UIView
        // teardown, after Swift stored properties have been destroyed. Associated
        // storage keeps their parent alive until the view's ivars are destroyed.
        unsafe objc_setAssociatedObject(
            self, &Self.controllerLifetimeKey, tabController, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        isAccessibilityElement = false
        // Preserve UIKit's individual tab elements while exposing the control's
        // contextual label once when assistive technology enters the group.
        accessibilityContainerType = .semanticGroup
        addSubview(floatingTabBar)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        floatingTabBar.frame = bounds
        floatingTabBar.layoutIfNeeded()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil else {
            return
        }
        setNeedsLayout()
        layoutIfNeeded()
        if #available(iOS 26.0, *), hasLiquidLens == false {
            scrollableTabBarLogger.error(
                "UIKit's floating tab bar did not create its Liquid Glass selection lens."
            )
        }
    }

    var hasLiquidLens: Bool {
        containsView(
            named: PrivateUIKitRuntimeNames.liquidLensViewClassName,
            below: floatingTabBar
        )
    }

    private func containsView(named className: String, below view: UIView) -> Bool {
        NSStringFromClass(type(of: view)) == className
            || view.subviews.contains { containsView(named: className, below: $0) }
    }
}
