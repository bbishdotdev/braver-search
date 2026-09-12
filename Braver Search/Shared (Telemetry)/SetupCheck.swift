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

    static func snapshot(analytics: DurableAnalytics = .shared) -> [String: Any] {
        let state = (try? analytics.locked { root in read(root.appendingPathComponent("setup-check.json")) }) ?? nil
        guard let state, let started = state["startedAt"] as? Double else {
            return ["status": "idle", "message": "Open a test search in Safari, then return here to see the result."]
        }
        if state["completedAt"] != nil {
            return ["status": "success", "id": state["id"] ?? "", "completedAt": state["completedAt"] ?? 0, "message": "Your test reached Brave Search. Redirecting from Google works. Other search engines may need their own website permission."]
        }
        if Date().timeIntervalSince1970 - started < 30 {
            return ["status": "waiting", "id": state["id"] ?? "", "message": "Waiting for the test in Safari. Return here after the page opens."]
        }
        return ["status": "inconclusive", "id": state["id"] ?? "", "message": "Couldn’t verify yet. In Safari, turn on Braver Search, allow access to Google and Brave Search, and check that redirects are on in the extension popup. Then retry. This does not necessarily mean the extension is disabled."]
    }

    static func resultShown(_ snapshot: [String: Any], analytics: DurableAnalytics = .shared) {
        guard let id = snapshot["id"] as? String, let status = snapshot["status"] as? String,
              status == "success" || status == "inconclusive" else { return }
        analytics.capture("setup_test_result_shown", properties: ["test_id": id, "result": status], once: "test_result_" + id + "_" + status)
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
