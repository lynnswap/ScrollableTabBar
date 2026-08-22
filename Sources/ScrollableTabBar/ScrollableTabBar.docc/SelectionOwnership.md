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
`UIControl.Event.valueChanged`.

## User Selection

When a user chooses a different item, the control updates
``ScrollableTabBar/selectedID`` first and then sends exactly one
`UIControl.Event.valueChanged`. Read `selectedID` from the event handler,
update application state, and render the corresponding content. Reselecting the
current item does not send an event.

Set the inherited `UIControl.isEnabled` property to `false` when user selection
must be prevented. Programmatic state remains app-owned.

## Presentation Boundary

The system floating presentation is an implementation preference, not a public
layout contract. The number of visible items, continuous scrolling, arrow
placement, pagination width, and exact visual treatment can vary with UIKit and
the available width.

If the undocumented runtime contract is unavailable or changes, the control
uses a public segmented or menu presentation. The fallback preserves item
order, typed selection, enablement, and event semantics; it does not promise an
identical appearance.
