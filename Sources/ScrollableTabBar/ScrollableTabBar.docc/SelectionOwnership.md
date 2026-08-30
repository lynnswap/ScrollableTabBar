# Selection Ownership

Keep semantic selection in application state and use `ScrollableTabBar` as its
UIKit projection.

## App-Owned State

The app defines each item ID, the meaning and order of the items, the selected
domain value, and the content associated with that value. Item membership and
order are immutable for one control instance. Create a new control if either
changes.

Construct ``ScrollableTabBar`` with a nonempty collection of unique IDs and an
initial ``ScrollableTabBar/selectedID`` that belongs to that collection.
Assigning another member ID updates the projection without sending
a delegate callback.

## User Selection

When a user chooses a different item, the control updates
``ScrollableTabBar/selectedID`` first and then calls
``ScrollableTabBarDelegate/scrollableTabBar(_:didSelect:)`` exactly once with
the selected domain ID. Update application state from that ID and render the
corresponding content. Reselecting the current item does not call the delegate.

Set ``ScrollableTabBar/isEnabled`` to `false` when user selection must be
prevented. Programmatic state remains app-owned.
