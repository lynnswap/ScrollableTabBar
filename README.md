# ScrollableTabBar

`ScrollableTabBar` is an iOS UIKit control for presenting an ordered selection
whose overflow items remain horizontally reachable.

![ScrollableTabBar showing horizontally scrolling tabs](Docs/Assets/scrollable-tab-bar-demo.gif)

> [!WARNING]
> The preferred floating presentation relies on undocumented UIKit APIs and
> runtime behavior. Its availability, exact Liquid Glass appearance, and App
> Store acceptance are not guaranteed.

## Requirements

- iOS 18.0+
- Swift 6.3+

## State Ownership

The app remains the source of truth for each item's domain identity, membership
and order, selected value, and corresponding content. `ScrollableTabBar`
projects that selection into UIKit. Create a new control when membership or
order changes.

See [Selection Ownership](https://lynnswap.github.io/ScrollableTabBar/documentation/scrollabletabbar/selectionownership/)
for programmatic and user-driven selection behavior.

## Quick Start

```swift
import ScrollableTabBar
import UIKit

@MainActor
final class DashboardViewController: UIViewController, ScrollableTabBarDelegate {
    enum Section: Hashable {
        case summary
        case activity
        case settings
    }

    private var selectedSection: Section = .summary

    private lazy var sectionControl: ScrollableTabBar<Section> = {
        let control = ScrollableTabBar(
            items: [
                .init(id: .summary, title: "Summary"),
                .init(id: .activity, title: "Activity"),
                .init(
                    id: .settings,
                    title: "Settings",
                    image: UIImage(systemName: "gear")
                ),
            ],
            selectedID: selectedSection
        )
        control.accessibilityLabel = "Dashboard Section"
        control.delegate = self
        return control
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.titleView = sectionControl
        showSection(selectedSection)
    }

    func scrollableTabBar(
        _ tabBar: ScrollableTabBar<Section>,
        didSelect selectedID: Section
    ) {
        selectedSection = selectedID
        showSection(selectedID)
    }

    private func showSection(_ section: Section) {
        // Render application content for `section`.
    }
}
```

## Presentation

When its expected UIKit runtime contract is available, the control uses the
system floating-tab presentation. Otherwise, a public UIKit fallback preserves
selection, ordering, enablement, and event semantics. Exact layout and
appearance are not API guarantees.

## Testing

Run package tests on an iOS Simulator:

```sh
xcodebuild test \
  -workspace ScrollableTabBar.xcworkspace \
  -scheme ScrollableTabBarTests \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'
```

Run the external public-product contract from its separate package:

```sh
cd ContractTests
xcodebuild test \
  -scheme ScrollableTabBarProductContract-Package \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'
```

## Documentation

- [ScrollableTabBar Documentation](https://lynnswap.github.io/ScrollableTabBar/documentation/scrollabletabbar/)

## License

ScrollableTabBar is available under the MIT License. See [LICENSE](LICENSE).
