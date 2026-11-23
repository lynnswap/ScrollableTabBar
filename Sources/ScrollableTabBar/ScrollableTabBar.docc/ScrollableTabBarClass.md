# ``ScrollableTabBar/ScrollableTabBar``

## Presentation

The control prefers UIKit's floating-tab presentation when its expected
runtime contract is available. Otherwise, it uses a public segmented or menu
presentation while preserving item order, typed selection, enablement, and
event semantics.

By default the control requests up to 640 points of width. Set
``sizesToFitContentWidth`` to `true` in an Auto Layout container to fit a short
row of tabs. Constrain the width to the space available for longer rows. The number of visible items, continuous scrolling,
arrow placement, pagination width, and exact visual treatment are not API
guarantees.

> Important: The preferred presentation relies on undocumented UIKit APIs and
> runtime behavior. Its future availability, exact appearance, and App Store
> acceptance are not guaranteed.

## Topics

### Essentials

- ``init(items:selectedID:)``
- ``Item``

### Updating and Reading State

- ``setItems(_:selectedID:)``
- ``items``
- ``selectedID``
