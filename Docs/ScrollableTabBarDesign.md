# Standalone ScrollableTabBar Design

Status: Accepted
Branch: `codex/extract-scrollable-tab-bar`
Baseline: `9a04ea93b48522f7e4c4895199dcec5016033b13`

## Scope Contract

### Outcome

Ship `ScrollableTabBar` as an independently versioned Swift package so that
WebInspectorKit can later replace its same-package target with an exact remote
dependency without changing the Network consumer source.

### Consumers

- Planned first consumer: WebInspectorKit Network Detail after the standalone
  package is released.
- Distribution-proof consumer: a separate `ContractTests` package that imports
  the library product without `@testable`.
- Runtime consumer: a thin demo app that uses only the public product and
  exercises the control inside a real navigation hierarchy.

### Compatibility

- Preserve the public API and observable selection semantics already merged in
  WebInspectorKit.
- Preserve the existing iOS 18.0 minimum. `UITab.isEnabled` remains guarded at
  iOS 18.4. This intentionally retains the existing consumer contract rather
  than raising the floor to the default iOS 18.4 design baseline.
- The v1 API remains Swift-only.

### Non-goals

- Do not modify WebInspectorKit in this change. Its dependency migration begins
  only after a standalone release exists.
- Do not create a release, tag, or migration PR in WebInspectorKit as part of
  this branch.
- Do not add dynamic membership, per-item enablement, styling policy, badges,
  or a public presentation-strategy API.
- Do not add macOS or AppKit support, or publish an empty macOS module.
- Do not guarantee exact private UIKit visuals or App Store acceptance.

## Phase 1 Findings

1. The standalone repository is an initial Swift 6.3 package scaffold with one
   empty library target, one no-op test, no platform declaration, and no public
   API.
2. The merged WebInspectorKit implementation is already a leaf product with no
   dependencies and a complete public consumer story.
3. The existing public surface consists of one `UIControl` owner, its nested
   immutable item value, and inherited UIKit target/action behavior. No second
   product or public protocol is justified.
4. All four implementation files are currently wrapped in
   `#if canImport(UIKit)` because their source package also supports macOS. In a
   standalone UIKit-only package those guards would make macOS builds appear to
   succeed with an empty module and empty tests.
5. Swift package tests can create `UIWindow`, exercise the real private floating
   hierarchy, verify pagination and Liquid Glass, and validate teardown in an
   iOS Simulator test process. An app target is not required for these tests.
6. A real app process is still required for XCUITest gestures, the final
   `navigationItem.titleView` layout, real accessibility traversal, screenshots,
   and a Release executable string scan.
7. The private selectors, KVC keys, and private class names are currently plain
   string literals. Obfuscating selectors alone would leave equivalent private
   runtime identifiers in the product binary.
8. The process-global runtime subclass uses a `Lynnswap` vendor prefix. The
   prefix only prevents Objective-C runtime namespace collisions and has no
   public meaning; the package name itself can provide the namespace.
9. The standalone repository lacks an external consumer contract, README,
   DocC build, license, CI, and a supported runtime matrix.

## Target and Product Graph

```text
ScrollableTabBar package
├── ScrollableTabBar product
│   └── ScrollableTabBar target
├── ScrollableTabBarTests test target
└── ScrollableTabBar.docc

ContractTests package
└── ScrollableTabBarProductContractTests
    └── ScrollableTabBar product via package(path: "..")

ScrollableTabBarDemo.xcodeproj
├── ScrollableTabBarDemo app
│   └── local ScrollableTabBar product
└── ScrollableTabBarDemoUITests
    └── ScrollableTabBarDemo app

ScrollableTabBar.xcworkspace
├── root Swift package
└── ScrollableTabBarDemo.xcodeproj
```

The package keeps one product and one implementation target. Private runtime,
adaptive fallback, and public control are implementation variants of the same
consumer-facing control; splitting them into file-bucket targets would not add
an owner or dependency boundary.

The demo app is a composition root, not a second implementation. It imports the
same local library product that external apps import.

The shared `ScrollableTabBarTests` scheme owns the package Test action. Keeping
it separate from the library scheme avoids a name collision with the demo
project's local package-product scheme inside the combined workspace.

## Workspace Decision

Commit a top-level workspace because the repository will contain both the root
package and a demo app project. The workspace is a developer entry point only:

- package tests remain runnable from the shared `ScrollableTabBarTests` scheme;
- the workspace does not duplicate the library as an Xcode framework target;
- the demo project adds the app-process and XCUITest boundary that package tests
  cannot provide;
- the generated `.swiftpm/xcode/package.xcworkspace` remains ignored.

## Public API Sketch

```swift
import UIKit

@MainActor
public final class ScrollableTabBar<ID: Hashable>: UIControl {
    public struct Item: Identifiable {
        public let id: ID
        public let title: String
        public let image: UIImage?
        public let accessibilityIdentifier: String?

        public init(
            id: ID,
            title: String,
            image: UIImage? = nil,
            accessibilityIdentifier: String? = nil
        )
    }

    public let items: [Item]
    public var selectedID: ID { get set }

    public init(items: [Item], selectedID: ID)
}
```

