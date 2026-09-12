//
//  AppDelegate.swift
//  macOS (App)
//
//  Created by Brenden Bishop on 1/18/25.
//

import Cocoa
import Foundation
import Security
import StoreKit

enum MacAppAnalytics {
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
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        MacAppAnalytics.initializeSharedState()
        MacAppAnalytics.trackFirstAppOpenIfNeeded()
        MacAppAnalytics.track("app_opened")
        MonetizationManager.shared.configureIfNeeded()
        Task {
            await MonetizationManager.shared.resolveUserState()
            await StoreManager.shared.loadProductsIfNeeded()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard urls.contains(where: { $0.scheme?.lowercased() == "braversearch" && $0.host?.lowercased() == "support" }) else {
            return
        }

        MonetizationManager.shared.openSupportFlow()
        NSApp.activate(ignoringOtherApps: true)
    }

}
