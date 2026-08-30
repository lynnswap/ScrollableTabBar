/// A delegate that receives user-driven selection changes from a ``ScrollableTabBar``.
@MainActor
public protocol ScrollableTabBarDelegate<SelectionID>: AnyObject {
    /// The stable identifier type used by the tab bar.
    associatedtype SelectionID: Hashable

    /// Tells the delegate that the user selected a different item.
    ///
    /// The tab bar updates its ``ScrollableTabBar/selectedID`` and presentation before
    /// calling this method. Programmatic selection and reselecting the current item do
    /// not call the delegate.
    func scrollableTabBar(
        _ tabBar: ScrollableTabBar<SelectionID>,
        didSelect selectedID: SelectionID
    )
}
