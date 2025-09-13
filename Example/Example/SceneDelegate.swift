//
//  SceneDelegate.swift
//  Example
//
//  Created by VAndrJ on 19.08.2025.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    let store = Store()

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let scene = scene as? UIWindowScene else { return }

        window = UIWindow(windowScene: scene)
        window?.rootViewController = UINavigationController(
            rootViewController: ViewController(view: ExampleScreenView(viewModel: ExampleViewModel(store: store)))
        )
        window?.makeKeyAndVisible()
    }
}
