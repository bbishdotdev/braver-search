//
//  SafariWebExtensionHandler.swift
//  Braver Search Extension
//
//  Created by Brenden Bishop on 1/19/25.
//

import SafariServices
import os.log
import Foundation
import Security

private let extensionDebugLogging = false

private func debugLog(_ message: String) {
    guard extensionDebugLogging else {
        return
    }

    NSLog("%@", message)
}

struct Message {
    let type: String
    let enabled: Bool?
    let event: String?
    let properties: [String: Any]

    init?(dictionary: [String: Any]) {
        guard let type = dictionary["type"] as? String else {
            return nil
        }

        self.type = type
        self.enabled = dictionary["enabled"] as? Bool
        self.event = dictionary["event"] as? String
        self.properties = dictionary["properties"] as? [String: Any] ?? [:]
    }
}

private enum ExtensionMonetizationKeys {
    static let userState = "monetization.userState"
    static let redirectCount = "monetization.redirectCount"
    static let hasDonated = "monetization.hasDonated"
    static let unknownState = "unknown"
    static let grandfatheredState = "grandfathered"
    static let reviewURL = "https://apps.apple.com/app/id6740840706?action=write-review"
    static let supportURL = "braversearch://support"
}

private enum ExtensionSetupKeys {
    static let hasSeenExtensionRuntime = "hasSeenExtensionRuntime"
    static let extensionRuntimeLastSeenAt = "extensionRuntimeLastSeenAt"
}

enum ExtensionAnalytics {
    static func sharedDefaults() -> UserDefaults { DurableAnalytics.defaults }
}

