import Foundation
import StoreKit

/// Sandboxed App Group record; only native code writes it, under the existing cross-process file lock.
/// StoreKit supplies signed acquisition/purchase dates. Safari never accepts a JS 'paid' flag.
enum AccessStore {
    #if DEBUG
    static var testPersistence: DurableAnalytics?
    #endif
    private static var persistence: DurableAnalytics {
        #if DEBUG
        if let testPersistence { return testPersistence }
        #endif
        return .shared
    }
    private static var filename: String {
        #if DEBUG
        if localTest() != nil { return "access-local-test-v1.json" }
        #endif
        return "access-v1.json"
    }

    static func update(_ change: (inout AccessRecord) -> Void) throws {
        let recordFilename = filename // Read test configuration before acquiring the record lock.
        try persistence.locked { root in
            let url = root.appendingPathComponent(recordFilename)
            var record = (try? JSONDecoder().decode(AccessRecord.self, from: Data(contentsOf: url))) ?? AccessRecord()
            change(&record)
            try JSONEncoder().encode(record).write(to: url, options: .atomic)
        }
    }

    static func decision(now: Date = Date(), cutoff: Date? = AccessConfiguration.launchDate) -> AccessDecision {
        #if DEBUG
        if let preview = previewRecord() {
            return AccessPolicy.evaluate(preview, cutoff: Date(timeIntervalSince1970: 1), now: now)
        }
        let test = localTest()
        #endif
        var decision = AccessDecision(state: cutoff == nil ? .free : .unknown, expiresAt: nil)
        do {
            try update { record in
                if record.legacyFirstUse == nil {
                    let timestamp = DurableAnalytics.defaults.double(forKey: "monetization.firstUseDate")
                    if timestamp > 0 { record.legacyFirstUse = Date(timeIntervalSince1970: timestamp) }
                }
                let effective = record.advanceClock(now: now, uptime: ProcessInfo.processInfo.systemUptime)
                #if DEBUG
                if let test {
                    decision = test.decision(record: record, now: effective)
                    return
                }
                #endif
                decision = AccessPolicy.evaluateForStore(record, cutoff: cutoff, now: effective)
            }
        } catch { /* storage failure never grants paid access */ }
        return decision
    }