Inherited `UIControl` APIs remain the event and enablement surface. No public
protocol, delegate, runtime strategy, or UIKit-private type is added.

### Public invariants

- `items` is nonempty and ordered.
- Item IDs are unique.
- Initial and assigned selections belong to `items`.
- Programmatic selection updates the projection without sending
  `.valueChanged`.
- User selection updates `selectedID` before sending exactly one
  `.valueChanged`; reselecting sends nothing.
- `isEnabled == false` prevents user selection and updates presentation state.
- When measured, the control requests a 640-point preferred maximum and honors
  narrower finite container proposals so overflow remains reachable.

## Consumer Code

WebInspectorKit before extraction already uses the intended external contract:

```swift
import ScrollableTabBar

let control = ScrollableTabBar(
    items: Mode.allCases.map { mode in
        .init(id: mode, title: mode.title)
    },
    selectedID: mode
)
control.addAction(selectionAction, for: .valueChanged)
navigationItem.titleView = control
```

After the standalone release, this source remains unchanged. Only
WebInspectorKit's package dependency declaration changes from a local target to
an exact remote product.

The contract fixture and demo app use their own domain ID enums with the same
initializer, `selectedID`, `isEnabled`, and target/action APIs. Neither may use
`@testable`, WebInspector types, or internal runtime state.

## Ownership and Lifecycle

| Concern | Owner |
| --- | --- |
| Semantic item membership, order, and app content routing | Consumer |
| Current UIKit selection projection and event delivery | `ScrollableTabBar` |
| Preferred navigation-title maximum | `ScrollableTabBar` |
| Final compression around other bar items | Consumer's `UINavigationBar` |
| Stable `UITab` instances and hidden controller | `SystemFloatingTabContent` |
| Private tab-model attach/detach | `SystemFloatingTabRuntime` |
| Runtime-coupled identifiers and decoding | `PrivateUIKitRuntimeNames` |
| Process-global Objective-C presentation subclasses | `ExpandedPaginationRuntime` |
| Segmented/menu fallback and trait adaptation | `AdaptiveTabContent` |
| App scene, navigation hierarchy, and displayed content | Demo app |

`ScrollableTabBar` retains one content implementation for its lifetime.
`SystemFloatingTabContent` retains the hidden `UITabBarController`, tabs,
collection view, and floating view as one lifecycle unit. Teardown removes the
delegate, detaches the private tab model, and clears the controller tabs. The
dynamically registered subclass intentionally remains process-global.

## Variation Axes and Absorption Points

| Axis | Absorption point | Adding a variant |
| --- | --- | --- |
| Private floating runtime available / unavailable | Content factory in `ScrollableTabBar` | Add one internal content type and one factory branch |
| Verified Glass assigned-bounds continuous viewport / standard UIKit layout | `ExpandedPaginationRuntime` | Add one verified runtime contract branch in that owner |
| Regular / compact / accessibility presentation fallback | `AdaptiveTabView` | Add one presentation decision and matching render branch |
| iOS runtime version | Availability guards at the API-use boundary | Add one guard where the changed UIKit contract is consumed |

Platform is not a variant in v1: the package is UIKit on iOS only.

## Private Runtime Identifier Policy

Add one internal `PrivateUIKitRuntimeNames` owner that follows
WebInspectorKit's Native Bridge convention:

- encode private selector names, KVC keys, and private class names as byte
  arrays using XOR key `0xA7`;
- decode only at the runtime capability boundary;
- construct selectors from decoded strings;
- keep existing selector, method-encoding, class, and KVC capability checks;
- preserve existing fallback behavior when UIKit's runtime contract changes.

The policy covers production identifiers for `_UIFloatingTabBar`, tab-model
access, collection/sidebar access, platform metrics, pagination viewport
sizing, and the Liquid Lens class check. Test expectations may contain plain
names because they are not linked into the distributed library product.

The self-registered
`ScrollableTabBarFullWidthPaginationFloatingTabBar` and
`ScrollableTabBarFullWidthPaginationCollectionView` names are our own readable
runtime metadata, not Apple private API identifiers. They retain a
package-scoped name in the process-global Objective-C namespace without a
personal vendor prefix.

## Source Layout

```text
Sources/ScrollableTabBar/
  ScrollableTabBar.swift
  PrivateUIKitRuntimeNames.swift
  SystemFloatingTabContent.swift
  ExpandedPaginationRuntime.swift
  AdaptiveTabContent.swift
  ScrollableTabBar.docc/
    ScrollableTabBar.md

Tests/ScrollableTabBarTests/
  ScrollableTabBarTests.swift
  PrivateUIKitRuntimeNamesTests.swift
  SystemFloatingTabContentTests.swift
  AdaptiveTabContentTests.swift

ContractTests/
  Package.swift
  Tests/ScrollableTabBarProductContractTests/
    ScrollableTabBarProductContractTests.swift

Tools/DemoApp/
  ScrollableTabBarDemo.xcodeproj/
  ScrollableTabBarDemo/
  ScrollableTabBarDemoUITests/

ScrollableTabBar.xcworkspace/
README.md
LICENSE
```

