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

enum ExtensionAnalytics {
    static let baseGroupIdentifier = "group.xyz.bsquared.braversearch"
    private static let anonymousIDKey = "analyticsAnonymousID"
    private static let postHogAPIKeyKey = "posthogAPIKey"
    private static let postHogHostKey = "posthogHost"
    private static let postHogAPIKeyInfoKey = "POSTHOG_API_KEY"
    private static let postHogHostInfoKey = "POSTHOG_HOST"
    private static let defaultPostHogHost = "https://us.i.posthog.com"
    private static let cacheLock = NSLock()
    private static var cachedDefaults: UserDefaults?
    private static var cachedAnonymousID: String?
    private static var cachedAPIKey: String?
    private static var cachedAPIKeyResolved = false
    private static var cachedHost: String?
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 1.5
        configuration.timeoutIntervalForResource = 3
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }()

    static func sharedDefaults() -> UserDefaults {
        if let cachedDefaults = withLock({ cachedDefaults }) {
            return cachedDefaults
        }

        let resolvedDefaults: UserDefaults
        if let appGroupIdentifier = resolvedAppGroupIdentifier(),
           let defaults = UserDefaults(suiteName: appGroupIdentifier) {
            resolvedDefaults = defaults
        } else {
            resolvedDefaults = UserDefaults(suiteName: baseGroupIdentifier)!
        }

        withLock {
            cachedDefaults = resolvedDefaults
        }

        return resolvedDefaults
    }

    private static func resolvedAppGroupIdentifier() -> String? {
        #if os(iOS)
        return baseGroupIdentifier
        #else
        guard let task = SecTaskCreateFromSelf(nil),
              let value = SecTaskCopyValueForEntitlement(
                task,
                "com.apple.security.application-groups" as CFString,
                nil
              ) else {
            return nil
        }

        return (value as? [String])?.first
        #endif
    }

    static func track(_ event: String, properties: [String: Any] = [:]) -> [String: Any] {
        let defaults = sharedDefaults()
        let host = configuredHost(defaults: defaults)
        guard let apiKey = configuredAPIKey(defaults: defaults), !apiKey.isEmpty else {
            return [
                "accepted": false,
                "hasAPIKey": false,
                "host": host,
            ]
        }

        let anonymousID = configuredAnonymousID(defaults: defaults)

        guard let url = URL(string: "\(host)/capture/") else {
            return [
                "accepted": false,
                "hasAPIKey": true,
                "host": host,
            ]
        }

        var payloadProperties: [String: Any] = [
            "distinct_id": anonymousID,
            "$process_person_profile": false,
            "source": "safari_extension",
            "app_version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
        ]

        #if os(iOS)
        payloadProperties["platform"] = "ios"
        #elseif os(macOS)
        payloadProperties["platform"] = "macos"
        #endif

        properties.forEach { payloadProperties[$0.key] = $0.value }

        let payload: [String: Any] = [
            "api_key": apiKey,
            "event": event,
            "properties": payloadProperties,
        ]

        guard JSONSerialization.isValidJSONObject(payload),
              let body = try? JSONSerialization.data(withJSONObject: payload) else {
            return [
                "accepted": false,
                "hasAPIKey": true,
                "host": host,
            ]
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        session.dataTask(with: request) { _, response, error in
            if let error = error {
                NSLog("Braver Search: PostHog request failed for %@: %@", event, error.localizedDescription)
                return
            }

            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            debugLog("Braver Search: PostHog request completed for \(event) with status \(statusCode)")
        }.resume()

        return [
            "accepted": true,
            "hasAPIKey": true,
            "host": host,
        ]
    }

    private static func configuredAPIKey(defaults: UserDefaults, bundle: Bundle = .main) -> String? {
        let cachedValue = withLock { () -> (Bool, String?) in
            (cachedAPIKeyResolved, cachedAPIKey)
        }
        if cachedValue.0 {
            return cachedValue.1
        }

        if let apiKey = defaults.string(forKey: postHogAPIKeyKey), !apiKey.isEmpty {
            withLock {
                cachedAPIKey = apiKey
                cachedAPIKeyResolved = true
            }
            return apiKey
        }

        let apiKey = (bundle.object(forInfoDictionaryKey: postHogAPIKeyInfoKey) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let apiKey, !apiKey.isEmpty {
            defaults.set(apiKey, forKey: postHogAPIKeyKey)
            withLock {
                cachedAPIKey = apiKey
                cachedAPIKeyResolved = true
            }
            return apiKey
        }

        withLock {
            cachedAPIKey = nil
            cachedAPIKeyResolved = true
        }
        return nil
    }

    private static func configuredHost(defaults: UserDefaults, bundle: Bundle = .main) -> String {
        if let cachedHost = withLock({ cachedHost }) {
            return cachedHost
        }

        if let host = defaults.string(forKey: postHogHostKey), !host.isEmpty {
            withLock {
                cachedHost = host
            }
            return host
        }

        let host = (bundle.object(forInfoDictionaryKey: postHogHostInfoKey) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let resolvedHost = (host?.isEmpty == false) ? host! : defaultPostHogHost
        defaults.set(resolvedHost, forKey: postHogHostKey)
        withLock {
            cachedHost = resolvedHost
        }
        return resolvedHost
    }

    private static func configuredAnonymousID(defaults: UserDefaults) -> String {
        if let cachedAnonymousID = withLock({ cachedAnonymousID }) {
            return cachedAnonymousID
        }

        let anonymousID = defaults.string(forKey: anonymousIDKey) ?? UUID().uuidString
        defaults.set(anonymousID, forKey: anonymousIDKey)
        withLock {
            cachedAnonymousID = anonymousID
        }
        return anonymousID
    }

    private static func withLock<T>(_ body: () -> T) -> T {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return body()
    }
}

@available(macOS 11.0, iOS 15.0, *)
class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {
    func beginRequest(with context: NSExtensionContext) {
        debugLog("Braver Search: Begin request")
        
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
                        let trackResult = ExtensionAnalytics.track(event, properties: message.properties)
                        sendResponse(
                            [
                                "ok": true,
                                "type": message.type,
                                "event": event,
                                "analytics": trackResult,
                            ],
                            context: context
                        )
                        return
                    }
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
