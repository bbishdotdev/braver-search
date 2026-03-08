//
//  AppDelegate.swift
//  macOS (App)
//
//  Created by Brenden Bishop on 1/18/25.
//

import Cocoa
import Foundation
import Security

enum MacAppAnalytics {
    static let baseGroupIdentifier = "group.xyz.bsquared.braversearch"
    private static let enabledKey = "enabled"
    private static let searchURLKey = "searchUrl"
    private static let anonymousIDKey = "analyticsAnonymousID"
    private static let firstAppOpenTrackedKey = "hasTrackedFirstAppOpen"
    private static let postHogAPIKeyKey = "posthogAPIKey"
    private static let postHogHostKey = "posthogHost"
    private static let defaultSearchURL = "https://search.brave.com/search?q="
    private static let defaultPostHogHost = "https://us.i.posthog.com"
    private static let postHogAPIKeyInfoKey = "POSTHOG_API_KEY"
    private static let postHogHostInfoKey = "POSTHOG_HOST"
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
        if let appGroupIdentifier = resolvedAppGroupIdentifier(),
           let defaults = UserDefaults(suiteName: appGroupIdentifier) {
            return defaults
        }

        return UserDefaults(suiteName: baseGroupIdentifier)!
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

    static func initializeSharedState(bundle: Bundle = .main) {
        let defaults = sharedDefaults()

        if defaults.object(forKey: enabledKey) == nil {
            defaults.set(true, forKey: enabledKey)
        }

        if defaults.string(forKey: searchURLKey)?.isEmpty != false {
            defaults.set(defaultSearchURL, forKey: searchURLKey)
        }

        if defaults.string(forKey: anonymousIDKey)?.isEmpty != false {
            defaults.set(UUID().uuidString, forKey: anonymousIDKey)
        }

        let apiKey = (bundle.object(forInfoDictionaryKey: postHogAPIKeyInfoKey) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let host = (bundle.object(forInfoDictionaryKey: postHogHostInfoKey) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? defaultPostHogHost

        defaults.set(apiKey, forKey: postHogAPIKeyKey)
        defaults.set(host.isEmpty ? defaultPostHogHost : host, forKey: postHogHostKey)
    }

    static func track(_ event: String, properties: [String: Any] = [:]) {
        let defaults = sharedDefaults()
        guard let apiKey = defaults.string(forKey: postHogAPIKeyKey), !apiKey.isEmpty else {
            return
        }

        let host = defaults.string(forKey: postHogHostKey) ?? defaultPostHogHost
        let anonymousID = defaults.string(forKey: anonymousIDKey) ?? UUID().uuidString
        defaults.set(anonymousID, forKey: anonymousIDKey)

        guard let url = URL(string: "\(host)/capture/") else {
            return
        }

        var payloadProperties: [String: Any] = [
            "distinct_id": anonymousID,
            "$process_person_profile": false,
            "platform": "macos",
            "source": "host_app",
            "app_version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
        ]

        properties.forEach { payloadProperties[$0.key] = $0.value }

        let payload: [String: Any] = [
            "api_key": apiKey,
            "event": event,
            "properties": payloadProperties,
        ]

        guard JSONSerialization.isValidJSONObject(payload),
              let body = try? JSONSerialization.data(withJSONObject: payload) else {
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        session.dataTask(with: request).resume()
    }

    static func trackFirstAppOpenIfNeeded() {
        let defaults = sharedDefaults()
        guard !defaults.bool(forKey: firstAppOpenTrackedKey) else {
            return
        }

        defaults.set(true, forKey: firstAppOpenTrackedKey)
        track("first_app_open")
    }
}

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        MacAppAnalytics.initializeSharedState()
        MacAppAnalytics.trackFirstAppOpenIfNeeded()
        MacAppAnalytics.track("app_opened")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

}
