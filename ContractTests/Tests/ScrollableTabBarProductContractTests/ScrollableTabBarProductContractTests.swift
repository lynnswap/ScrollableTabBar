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
func publicProductSupportsTypedSelectionAndUIControlEvents() {
    let viewController = ContractWorkspaceViewController()
    viewController.loadViewIfNeeded()
    let control = viewController.sectionControl
    let recorder = ContractSelectionRecorder()
    control.addTarget(
        recorder,
        action: #selector(ContractSelectionRecorder.valueChanged),
        for: .valueChanged
    )

    #expect(control.items.map(\.id) == [.canvas, .activity, .settings])
    #expect(control.items.last?.accessibilityIdentifier == "Contract.Workspace.Settings")
    #expect(control.selectedID == .canvas)
    #expect(viewController.navigationItem.titleView === control)
    #expect(viewController.renderedSection == .canvas)

    control.selectedID = .settings

    #expect(control.selectedID == .settings)
    #expect(recorder.eventCount == 0)
    #expect(viewController.renderedSection == .canvas)
    #expect(control.isEnabled)

    control.isEnabled = false
    #expect(control.isEnabled == false)
}

@MainActor
private final class ContractWorkspaceViewController: UIViewController {
    private var selectedSection: ContractWorkspaceSection = .canvas
    private(set) var renderedSection: ContractWorkspaceSection?

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
        control.addTarget(
            self,
            action: #selector(sectionSelectionChanged),
            for: .valueChanged
        )
        return control
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.titleView = sectionControl
        render(selectedSection)
    }

    @objc private func sectionSelectionChanged() {
        selectedSection = sectionControl.selectedID
        render(selectedSection)
    }

    private func render(_ section: ContractWorkspaceSection) {
        renderedSection = section
    }
}

@MainActor
private final class ContractSelectionRecorder: NSObject {
    private(set) var eventCount = 0

    @objc func valueChanged() {
        eventCount += 1
    }
}
