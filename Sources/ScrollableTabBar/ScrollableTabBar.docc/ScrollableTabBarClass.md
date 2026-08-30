# ``ScrollableTabBar/ScrollableTabBar``

## Presentation

The control prefers UIKit's floating-tab presentation when its expected
runtime contract is available. Otherwise, it uses a public segmented or menu
presentation while preserving item order, typed selection, enablement, and
event semantics.

The control requests up to a 640-point intrinsic width and accepts narrower
space from its container. The number of visible items, continuous scrolling,
arrow placement, pagination width, and exact visual treatment are not API
guarantees.

> Important: The preferred presentation relies on undocumented UIKit APIs and
> runtime behavior. Its future availability, exact appearance, and App Store
> acceptance are not guaranteed.

## Topics

### Essentials

- ``init(items:selectedID:)``
- ``Item``

### Reading State

- ``items``
- ``selectedID``
