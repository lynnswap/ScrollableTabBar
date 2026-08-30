# ``ScrollableTabBar``

Present an ordered, typed UIKit selection while keeping overflow items
horizontally reachable.

## Overview

`ScrollableTabBar` is an iOS 18 `UIView` for compact tab selection. Give every
item a stable domain ID and use ``ScrollableTabBarDelegate`` to route user
selection back into application state. The package requires Swift 6.3; the
control has no explicit shutdown operation and follows the containing view
hierarchy's lifetime.

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

The control prefers UIKit's floating-tab presentation when its expected
runtime contract is available. Otherwise, it uses a public UIKit segmented or
menu presentation with the same selection and event semantics.

> Important: The preferred presentation relies on undocumented UIKit APIs and
> runtime behavior. Exact pagination, Liquid Glass appearance, future runtime
> availability, and App Store acceptance are not guaranteed.

Read <doc:SelectionOwnership> before connecting the control to application
state.

## Topics

### Essentials

- <doc:SelectionOwnership>
- ``ScrollableTabBar/ScrollableTabBar``
- ``ScrollableTabBarDelegate``
