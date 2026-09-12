import Foundation

/// Local proof of a specific test reaching Brave, independent of analytics connectivity.
enum SetupCheck {
    static let lifetime: TimeInterval = 600

    static func start(analytics: DurableAnalytics = .shared) throws -> URL {
        let id = UUID().uuidString.lowercased()
        try analytics.locked { root in
            try JSONSerialization.data(withJSONObject: ["id": id, "startedAt": Date().timeIntervalSince1970])
                .write(to: root.appendingPathComponent("setup-check.json"), options: .atomic)
        }
        analytics.capture("setup_test_started", properties: ["test_id": id], once: "test_started_" + id)
        var components = URLComponents(string: "https://www.google.com/search")!
        components.queryItems = [URLQueryItem(name: "q", value: "Braver Search setup check"), URLQueryItem(name: "braver_setup", value: id)]
        return components.url!
    }

    static func complete(id: String, analytics: DurableAnalytics = .shared) -> Bool {
        var completedAt: Double?
        try? analytics.locked { root in
            let file = root.appendingPathComponent("setup-check.json")
            guard var state = read(file), state["id"] as? String == id,
                  let started = state["startedAt"] as? Double,
                  Date().timeIntervalSince1970 - started <= lifetime else { return }
            state["completedAt"] = state["completedAt"] ?? Date().timeIntervalSince1970
            try JSONSerialization.data(withJSONObject: state).write(to: file, options: .atomic)
            completedAt = state["completedAt"] as? Double
        }
        if let completedAt {
            analytics.capture("setup_test_redirect_observed", properties: ["test_id": id], once: "test_redirect_" + id, timestamp: Date(timeIntervalSince1970: completedAt))
        }
        return completedAt != nil
    }

    /// Persist what the extension actually observed, independently of PostHog delivery.
    @discardableResult
    static func recordProgress(id: String, stage: String, enabled: Bool? = nil,
                               analytics: DurableAnalytics = .shared) -> Bool {
        guard ["extension_seen", "redirect_requested", "redirect_failed"].contains(stage) else { return false }
        var accepted = false
        try? analytics.locked { root in
            let file = root.appendingPathComponent("setup-check.json")
            guard var state = read(file), state["id"] as? String == id,
                  let started = state["startedAt"] as? Double,
                  (0...lifetime).contains(Date().timeIntervalSince1970 - started) else { return }
            state[stage] = true
            if stage == "extension_seen", let enabled { state["redirectsEnabled"] = enabled }
            try JSONSerialization.data(withJSONObject: state).write(to: file, options: .atomic)
            accepted = true
        }
        if accepted {
            var properties: [String: Any] = ["test_id": id, "stage": stage]
            if let enabled { properties["enabled"] = enabled }
            analytics.capture("setup_test_progress", properties: properties, once: "test_progress_" + id + "_" + stage)
        }
        return accepted
    }

    static func snapshot(analytics: DurableAnalytics = .shared, now: Date = Date()) -> [String: Any] {
        let state: [String: Any]?
        do {
            state = try analytics.locked { root in
                let file = root.appendingPathComponent("setup-check.json")
                let saved = read(file)
                if saved == nil && FileManager.default.fileExists(atPath: file.path) {
                    throw CocoaError(.fileReadCorruptFile)
                }
                return saved
            }
        } catch {
            return ["status": "inconclusive", "title": "Couldn’t read the test result",
                    "message": "Close and reopen Braver Search, then try again.", "reason": "storage_unavailable"]
        }
        guard let state, let started = state["startedAt"] as? Double else {
            return ["status": "idle", "message": "Open a test search in Safari, then return here to see the result."]
        }
        var result: [String: Any] = ["id": state["id"] ?? ""]
        func response(_ status: String, _ title: String, _ message: String, reason: String) -> [String: Any] {
            result.merge(["status": status, "title": title, "message": message, "reason": reason]) { _, new in new }
            return result
        }
        if state["completedAt"] != nil {
            result["completedAt"] = state["completedAt"]
            return response("success", "Setup verified", "Your test reached Brave Search. Redirecting from Google works. Other search engines may need their own website permission.", reason: "brave_confirmed")
        }
        if state["redirectsEnabled"] as? Bool == false {
            return response("inconclusive", "Redirects were off for this test", "Open Braver Search in Safari’s Extensions menu, turn redirects on, then try again.", reason: "redirects_off")
        }
        if state["redirect_failed"] as? Bool == true {
            return response("inconclusive", "Safari couldn’t open the redirect", "The extension saw the test, but Safari did not accept the redirect. Start a new test and keep its tab open.", reason: "redirect_failed")
        }
        let waiting = now.timeIntervalSince1970 - started < 30
        if state["redirect_requested"] as? Bool == true {
            return response(waiting ? "waiting" : "inconclusive", "Redirect detected",
                            waiting ? "Waiting for Brave Search to finish loading."
                                    : "Safari accepted the redirect, but Brave Search hasn’t confirmed it finished loading. Check that Braver Search has website access to Brave Search in Safari, then try again.", reason: "awaiting_brave_confirmation")
        }
        if state["extension_seen"] as? Bool == true {
            return response(waiting ? "waiting" : "inconclusive", "Extension responded",
                            waiting ? "Waiting for Safari to redirect the search."
                                    : "The extension saw the test, but no redirect was confirmed. Try again and check website access in Safari if this repeats.", reason: "awaiting_redirect")
        }
        return response(waiting ? "waiting" : "inconclusive", waiting ? "Checking Safari…" : "No response from Safari",
                        waiting ? "Return after the search opens."
                                : "Safari hasn’t sent a result for this test. Make sure the test opened in Safari and Braver Search is enabled with website access to Google and Brave Search.", reason: "no_extension_response")
    }

    static func resultShown(_ snapshot: [String: Any], analytics: DurableAnalytics = .shared) {
        guard let id = snapshot["id"] as? String, let status = snapshot["status"] as? String,
              status == "success" || status == "inconclusive" else { return }
        analytics.capture("setup_test_result_shown", properties: ["test_id": id, "result": status,
            "reason": snapshot["reason"] as? String ?? "unknown"], once: "test_result_" + id + "_" + status)
        // Repair an interrupted extension capture once the host sees the durable success proof.
        if status == "success", let completedAt = snapshot["completedAt"] as? Double {
            analytics.capture("setup_test_redirect_observed", properties: ["test_id": id], once: "test_redirect_" + id, timestamp: Date(timeIntervalSince1970: completedAt))
        }
    }

    private static func read(_ url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}
