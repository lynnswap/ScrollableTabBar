import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else {
            return
        }

        let rootViewController = UIViewController()
        rootViewController.title = "Demo"
        rootViewController.view.backgroundColor = .systemBackground

        let navigationController = UINavigationController(
            rootViewController: rootViewController
        )
        navigationController.pushViewController(
            ViewController(),
            animated: false
        )

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = navigationController
        self.window = window
        window.makeKeyAndVisible()
    }
}