Each production file has one owner type and its private collaborators. The
package has no external runtime dependency.

## Access-control Plan

The only public declarations are:

- `ScrollableTabBar`
- `ScrollableTabBar.Item`
- the four item properties and item initializer
- `ScrollableTabBar.items`
- `ScrollableTabBar.selectedID`
- the control initializer

UIKit overrides required by the control remain public only where Swift requires
the override visibility. All runtime catalog, content, fallback, logging, and
test seams remain internal. No type is `open` beyond the inherited subclassing
behavior of the final public control.

## Migration and Deletion List

1. Replace the template source and no-op test with the merged WebInspectorKit
   implementation and owner tests.
2. Remove file-wide `#if canImport(UIKit)` wrappers; unconditional UIKit imports
   make unsupported host builds fail rather than publish an empty module.
3. Add the explicit iOS 18 platform floor and strict Swift 6 settings.
4. Replace every production plain private runtime identifier with the encoded
   catalog owner.
5. Replace `LynnswapScrollableTabBarExpandedPaginationFloatingTabBar` with the
   package-scoped runtime name.
6. Copy and adapt consumer documentation, ownership design, and MIT license.
7. Add external product contract and demo app; do not copy WebInspector-specific
   fixtures, localization, or Network tests.
8. Leave WebInspectorKit unchanged until a standalone release is available.

## Avoided Shapes

- Do not create a duplicate `ScrollableTabBar` Xcode framework target for the
  demo app; the Swift package is the only library source of truth.
- Do not make the demo app or UI tests reachable from the library target.
- Do not expose `UITab`, private selectors, runtime strategy, fallback choice,
  collection views, or page buttons publicly.
- Do not keep plain production KVC keys or private class names while encoding
  only `Selector` values.
- Do not add WebInspector compatibility wrappers or copy Network policy into the
  provider repository.
- Do not commit generated `.swiftpm` workspace or user data.

## Test Plan

### Package owner tests on iOS Simulator

- membership, identity, programmatic selection, event count/order, reselect,
  invalid selection, enablement, and sizing;
- segmented/menu fallback parity, trait changes, Dynamic Type, and
  accessibility projection;
- real floating hierarchy, stable `UITab` identity, continuous manual
  scrolling, page buttons, assigned-bounds resize tracking, Liquid Glass on verified
  versions, and teardown;
- encoded runtime-name decoding and capability guards.

### External product contract

- build, link, and run a separate package importing `.product(name:
  "ScrollableTabBar", package: "ScrollableTabBar")` without `@testable`;
- compile the README/DocC quick-start shape using an unrelated domain ID.

### Demo app and UI tests

- render seven public items in a real `UINavigationController` title view;
- activate a visible tab through an actual touch and observe the app label
  update through `.valueChanged`;
- page to and activate an initially hidden item using an actual gesture;
- run on phone and iPad for compact paging and regular-width presentation;
- retain manual screenshot checks for Liquid Glass, dark mode, and localization.

### Distribution and documentation

- generate DocC with warnings as errors;
- inventory the generated public interface and all `public`/`open`
  declarations;
- run `swift package dump-package`, `git diff --check`, and `actionlint`;
- pin every external GitHub Action to a full commit SHA.

## Findings-to-Design Map

| Finding | Design response |
| --- | --- |
| 1: empty scaffold | Migration items 1 and 3 |
| 2: complete leaf implementation | Single product/target graph |
| 3: minimal public surface | Public API and access-control plan |
| 4: misleading platform gates | iOS-only package and wrapper deletion |
| 5: package tests cover native owners | Package owner test layer |
| 6: app-only runtime evidence remains | Demo app, UI tests, and workspace |
| 7: plain private identifiers | Encoded `PrivateUIKitRuntimeNames` catalog |
| 8: personal runtime prefix | Package-scoped dynamic class name |
| 9: distribution gaps | Contract, docs, license, CI, support matrix |

## Acceptance Criteria

- The standalone package exposes the exact approved public surface and no
  WebInspector types.
- WebInspectorKit's current consumer source compiles unchanged against the
  standalone product in a local compatibility probe.
- Product, target, and dependency graph match this document.
- Package, external contract, and demo UI tests pass on the supported runtime
  matrix.
- DocC and README examples compile using only public API.
- `codex-review` against `main` is clean before opening a Ready PR.

## Design Gate

Implementation begins after approval of these decisions:

1. one iOS-only SwiftPM product and implementation target;
2. unchanged Swift-only generic public API and iOS 18.0 floor;
3. separate external contract package;
4. thin demo app plus UI tests, with a workspace only as the combined developer
   entry point;
5. XOR-obfuscated private selector, KVC, and class-name catalog;
6. package-scoped readable Objective-C runtime subclass name;
7. standalone release first, WebInspectorKit remote exact-pin migration later.
