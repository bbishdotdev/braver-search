//
//  SceneDelegate.swift
//  Braver Search
//
//  Created by Brenden Bishop on 1/19/25.
//

import UIKit
import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UIHostingController(rootView: MainView())
        self.window = window
        window.makeKeyAndVisible()

        if let url = connectionOptions.urlContexts.first?.url {
            handle(url: url)
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else {
            return
        }

        handle(url: url)
    }

    private func handle(url: URL) {
        guard url.scheme?.lowercased() == "braversearch", url.host?.lowercased() == "support" else {
            return
        }

        DispatchQueue.main.async {
            MonetizationManager.shared.openSupportFlow()
        }
    }
}
