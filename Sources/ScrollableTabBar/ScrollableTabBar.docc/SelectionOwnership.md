# Selection Ownership

Keep semantic selection in application state and use `ScrollableTabBar` as its
UIKit projection.

## App-Owned State

The app defines each item ID, the meaning and order of the items, the selected
domain value, and the content associated with that value. Give each item a
unique, stable ID; changes to its title, image, or position do not change its
identity.

Construct ``ScrollableTabBar`` with your items and an optional
``ScrollableTabBar/selectedID``. A non-`nil` selection must identify one of the
items. `nil` represents no selection, and an empty items array is supported.
Assigning `selectedID` updates the presentation without calling the delegate.

## Update Items and Selection Together

Use ``ScrollableTabBar/setItems(_:selectedID:)`` after adding, removing,
reordering, or editing items. Pass the complete ordered array and the selection
that should be shown after the update. When removing the selected item, the app
chooses another member ID or `nil` in that same call. The control does not choose
a replacement selection for the app.

```swift
var items: [ScrollableTabBar<String>.Item] = [
    .init(id: "inbox", title: "Inbox"),
    .init(id: "archive", title: "Archive"),
]
let tabBar = ScrollableTabBar(items: items, selectedID: "inbox")

items.append(.init(id: "drafts", title: "Drafts"))
tabBar.setItems(items, selectedID: "drafts")

items.removeAll { $0.id == "drafts" }
items[0].title = "All Mail"
tabBar.setItems(items, selectedID: "inbox")

// Keep the control mounted while its data is empty.
tabBar.setItems([], selectedID: nil)
```

An empty control displays no items. Populate it again with `setItems` when data
becomes available. Updates do not call the delegate, including when the selected
ID changes or becomes `nil`.

## User Selection

When a user chooses a different item, the control updates
``ScrollableTabBar/selectedID`` first and then calls
``ScrollableTabBarDelegate/scrollableTabBar(_:didSelect:)`` exactly once with
the selected domain ID. Update application state from that ID and render the
corresponding content. Reselecting the current item does not call the delegate.

Set ``ScrollableTabBar/isEnabled`` to `false` when user selection must be
prevented. Programmatic state remains app-owned.

## Migrating Existing Callers

`selectedID` is optional so the control can represent empty items and no
selection. Unwrap it when reading the control's state. Delegate callbacks still
supply a nonoptional ID because they report the item the user selected.

Replace control recreation on membership or order changes with
`setItems(_:selectedID:)`. Keep application state as the source of truth and
render application content directly after a programmatic update.
