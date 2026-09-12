import Foundation
import Security
import Darwin

/// Shared by the host and native extension. No search text or visited URLs are collected.
final class DurableAnalytics {
    static let groupIdentifier: String = {
        #if os(macOS)
        if let task = SecTaskCreateFromSelf(nil),
           let value = SecTaskCopyValueForEntitlement(task, "com.apple.security.application-groups" as CFString, nil),
           let group = (value as? [String])?.first { return group }
        #endif
        return "group.xyz.bsquared.braversearch"
    }()
    static let defaults = UserDefaults(suiteName: groupIdentifier)!
    static let shared = DurableAnalytics(
        directory: FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupIdentifier)?
            .appendingPathComponent("Telemetry-v2", isDirectory: true)
    )

    private let defaults: UserDefaults
    private let directory: URL?
    private let worker = DispatchQueue(label: "xyz.bsquared.braversearch.telemetry", qos: .utility)
    private let session: URLSession
    private var sending = false
    private var wakeup: DispatchWorkItem?

    init(directory: URL?, session: URLSession? = nil, defaults: UserDefaults = DurableAnalytics.defaults) {
        self.defaults = defaults
        self.directory = directory
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        config.httpCookieStorage = nil
        config.urlCache = nil
        self.session = session ?? URLSession(configuration: config)
    }

    static func configure() {
        let defaults = Self.defaults
        if defaults.object(forKey: "enabled") == nil { defaults.set(true, forKey: "enabled") }
        if defaults.string(forKey: "searchUrl") == nil { defaults.set("https://search.brave.com/search?q=", forKey: "searchUrl") }
        // A build without credentials must never erase configuration shared by another target.
        for (info, key) in [("POSTHOG_API_KEY", "posthogAPIKey"), ("POSTHOG_HOST", "posthogHost")] {
            if let value = Bundle.main.object(forInfoDictionaryKey: info) as? String,
               !value.isEmpty, !value.contains("$(") { defaults.set(value, forKey: key) }
        }
        shared.flush()
    }

    /// `accepted` means durably stored, never that the server has received it.
    func capture(_ event: String, properties: [String: Any] = [:], once: String? = nil, timestamp: Date = Date(),
                 completion: ((Bool) -> Void)? = nil) {
        worker.async {
            var accepted = false
            do {
                try self.locked { root in
                    let queue = root.appendingPathComponent("queue", isDirectory: true)
                    let receipts = root.appendingPathComponent("milestones", isDirectory: true)
                    try FileManager.default.createDirectory(at: queue, withIntermediateDirectories: true)
                    try FileManager.default.createDirectory(at: receipts, withIntermediateDirectories: true)
                    let receipt = once.map { receipts.appendingPathComponent($0 + ".json") }
                    if let receipt, FileManager.default.fileExists(atPath: receipt.path) { accepted = true; return }
                    let file = queue.appendingPathComponent((once ?? UUID().uuidString) + ".json")
                    // If a process died between the event write and milestone write, finish the same transaction.
                    if !FileManager.default.fileExists(atPath: file.path) {
                        guard try FileManager.default.contentsOfDirectory(atPath: queue.path).count < 10_000 else { return }
                        let identityFile = root.appendingPathComponent("identity")
                        let identity: String
                        if let saved = try? String(contentsOf: identityFile, encoding: .utf8) { identity = saved }
                        else {
                            identity = self.defaults.string(forKey: "analyticsAnonymousID") ?? UUID().uuidString
                            try identity.write(to: identityFile, atomically: true, encoding: .utf8)
                            self.defaults.set(identity, forKey: "analyticsAnonymousID")
                        }
                        var props = properties
                        props["distinct_id"] = identity
                        props["$process_person_profile"] = false
                        props["analytics_version"] = 2
                        props["app_version"] = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
                        props["source"] = Bundle.main.bundleURL.pathExtension == "appex" ? "safari_extension" : "host_app"
                        #if os(iOS)
                        props["platform"] = "ios"
                        #else
                        props["platform"] = "macos"
                        #endif
                        #if DEBUG
                        props["environment"] = "development"
                        #else
                        props["environment"] = "production"
                        #endif
                        let formatter = ISO8601DateFormatter()
                        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                        let payload: [String: Any] = ["event": event, "uuid": UUID().uuidString,
                            "timestamp": formatter.string(from: timestamp), "properties": props]
                        try self.write(["payload": payload, "attempts": 0, "retryAt": 0], to: file)
                    }
                    if let receipt { try Data().write(to: receipt, options: .atomic) }
                    accepted = true
                }
            } catch { NSLog("Braver Search: telemetry persistence failed: %@", error.localizedDescription) }
            self.drain()
            completion?(accepted)
        }
    }

    func flush() { worker.async { self.drain() } }

    /// A file lock serializes shared state and identity updates across the app and extension processes.
    func locked<T>(_ body: (URL) throws -> T) throws -> T {
        guard let directory else { throw CocoaError(.fileNoSuchFile) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fd = Darwin.open(directory.appendingPathComponent("store.lock").path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard fd >= 0 else { throw CocoaError(.fileWriteUnknown) }
        defer { Darwin.close(fd) }
        guard flock(fd, LOCK_EX) == 0 else { throw CocoaError(.fileWriteUnknown) }
        defer { flock(fd, LOCK_UN) }
        return try body(directory)
    }

    private func write(_ object: [String: Any], to url: URL) throws {
        try JSONSerialization.data(withJSONObject: object).write(to: url, options: .atomic)
    }

    private func drain() {
        guard !sending else { return }
        wakeup?.cancel()
        let key = defaults.string(forKey: "posthogAPIKey") ?? ""
        guard !key.isEmpty else { return } // Retain events until configuration is available.
        let host = defaults.string(forKey: "posthogHost") ?? "https://us.i.posthog.com"
        guard let endpoint = URL(string: host + "/capture/") else { return }
        var selected: (URL, [String: Any])?
        var nextRetry = Date().timeIntervalSince1970 + 60
        do {
            try locked { root in
                let folder = root.appendingPathComponent("queue")
                let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
                for file in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) where file.pathExtension == "json" {
                    guard let data = try? Data(contentsOf: file),
                          let record = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
                    let retryAt = record["retryAt"] as? Double ?? 0
                    if retryAt <= Date().timeIntervalSince1970 { selected = (file, record); break }
                    nextRetry = min(nextRetry, retryAt)
                }
                if selected == nil && !files.isEmpty { schedule(after: max(1, nextRetry - Date().timeIntervalSince1970)) }
            }
        } catch { return }
        guard let (file, record) = selected, var payload = record["payload"] as? [String: Any] else { return }
        payload["api_key"] = key
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        sending = true
        session.dataTask(with: request) { _, response, error in
            self.worker.async {
                self.sending = false
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                do {
                    try self.locked { _ in
                        guard FileManager.default.fileExists(atPath: file.path) else { return }
                        if error == nil && (200..<300).contains(status) {
                            try FileManager.default.removeItem(at: file)
                        } else {
                            var retry = record
                            let attempts = (record["attempts"] as? Int ?? 0) + 1
                            retry["attempts"] = attempts
                            let backoff = min(3600, pow(2, Double(min(attempts, 11))))
                            let retryAfter = Double(String(describing: (response as? HTTPURLResponse)?.allHeaderFields.first { String(describing: $0.key).lowercased() == "retry-after" }?.value ?? "")) ?? 0
                            retry["retryAt"] = Date().timeIntervalSince1970 + max(backoff, retryAfter)
                            retry["lastStatus"] = status
                            try self.write(retry, to: file)
                        }
                    }
                } catch { NSLog("Braver Search: telemetry acknowledgement could not be saved") }
                self.drain()
            }
        }.resume()
    }

    private func schedule(after delay: TimeInterval) {
        let work = DispatchWorkItem { self.drain() }
        wakeup = work
        worker.asyncAfter(deadline: .now() + delay, execute: work)
    }
}
