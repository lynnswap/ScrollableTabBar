import UIKit

@MainActor
protocol ScrollableTabBarContent: AnyObject {
    var view: UIView { get }
    var selectionHandler: ((AnyHashable) -> Void)? { get set }
    var intrinsicHeight: CGFloat { get }

    func setItems(_ items: [ScrollableTabBarPresentationItem], selectedIndex: Int?) -> Bool

    func render(
        selectedIndex: Int?,
        isEnabled: Bool,
        accessibilityLabel: String?,
        accessibilityIdentifier: String?
    )

    func heightThatFits(_ size: CGSize) -> CGFloat
}

let scrollableTabBarMinimumHeight: CGFloat = 49

@MainActor
struct ScrollableTabBarPresentationItem {
    let id: AnyHashable
    let title: String
    let image: UIImage?
    let accessibilityIdentifier: String?
}

/// A tab selector whose overflow items remain reachable through horizontal pagination.
///
/// Use ``delegate`` to receive user selection. See <doc:SelectionOwnership> for state
/// ownership and event behavior.
@MainActor
public final class ScrollableTabBar<ID: Hashable>: UIView {
    /// A tab presented by ``ScrollableTabBar``.
    public struct Item: Identifiable {
        /// The stable identity used for selection.
        public let id: ID

        /// The text describing the tab.
        public var title: String

        /// An optional image shown when the active UIKit presentation supports it.
        public var image: UIImage?

        /// An optional identifier for UI automation.
        public var accessibilityIdentifier: String?

        /// Creates a tab item with stable identity and display content.
        public init(
            id: ID,
            title: String,
            image: UIImage? = nil,
            accessibilityIdentifier: String? = nil
        ) {
            self.id = id
            self.title = title
            self.image = image
            self.accessibilityIdentifier = accessibilityIdentifier
        }
    }

    /// The current membership and display order of the control.
    ///
    /// Use ``setItems(_:selectedID:)`` to update items and selection together.
    public private(set) var items: [Item]

    /// The identifier of the selected item, or `nil` when no item is selected.
    ///
    /// Assigning this property updates the presentation without sending
    /// a delegate callback. A non-`nil` identifier must belong to ``items``.
    public var selectedID: ID? {
        get { selectedIDStorage }
        set {
            if let newValue {
                precondition(
                    itemIndexByID[newValue] != nil,
                    "ScrollableTabBar selectedID must identify one of its items."
                )
            }
            selectedIDStorage = newValue
            renderContent()
        }
    }

    /// The object notified when the user selects a different item.
    ///
    /// The tab bar does not retain its delegate.
    public weak var delegate: (any ScrollableTabBarDelegate<ID>)?

    /// A Boolean value that determines whether the user can change the selection.
    public var isEnabled = true {
        didSet {
            renderContent()
        }
    }

    /// The contextual accessibility label propagated to the active presentation.
    public override var accessibilityLabel: String? {
        didSet {
            renderContent()
        }
    }

    /// The identifier propagated to the active presentation for UI automation.
    public override var accessibilityIdentifier: String? {
        didSet {
            renderContent()
        }
    }

    // The navigation container still owns compression below this component policy.
    // Capping the preferred width prevents spare title area from becoming empty glass
    // while retaining overflow as a normal presentation state.
    private static var preferredMaximumWidth: CGFloat { 640 }

    private(set) var content: any ScrollableTabBarContent
    private var itemIndexByID: [ID: Int]
    private var selectedIDStorage: ID?

    /// Creates a tab selector with the supplied items and selection.
    ///
    /// Item identifiers must be unique. A non-`nil` `selectedID` must identify
    /// one of the supplied items. Empty items and no selection are supported.
    public init(
        items: [Item] = [],
        selectedID: ID? = nil
    ) {
        let itemIndexByID = Self.indices(for: items, selectedID: selectedID)

        self.items = items
        self.itemIndexByID = itemIndexByID
        selectedIDStorage = selectedID
        content = Self.makeContent(
            items: Self.presentationItems(items),
            selectedIndex: selectedID.flatMap { itemIndexByID[$0] }
        )
        super.init(frame: .zero)

        isAccessibilityElement = false
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        setContentHuggingPriority(.defaultLow, for: .horizontal)
        addSubview(content.view)
        connectSelectionHandler()
        registerForTraitChanges([
            UITraitHorizontalSizeClass.self,
            UITraitPreferredContentSizeCategory.self,
        ]) { (self: ScrollableTabBar, _) in
            self.invalidateIntrinsicContentSize()
        }
        renderContent()
    }

