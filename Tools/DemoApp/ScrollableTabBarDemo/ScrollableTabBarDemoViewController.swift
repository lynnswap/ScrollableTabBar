import ScrollableTabBar
import UIKit

@MainActor
final class ScrollableTabBarDemoViewController: UIViewController,
    ScrollableTabBarDelegate
{
    enum Section: String, CaseIterable {
        case overview
        case headers
        case preview
        case cookies
        case security
        case timing
        case response

        var title: String {
            switch self {
            case .overview:
                "Overview"
            case .headers:
                "Headers"
            case .preview:
                "Preview"
            case .cookies:
                "Cookies"
            case .security:
                "Security"
            case .timing:
                "Timing"
            case .response:
                "Response"
            }
        }

        var accessibilityIdentifier: String {
            "ScrollableTabBarDemo.Tab.\(rawValue)"
        }
    }

    private lazy var sectionControl = ScrollableTabBar(
        items: Section.allCases.map { section in
            .init(
                id: section,
                title: section.title,
                accessibilityIdentifier: section.accessibilityIdentifier
            )
        },
        selectedID: Section.overview
    )

    private let selectionLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "ScrollableTabBar"
        view.backgroundColor = .systemGroupedBackground

        sectionControl.accessibilityIdentifier = "ScrollableTabBarDemo.Control"
        sectionControl.accessibilityLabel = "Inspector section"
        sectionControl.delegate = self
        navigationItem.titleView = sectionControl
        let doneItem = UIBarButtonItem(
            primaryAction: UIAction(
                title: "Done",
                image: UIImage(systemName: "checkmark")
            ) { _ in }
        )
        doneItem.accessibilityIdentifier = "ScrollableTabBarDemo.Done"
        navigationItem.rightBarButtonItem = doneItem

        let headingLabel = UILabel()
        headingLabel.font = .preferredFont(forTextStyle: .title1)
        headingLabel.adjustsFontForContentSizeCategory = true
        headingLabel.text = "ScrollableTabBar"

        let instructionsLabel = UILabel()
        instructionsLabel.font = .preferredFont(forTextStyle: .body)
        instructionsLabel.adjustsFontForContentSizeCategory = true
        instructionsLabel.numberOfLines = 0
        instructionsLabel.text = "Select a tab or swipe the floating tab bar to reach overflow items."

        selectionLabel.font = .preferredFont(forTextStyle: .title2)
        selectionLabel.adjustsFontForContentSizeCategory = true
        selectionLabel.accessibilityIdentifier = "ScrollableTabBarDemo.SelectionLabel"

        let stackView = UIStackView(arrangedSubviews: [
            headingLabel,
            instructionsLabel,
            selectionLabel,
        ])
        stackView.axis = .vertical
        stackView.alignment = .leading
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.leadingAnchor,
                constant: 24
            ),
            stackView.trailingAnchor.constraint(
                lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor,
                constant: -24
            ),
            stackView.centerYAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.centerYAnchor
            ),
        ])

        renderSelection(sectionControl.selectedID)
    }

    func scrollableTabBar(
        _ tabBar: ScrollableTabBar<Section>,
        didSelect selectedID: Section
    ) {
        renderSelection(selectedID)
    }

    private func renderSelection(_ selectedID: Section) {
        let title = selectedID.title
        selectionLabel.text = "Selected: \(title)"
        selectionLabel.accessibilityValue = title
    }
}

#Preview {
    UINavigationController(
        rootViewController: ScrollableTabBarDemoViewController()
    )
}