@available(macOS 11.0, iOS 15.0, *)
class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {
    func beginRequest(with context: NSExtensionContext) {
        debugLog("Braver Search: Begin request")
        DurableAnalytics.configure()
        AccessRefresh.schedule()
        
        let userDefaults = ExtensionAnalytics.sharedDefaults()
        var currentEnabled = userDefaults.bool(forKey: "enabled")
        
        // Parse incoming message
        if let item = context.inputItems.first as? NSExtensionItem,
           let userInfo = item.userInfo {
            let rawMessage = userInfo[SFExtensionMessageKey]

            debugLog("Braver Search: Received message: \(String(describing: rawMessage))")

            if let dictionary = rawMessage as? [String: Any],
               let message = Message(dictionary: dictionary) {
                debugLog("Braver Search: Message type: \(message.type)")
                
                switch message.type {
                case "getRedirectAccess":
                    let decision = AccessStore.decision()
                    let testID = message.properties["test_id"] as? String ?? ""
                    let diagnostic = message.properties["setup_query"] as? Bool == true && SetupCheck.isActive(id: testID)
                    sendResponse(["allowed": decision.allowsRedirects || diagnostic, "state": decision.state.rawValue], context: context)
                    if !decision.allowsRedirects && !diagnostic {
                        DurableAnalytics.shared.capture("redirect_access_blocked", properties: ["access_state": decision.state.rawValue], once: "access_block_\(decision.state.rawValue)_\(Int(Date().timeIntervalSince1970 / 86400))")
                    }
                    return
                case "setupTestProgress":
                    let accepted = SetupCheck.recordProgress(
                        id: message.properties["test_id"] as? String ?? "",
                        stage: message.properties["stage"] as? String ?? "",
                        enabled: message.properties["enabled"] as? Bool
                    )
                    sendResponse(["ok": accepted], context: context)
                    return
                case "setupTestCompleted":
                    let id = message.properties["test_id"] as? String ?? ""
                    sendResponse(["ok": SetupCheck.complete(id: id)], context: context)
                    return
                case "runtimeObserved":
                    userDefaults.set(true, forKey: ExtensionSetupKeys.hasSeenExtensionRuntime)
                    userDefaults.set(Date().timeIntervalSince1970, forKey: ExtensionSetupKeys.extensionRuntimeLastSeenAt)
                    let day = Int(Date().timeIntervalSince1970 / 86400)
                    DurableAnalytics.shared.capture("extension_runtime_observed", once: "runtime_\(day)") { accepted in
                        self.sendResponse(["ok": accepted], context: context)
                    }
                    return
                case "setState":
                    if let newState = message.enabled {
                        debugLog("Braver Search: Setting new state: \(newState)")
                        userDefaults.set(newState, forKey: "enabled")
                        userDefaults.synchronize()
                        currentEnabled = newState
                    }
                    let settings = Settings(
                        enabled: currentEnabled,
                        searchUrl: "https://search.brave.com/search?q="
                    )
                    sendResponse(
                        [
                            "enabled": settings.enabled,
                            "searchUrl": settings.searchUrl,
                        ],
                        context: context
                    )
                    return
                case "trackEvent":
                    if let event = message.event {
                        if event == "extension_activated" || event == "extension_popup_opened" || event == "search_redirected" {
                            userDefaults.set(true, forKey: ExtensionSetupKeys.hasSeenExtensionRuntime)
                            userDefaults.set(Date().timeIntervalSince1970, forKey: ExtensionSetupKeys.extensionRuntimeLastSeenAt)
                        }

                        if event == "search_redirected" {
                            userDefaults.set(userDefaults.integer(forKey: ExtensionMonetizationKeys.redirectCount) + 1, forKey: ExtensionMonetizationKeys.redirectCount)
                        }
                        let once = event == "extension_activated" ? "extension_activated" : nil
                        DurableAnalytics.shared.capture(event, properties: message.properties, once: once) { accepted in
                            self.sendResponse([
                                "ok": accepted, "analytics": ["accepted": accepted, "durablyQueued": accepted]
                            ], context: context)
                        }
                        return
                    }
                case "getMonetizationState":
                    let decision = AccessStore.decision()
                    let userState = decision.state.rawValue
                    let canTip = decision.state.canTip
                    sendResponse(
                        [
                            "userState": userState,
                            "accessAllowed": decision.allowsRedirects,
                            "accessTitle": decision.title,
                            "accessMessage": decision.message,
                            "canTip": canTip,
                            "hasDonated": userDefaults.bool(forKey: ExtensionMonetizationKeys.hasDonated),
                            "reviewURL": ExtensionMonetizationKeys.reviewURL,
                            "supportURL": ExtensionMonetizationKeys.supportURL,
                        ],
                        context: context
                    )
                    return
                case "getState":
                    debugLog("Braver Search: Getting current state")
                    let settings = Settings(
                        enabled: currentEnabled,
                        searchUrl: "https://search.brave.com/search?q="
                    )
                    sendResponse(
                        [
                            "enabled": settings.enabled,
                            "searchUrl": settings.searchUrl,
                        ],
                        context: context
                    )
                    return
                default:
                    debugLog("Braver Search: Unknown message type")
                }
            }
        }
        
        #if os(macOS)
        // On macOS, check Safari's extension state
        SFSafariExtensionManager.getStateOfSafariExtension(
            withIdentifier: "xyz.bsquared.braversearch.Braver-Search-Extension"
        ) { state, error in
            if let error = error {
                NSLog("Braver Search: Error getting extension state: %@", error.localizedDescription)
                return
            }
            
            if let state = state {
                debugLog("Braver Search: Extension enabled in Safari: \(state.isEnabled)")
            }
        }
        #endif
        
        let settings = Settings(
            enabled: currentEnabled,
            searchUrl: "https://search.brave.com/search?q="
        )

        sendResponse(
            [
                "enabled": settings.enabled,
                "searchUrl": settings.searchUrl,
            ],
            context: context
        )
    }
    
    private func sendResponse(_ response: [String: Any], context: NSExtensionContext) {
        debugLog("Braver Search: Sending response: \(String(describing: response))")
        let extensionItem = NSExtensionItem()
        extensionItem.userInfo = [ SFExtensionMessageKey: response ]
        context.completeRequest(returningItems: [extensionItem], completionHandler: nil)
    }
}

private struct Settings {
    let enabled: Bool
    let searchUrl: String
}

/// Refresh StoreKit independently of search navigation; cache is re-evaluated for expiry on every search.
private enum AccessRefresh {
    private static let lock = NSLock()
    private static var lastRefresh = Date.distantPast
    static func schedule() {
        lock.lock()
        guard Date().timeIntervalSince(lastRefresh) > 300 else { lock.unlock(); return }
        lastRefresh = Date()
        lock.unlock()
        Task { await AccessStore.refreshExtension() }
    }
}
