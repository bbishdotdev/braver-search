import Foundation

// Standalone macOS regression suite; URLProtocol prevents any real analytics traffic.
final class StubTransport: URLProtocol {
    static let lock = NSLock()
    static var requests: [Data] = []
    static var statuses: [Int] = [503, 200]
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lock.lock()
        var body = request.httpBody ?? Data()
        if body.isEmpty, let stream = request.httpBodyStream {
            stream.open()
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let size = stream.read(&buffer, maxLength: buffer.count)
                if size <= 0 { break }
                body.append(buffer, count: size)
            }
            stream.close()
        }
        Self.requests.append(body)
        let status = Self.statuses.isEmpty ? 200 : Self.statuses.removeFirst()
        Self.lock.unlock()
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("1".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@main struct TelemetryTests {
    static func require(_ value: @autoclosure () -> Bool, _ message: String) {
        if !value() { fatalError(message) }
    }
    static func waitUntil(_ condition: () -> Bool) {
        let end = Date().addingTimeInterval(10)
        while !condition() && Date() < end { Thread.sleep(forTimeInterval: 0.05) }
        require(condition(), "Timed out")
    }
    static func capture(_ analytics: DurableAnalytics, event: String, once: String? = nil, timestamp: Date = Date()) -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        var accepted = false
        analytics.capture(event, once: once, timestamp: timestamp) { accepted = $0; semaphore.signal() }
        require(semaphore.wait(timeout: .now() + 5) == .success, "Capture callback timed out")
        return accepted
    }
    static func records(_ root: URL) -> [URL] {
        ((try? FileManager.default.contentsOfDirectory(at: root.appendingPathComponent("queue"), includingPropertiesForKeys: nil)) ?? []).filter { $0.pathExtension == "json" }
    }
    static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("braver-telemetry-tests-" + UUID().uuidString)
        let suite = "braver.tests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { try? FileManager.default.removeItem(at: root); defaults.removePersistentDomain(forName: suite) }
        defaults.set("existing-install", forKey: "analyticsAnonymousID")
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubTransport.self]
        let session = URLSession(configuration: configuration)
        let analytics = DurableAnalytics(directory: root, session: session, defaults: defaults)
        require(capture(analytics, event: "first_app_open", once: "first_app_open", timestamp: Date(timeIntervalSince1970: 1700000000)), "Queue must work without credentials")
        require(capture(analytics, event: "first_app_open", once: "first_app_open"), "Repeated milestone should be accepted")
        require(records(root).count == 1, "Milestone duplicated")
        try FileManager.default.removeItem(at: root.appendingPathComponent("milestones/first_app_open.json"))
        require(capture(analytics, event: "first_app_open", once: "first_app_open"), "Recovery of interrupted milestone transaction failed")
        require(records(root).count == 1, "Recovery duplicated the stored event")
        let original = try Data(contentsOf: records(root)[0])
        let record = try JSONSerialization.jsonObject(with: original) as! [String: Any]
        let payload = record["payload"] as! [String: Any]
        require(payload["timestamp"] as? String == "2023-11-14T22:13:20.000Z", "Original occurrence time was lost")
        require((payload["properties"] as! [String: Any])["distinct_id"] as? String == "existing-install", "Identity migration failed")
        let restarted = DurableAnalytics(directory: root, session: session, defaults: defaults)
        defaults.set("stub-key", forKey: "posthogAPIKey")
        defaults.set("https://analytics.invalid", forKey: "posthogHost")
        restarted.flush()
        waitUntil { StubTransport.lock.lock(); defer { StubTransport.lock.unlock() }; return StubTransport.requests.count >= 1 }
        require(records(root).count == 1, "Failed request was dropped")
        waitUntil { records(root).isEmpty }
        StubTransport.lock.lock()
        let requests = StubTransport.requests
        StubTransport.lock.unlock()
        require(requests.count == 2, "Expected one failure then successful retry")
        let a = try JSONSerialization.jsonObject(with: requests[0]) as! NSDictionary
        let b = try JSONSerialization.jsonObject(with: requests[1]) as! NSDictionary
        require(a == b, "Retry changed uuid, timestamp, identity, or properties")
        require(capture(restarted, event: "first_app_open", once: "first_app_open"), "Receipt lost on restart")
        require(records(root).isEmpty, "Acknowledged milestone re-enqueued")
        require(!capture(DurableAnalytics(directory: nil, defaults: defaults), event: "test"), "Missing shared container must reject persistence")

        defaults.removeObject(forKey: "posthogAPIKey")
        let group = DispatchGroup()
        for index in 0..<30 {
            group.enter()
            (index % 2 == 0 ? analytics : restarted).capture("concurrent_milestone", once: "concurrent_milestone") { accepted in
                require(accepted, "Concurrent enqueue failed")
                group.leave()
            }
        }
        require(group.wait(timeout: .now() + 5) == .success, "Concurrent writers timed out")
        require(records(root).count == 1, "Shared writers duplicated a milestone")
        require(SetupCheck.snapshot(analytics: analytics)["status"] as? String == "idle", "Expected idle")
        let url = try SetupCheck.start(analytics: analytics)
        let id = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!.first { $0.name == "braver_setup" }!.value!
        require(!SetupCheck.complete(id: UUID().uuidString, analytics: analytics), "Unrelated test accepted")
        require(SetupCheck.snapshot(analytics: analytics)["status"] as? String == "waiting", "Expected waiting")
        require(SetupCheck.snapshot(analytics: restarted, now: Date().addingTimeInterval(31))["reason"] as? String == "no_extension_response", "No callback must produce an actionable timeout after returning")
        require(!SetupCheck.recordProgress(id: UUID().uuidString, stage: "redirect_failed", analytics: analytics), "Unrelated progress accepted")
        require(!SetupCheck.recordProgress(id: id, stage: "invented", analytics: analytics), "Unknown progress accepted")
        require(SetupCheck.recordProgress(id: id, stage: "extension_seen", enabled: true, analytics: restarted), "Runtime response was lost")
        require(SetupCheck.recordProgress(id: id, stage: "redirect_requested", analytics: restarted), "Redirect response was lost")
        require(SetupCheck.snapshot(analytics: analytics)["status"] as? String == "waiting", "An accepted redirect is not completed-page proof")
        require(SetupCheck.snapshot(analytics: analytics, now: Date().addingTimeInterval(31))["reason"] as? String == "awaiting_brave_confirmation", "Missing destination proof must explain the observed redirect")
        require(SetupCheck.complete(id: id, analytics: analytics), "Matching test should succeed")
        require(SetupCheck.snapshot(analytics: analytics)["status"] as? String == "success", "Success must be local even offline")
        require(SetupCheck.snapshot(analytics: restarted)["status"] as? String == "success", "A foreground reader must observe proof from another instance")
        require(SetupCheck.recordProgress(id: id, stage: "redirect_requested", analytics: restarted), "Late progress should be safely accepted")
        require(SetupCheck.snapshot(analytics: analytics)["status"] as? String == "success", "Late progress must not replace success")
        let newURL = try SetupCheck.start(analytics: analytics)
        let newID = URLComponents(url: newURL, resolvingAgainstBaseURL: false)!.queryItems!.first { $0.name == "braver_setup" }!.value!
        require(!SetupCheck.complete(id: id, analytics: analytics), "Old test must not complete a newer attempt")
        require(!SetupCheck.recordProgress(id: id, stage: "redirect_failed", analytics: analytics), "Old progress must not affect a newer test")
        require(SetupCheck.recordProgress(id: newID, stage: "extension_seen", enabled: false, analytics: analytics), "Disabled state was lost")
        require(SetupCheck.snapshot(analytics: restarted)["reason"] as? String == "redirects_off", "Disabled redirects must be explained immediately")
        require(SetupCheck.snapshot(analytics: restarted)["status"] as? String == "inconclusive", "Disabled redirect must not stay waiting")
        try analytics.locked { dir in
            let file = dir.appendingPathComponent("setup-check.json")
            try JSONSerialization.data(withJSONObject: ["id": newID, "startedAt": Date().timeIntervalSince1970 - 900]).write(to: file, options: .atomic)
        }
        require(!SetupCheck.complete(id: newID, analytics: analytics), "Expired token accepted")
        require(!SetupCheck.recordProgress(id: newID, stage: "redirect_requested", analytics: analytics), "Expired progress accepted")
        require(SetupCheck.snapshot(analytics: analytics)["status"] as? String == "inconclusive", "Expired test must be inconclusive")
        let failedURL = try SetupCheck.start(analytics: analytics)
        let failedID = URLComponents(url: failedURL, resolvingAgainstBaseURL: false)!.queryItems!.first { $0.name == "braver_setup" }!.value!
        require(SetupCheck.recordProgress(id: failedID, stage: "redirect_failed", analytics: restarted), "Failed redirect report was lost")
        require(SetupCheck.snapshot(analytics: analytics)["reason"] as? String == "redirect_failed", "Failed redirects must explain the failure immediately")
        require(SetupCheck.snapshot(analytics: DurableAnalytics(directory: nil, defaults: defaults))["reason"] as? String == "storage_unavailable", "Unavailable storage must be visible, not silently idle")
        // Wait for all asynchronous persistence before cleanup.
        _ = capture(analytics, event: "barrier")
        print("PASS: durable enqueue, milestone idempotency, identity migration, restart recovery, HTTP retry, stable retry payload, acknowledgement, unavailable storage, setup token matching/expiry, offline proof")
    }
}
