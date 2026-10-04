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

    private var sections = Section.allCases
    private var selectedSection: Section? = .overview
    private lazy var sectionControl = ScrollableTabBar<Section>()

    private let selectionLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "ScrollableTabBar"
        view.backgroundColor = .systemGroupedBackground

        sectionControl.accessibilityIdentifier = "ScrollableTabBarDemo.Control"
        sectionControl.accessibilityLabel = "Inspector section"
        sectionControl.delegate = self
        sectionControl.sizeToFit()
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

        let addButton = UIButton(
            type: .system,
            primaryAction: UIAction(title: "Add tab") { [weak self] _ in
                guard let self,
                    let section = Section.allCases.first(where: { !sections.contains($0) })
                else { return }
                sections.append(section)
                selectedSection = section
                updateTabs()
            })
        addButton.accessibilityIdentifier = "ScrollableTabBarDemo.AddTab"
        let removeButton = UIButton(
            type: .system,
            primaryAction: UIAction(title: "Remove selected tab") { [weak self] _ in
                guard let self, let selectedSection else { return }
                sections.removeAll { $0 == selectedSection }
                self.selectedSection = sections.first
                updateTabs()
            })
        removeButton.accessibilityIdentifier = "ScrollableTabBarDemo.RemoveTab"
        let clearButton = UIButton(
            type: .system,
            primaryAction: UIAction(title: "Remove all tabs") { [weak self] _ in
                guard let self else { return }
                sections.removeAll()
                selectedSection = nil
                updateTabs()
            })
        clearButton.accessibilityIdentifier = "ScrollableTabBarDemo.ClearTabs"
        let reverseButton = UIButton(
            type: .system,
            primaryAction: UIAction(title: "Reverse tabs") { [weak self] _ in
                guard let self else { return }
                sections.reverse()
                updateTabs()
            })
        reverseButton.accessibilityIdentifier = "ScrollableTabBarDemo.ReverseTabs"
        let clearSelectionButton = UIButton(
            type: .system,
            primaryAction: UIAction(title: "Clear selection") { [weak self] _ in
                guard let self else { return }
                selectedSection = nil
                updateTabs()
            })
        clearSelectionButton.accessibilityIdentifier = "ScrollableTabBarDemo.ClearSelection"
        let stackView = UIStackView(arrangedSubviews: [
            headingLabel,
            instructionsLabel,
            selectionLabel,
            addButton,
            removeButton,
            reverseButton,
            clearSelectionButton,
            clearButton,
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

        updateTabs()
    }

    func scrollableTabBar(
        _ tabBar: ScrollableTabBar<Section>,
        didSelect selectedID: Section
    ) {
        selectedSection = selectedID
        renderSelection(selectedID)
    }

    private func updateTabs() {
        let items = sections.map { section in
            ScrollableTabBar<Section>.Item(
                id: section,
                title: section.title,
                accessibilityIdentifier: section.accessibilityIdentifier
            )
        }
        sectionControl.setItems(items, selectedID: selectedSection)
        renderSelection(selectedSection)
    }

    private func renderSelection(_ selectedID: Section?) {
        let title = selectedID?.title ?? "None"
        selectionLabel.text = "Selected: \(title)"
        selectionLabel.accessibilityValue = title
    }
}

#Preview {
    UINavigationController(
        rootViewController: ScrollableTabBarDemoViewController()
    )
}