    /// Replaces the items and selection without notifying the delegate.
    ///
    /// Supply the application's complete ordered items after adding, removing,
    /// reordering, or editing tabs. Identifiers must be unique and a non-`nil`
    /// `selectedID` must identify one of the new items. Pass `nil` to clear the
    /// selection, including when removing every item. Existing IDs retain their
    /// identity even when their display content or position changes.
    public func setItems(_ items: [Item], selectedID: ID?) {
        let indices = Self.indices(for: items, selectedID: selectedID)
        let wasEmpty = self.items.isEmpty
        self.items = items
        itemIndexByID = indices
        selectedIDStorage = selectedID

        let presentationItems = Self.presentationItems(items)
        let selectedIndex = selectedID.flatMap { indices[$0] }
        if wasEmpty || items.isEmpty {
            replaceContent(Self.makeContent(items: presentationItems, selectedIndex: selectedIndex))
        } else if !content.setItems(presentationItems, selectedIndex: selectedIndex) {
            replaceContent(AdaptiveTabContent(items: presentationItems))
        }
        renderContent()
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    public override var intrinsicContentSize: CGSize {
        CGSize(width: Self.preferredMaximumWidth, height: content.intrinsicHeight)
    }

    public override func sizeThatFits(_ size: CGSize) -> CGSize {
        let proposedWidth = size.width > 0 && size.width.isFinite
            ? min(size.width, Self.preferredMaximumWidth)
            : Self.preferredMaximumWidth
        return CGSize(
            width: proposedWidth,
            height: content.heightThatFits(size)
        )
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        content.view.frame = bounds
        content.view.layoutIfNeeded()
    }

    func didSelectItem(id: ID) {
        // A menu action can outlive the item snapshot that created it.
        guard itemIndexByID[id] != nil, isEnabled else {
            renderContent()
            return
        }

        guard id != selectedIDStorage else {
            return
        }
        selectedIDStorage = id
        renderContent()
        delegate?.scrollableTabBar(
            self,
            didSelect: id
        )
    }

    private func renderContent() {
        content.render(
            selectedIndex: selectedIDStorage.flatMap { itemIndexByID[$0] },
            isEnabled: isEnabled,
            accessibilityLabel: accessibilityLabel,
            accessibilityIdentifier: accessibilityIdentifier
        )
    }

    private func connectSelectionHandler() {
        content.selectionHandler = { [weak self] id in
            guard let id = id.base as? ID else { return }
            self?.didSelectItem(id: id)
        }
    }

    private func replaceContent(_ newContent: any ScrollableTabBarContent) {
        content.selectionHandler = nil
        content.view.removeFromSuperview()
        content = newContent
        addSubview(content.view)
        connectSelectionHandler()
    }

    private static func indices(for items: [Item], selectedID: ID?) -> [ID: Int] {
        var indices: [ID: Int] = [:]
        for (index, item) in items.enumerated() {
            precondition(
                indices.updateValue(index, forKey: item.id) == nil,
                "ScrollableTabBar item identifiers must be unique."
            )
        }
        if let selectedID {
            precondition(
                indices[selectedID] != nil,
                "ScrollableTabBar selectedID must identify one of its items.")
        }
        return indices
    }

    private static func presentationItems(_ items: [Item]) -> [ScrollableTabBarPresentationItem] {
        items.map {
            ScrollableTabBarPresentationItem(
                id: AnyHashable($0.id),
                title: $0.title,
                image: $0.image,
                accessibilityIdentifier: $0.accessibilityIdentifier
            )
        }
    }

    private static func makeContent(
        items: [ScrollableTabBarPresentationItem],
        selectedIndex: Int?
    ) -> any ScrollableTabBarContent {
        SystemFloatingTabContent.makeIfAvailable(items: items, selectedIndex: selectedIndex)
            ?? AdaptiveTabContent(items: items)
    }
}