    /// Host only. A forced refresh may authenticate and must be user initiated.
    @discardableResult
    static func refresh(forceRefresh: Bool = false) async -> String? {
        #if DEBUG
        if previewRecord() != nil { return nil }
        #endif
        if #available(iOS 16.0, macOS 13.0, *) {
            let failure = await verifyAcquisition {
                let result: VerificationResult<AppTransaction>
                if forceRefresh { result = try await AppTransaction.refresh() }
                else { result = try await AppTransaction.shared }
                switch result {
                case .verified(let app): return (app.originalPurchaseDate, app.environment.rawValue)
                case .unverified(_, let error): throw error
                }
            }
            // Failure is not evidence of a new account or revoked access. Keep cached
            // entitlements; ordinary trial expiry still uses the local guarded clock.
            if let failure { return failure }
        }
        var revision = 0
        var environment: String?
        try? update { revision = $0.entitlementRevision; environment = $0.appTransactionEnvironment }
        var lifetime: [(String, UInt64)] = []
        var trialTransactionID: UInt64?
        var trialStart: Date?
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result, transaction.revocationDate == nil,
                  !transaction.isUpgraded, transaction.productType == .nonConsumable,
                  matchesEnvironment(transaction, environment) else { continue }
            if AccessConfiguration.lifetimeIDs.contains(transaction.productID) { lifetime.append((transaction.productID, transaction.id)) }
            if transaction.productID == AccessConfiguration.trialID { trialStart = transaction.originalPurchaseDate; trialTransactionID = transaction.id }
        }
        #if DEBUG
        print("Access refresh: inventory lifetime=\(lifetime.map { $0.0 }.sorted()) trial=\(trialStart != nil)")
        #endif
        // The entitlement inventory can lag a finished purchase even when its individual
        // signed transaction is already available. Recover only verified, unrevoked
        // non-consumables; keep their original dates and the same revision/revocation guards.
        let missingIDs = AccessConfiguration.lifetimeIDs.filter { id in !lifetime.contains { $0.0 == id } }
            + (trialStart == nil ? [AccessConfiguration.trialID] : [])
        for id in missingIDs {
            guard let result = await Transaction.latest(for: id), case .verified(let transaction) = result,
                  transaction.productType == .nonConsumable, transaction.revocationDate == nil,
                  !transaction.isUpgraded, matchesEnvironment(transaction, environment) else { continue }
            if id == AccessConfiguration.trialID {
                trialStart = transaction.originalPurchaseDate
                trialTransactionID = transaction.id
            } else {
                lifetime.append((id, transaction.id))
            }
        }
        #if DEBUG
        print("Access refresh: reconciled lifetime=\(lifetime.map { $0.0 }.sorted()) trial=\(trialStart != nil)")
        #endif
        // No verified inventory or individual transaction means no payment evidence.
        try? update { record in
            guard record.entitlementRevision == revision else { return } // A purchase/refund delivered during this scan wins.
            record.entitlementRevision += 1
            record.lifetimeProducts = lifetime.filter { !record.revokedTransactionIDs.contains($0.1) }.map { $0.0 }
            record.trialStart = trialTransactionID.map { record.revokedTransactionIDs.contains($0) } == true ? nil : trialStart
        }
        return nil
    }

    /// Tests inject acquisition failures without forging any StoreKit purchase.
    static func verifyAcquisition(using load: () async throws -> (Date, String)) async -> String? {
        do {
            let (date, environment) = try await load()
            try update { $0.setVerifiedAcquisition(date: date, environment: environment) }
            return nil
        } catch {
            let error = error as NSError
            // Only a technical code, never receipts, account details, or purchase identifiers.
            NSLog("Braver Search: app access verification failed (%@ %ld)", error.domain, error.code)
            return "We couldn’t verify your app download with Apple. Retry to check your trial or lifetime access. (\(error.domain) \(error.code))"
        }
    }

    /// Extension receipts may be unavailable independently of the host. Never erase a host
    /// entitlement on an empty extension inventory; apply only verified transaction evidence.
    static func refreshExtension() async {
        #if DEBUG
        if previewRecord() != nil { return }
        #endif
        for id in AccessConfiguration.lifetimeIDs + [AccessConfiguration.trialID] {
            guard let result = await Transaction.latest(for: id), case .verified(let transaction) = result else { continue }
            try? accept(transaction)
        }
    }

    static func accept(_ transaction: Transaction) throws {
        guard transaction.productType == .nonConsumable else { return }
        try update { record in
            guard matchesEnvironment(transaction, record.appTransactionEnvironment) else { return }
            record.entitlementRevision += 1
            if transaction.revocationDate != nil && !record.revokedTransactionIDs.contains(transaction.id) {
                record.revokedTransactionIDs.append(transaction.id)
            }
            if AccessConfiguration.lifetimeIDs.contains(transaction.productID) {
                record.lifetimeProducts.removeAll { $0 == transaction.productID }
                if transaction.revocationDate == nil && !transaction.isUpgraded && !record.revokedTransactionIDs.contains(transaction.id) { record.lifetimeProducts.append(transaction.productID) }
            }
            if transaction.productID == AccessConfiguration.trialID {
                record.trialStart = transaction.revocationDate == nil && !record.revokedTransactionIDs.contains(transaction.id) ? transaction.originalPurchaseDate : nil
            }
        }
    }

    private static func matchesEnvironment(_ transaction: Transaction, _ environment: String?) -> Bool {
        if #available(iOS 16.0, macOS 13.0, *), let environment {
            return transaction.environment.rawValue == environment
        }
        return true
    }

    #if DEBUG
    static func localTest() -> LocalAccessTest? {
        try? persistence.locked { root in
            try JSONDecoder().decode(LocalAccessTest.self,
                from: Data(contentsOf: root.appendingPathComponent("access-local-test-config.json")))
        }
    }

    /// Called by the host only; the extension reads the same config and isolated record.
    static func configureLocalTest(arguments: [String] = ProcessInfo.processInfo.arguments, now: Date = Date()) {
        func value(_ key: String) -> String? {
            guard let i = arguments.firstIndex(of: key), arguments.indices.contains(i + 1) else { return nil }
            return arguments[i + 1]
        }
        var config: LocalAccessTest?
        if let name = value("-monetization-test-cohort"), let cohort = LocalAccessTest.Cohort(rawValue: name) {
            let cutoff = value("-monetization-test-cutoff").flatMap { ISO8601DateFormatter().date(from: $0) }
                ?? now.addingTimeInterval(-86400)
            let days = min(30, max(0, Int(value("-monetization-test-elapsed-days") ?? "0") ?? 0))
            config = LocalAccessTest(cohort: cohort, cutoff: cutoff, elapsedDays: days)
        }
        try? persistence.locked { root in
            let url = root.appendingPathComponent("access-local-test-config.json")
            if let config { try JSONEncoder().encode(config).write(to: url, options: .atomic) }
            else if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
        }
    }

    // Explicit UI fixtures on a development build only. They never create a StoreKit transaction.
    static func configurePreview() {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-monetization-scenario"), args.indices.contains(index + 1) else {
            try? persistence.locked { root in
                let url = root.appendingPathComponent("access-preview.json")
                if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
            }
            return
        }
        let scenario = args[index + 1]
        var record = AccessRecord(originalPurchaseDate: Date().addingTimeInterval(-60))
        if scenario == "grandfathered" { record.originalPurchaseDate = Date(timeIntervalSince1970: 0) }
        if scenario == "trial" { record.trialStart = Date().addingTimeInterval(-86400) }
        if scenario == "expired" { record.trialStart = Date().addingTimeInterval(-15 * 86400) }
        if scenario == "lifetime" { record.lifetimeProducts = [AccessConfiguration.suggestedLifetimeID] }
        if scenario == "unknown" { record.originalPurchaseDate = nil }
        try? persistence.locked { root in
            try JSONEncoder().encode(record).write(to: root.appendingPathComponent("access-preview.json"), options: .atomic)
        }
    }
    static func previewRecord() -> AccessRecord? {
        try? persistence.locked { root in
            try JSONDecoder().decode(AccessRecord.self, from: Data(contentsOf: root.appendingPathComponent("access-preview.json")))
        }
    }
    #endif
}
