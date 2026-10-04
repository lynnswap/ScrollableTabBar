import ScrollableTabBar
import Testing
import UIKit

private enum ContractWorkspaceSection: Hashable {
    case canvas
    case activity
    case settings
}

@MainActor
@Test
func publicProductSupportsTypedSelectionAndDelegateCallbacks() {
    let viewController = ContractWorkspaceViewController()
    viewController.loadViewIfNeeded()
    let control = viewController.sectionControl

    #expect(control.items.map(\.id) == [.canvas, .activity, .settings])
    #expect(control.items.last?.accessibilityIdentifier == "Contract.Workspace.Settings")
    #expect(control.selectedID == .canvas)
    #expect(control.delegate === viewController)
    #expect(viewController.navigationItem.titleView === control)
    #expect(viewController.renderedSection == .canvas)

    control.selectedID = .settings

    #expect(control.selectedID == .settings)
    #expect(viewController.delegateCallCount == 0)
    #expect(viewController.renderedSection == .canvas)
    #expect(control.isEnabled)

    control.isEnabled = false
    #expect(control.isEnabled == false)
}

@MainActor
@Test
func publicProductSupportsDynamicItemsAndNoSelection() {
    let control = ScrollableTabBar<ContractWorkspaceSection>()
    #expect(control.items.isEmpty)
    #expect(control.selectedID == nil)

    var items: [ScrollableTabBar<ContractWorkspaceSection>.Item] = [
        .init(id: .canvas, title: "Canvas"),
        .init(id: .activity, title: "Activity"),
    ]
    control.setItems(items, selectedID: .activity)
    items.removeAll { $0.id == .activity }
    items[0].title = "Workspace"
    items.append(.init(id: .settings, title: "Settings"))
    control.setItems(items, selectedID: .settings)
    #expect(control.items.map(\.id) == [.canvas, .settings])
    #expect(control.items.first?.title == "Workspace")
    #expect(control.selectedID == .settings)

    control.selectedID = nil
    #expect(control.selectedID == nil)
    control.setItems([], selectedID: nil)
    #expect(control.items.isEmpty)
    #expect(control.selectedID == nil)
}

@MainActor
private final class ContractWorkspaceViewController: UIViewController,
    ScrollableTabBarDelegate
{
    private var selectedSection: ContractWorkspaceSection = .canvas
    private(set) var renderedSection: ContractWorkspaceSection?
    private(set) var delegateCallCount = 0

    lazy var sectionControl: ScrollableTabBar<ContractWorkspaceSection> = {
        let control = ScrollableTabBar(
            items: [
                .init(
                    id: .canvas,
                    title: "Canvas",
                    accessibilityIdentifier: "Contract.Workspace.Canvas"
                ),
                .init(
                    id: .activity,
                    title: "Activity",
                    accessibilityIdentifier: "Contract.Workspace.Activity"
                ),
                .init(
                    id: .settings,
                    title: "Settings",
                    image: UIImage(systemName: "gear"),
                    accessibilityIdentifier: "Contract.Workspace.Settings"
                ),
            ],
            selectedID: selectedSection
        )
        control.delegate = self
        return control
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.titleView = sectionControl
        render(selectedSection)
    }

    func scrollableTabBar(
        _ tabBar: ScrollableTabBar<ContractWorkspaceSection>,
        didSelect selectedID: ContractWorkspaceSection
    ) {
        delegateCallCount += 1
        selectedSection = selectedID
        render(selectedID)
    }

    private func render(_ section: ContractWorkspaceSection) {
        renderedSection = section
    }
}
