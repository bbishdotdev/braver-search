//
//  AppDelegate.swift
//  Braver Search
//
//  Created by Brenden Bishop on 1/19/25.
//

import Foundation
import Security
import StoreKit
import UIKit

enum IOSAppAnalytics {
    static func sharedDefaults() -> UserDefaults { DurableAnalytics.defaults }
    static func initializeSharedState(bundle: Bundle = .main) { DurableAnalytics.configure() }
    static func track(_ event: String, properties: [String: Any] = [:]) {
        DurableAnalytics.shared.capture(event, properties: properties)
    }
    static func trackFirstAppOpenIfNeeded() {
        // Preserve the legacy install cohort; upgrades must not become new installs.
        guard !sharedDefaults().bool(forKey: "hasTrackedFirstAppOpen") else { return }
        DurableAnalytics.shared.capture("first_app_open", once: "first_app_open") { accepted in
            if accepted { sharedDefaults().set(true, forKey: "hasTrackedFirstAppOpen") }
        }
    }
}

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        IOSAppAnalytics.initializeSharedState()
        IOSAppAnalytics.trackFirstAppOpenIfNeeded()
        IOSAppAnalytics.track("app_opened")
        MonetizationManager.shared.configureIfNeeded()
        Task {
            await MonetizationManager.shared.resolveUserState()
            await StoreManager.shared.loadProductsIfNeeded()
        }
        return true
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

}
