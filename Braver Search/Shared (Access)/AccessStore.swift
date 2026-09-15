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
    private static let filename = "access-v1.json"

    static func update(_ change: (inout AccessRecord) -> Void) throws {
        try persistence.locked { root in
            let url = root.appendingPathComponent(filename)
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
        #endif
        var decision = AccessDecision(state: cutoff == nil ? .free : .unknown, expiresAt: nil)
        do {
            try update { record in
                if record.legacyFirstUse == nil {
                    let timestamp = DurableAnalytics.defaults.double(forKey: "monetization.firstUseDate")
                    if timestamp > 0 { record.legacyFirstUse = Date(timeIntervalSince1970: timestamp) }
                }
                let effective = record.advanceClock(now: now, uptime: ProcessInfo.processInfo.systemUptime)
                decision = AccessPolicy.evaluate(record, cutoff: cutoff, now: effective)
            }
        } catch { /* storage failure never grants paid access */ }
        return decision
    }

    /// All StoreKit reads use the local verified receipt; no web request on the navigation path.
    static func refresh() async {
        #if DEBUG
        if previewRecord() != nil { return }
        #endif
        if #available(iOS 16.0, macOS 13.0, *) {
            if let result = try? await AppTransaction.shared, case .verified(let app) = result {
                try? update { $0.originalPurchaseDate = app.originalPurchaseDate }
            }
        }
        var revision = 0
        try? update { revision = $0.entitlementRevision }
        var lifetime: [(String, UInt64)] = []
        var trialTransactionID: UInt64?
        var trialStart: Date?
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result, transaction.revocationDate == nil,
                  !transaction.isUpgraded, transaction.productType == .nonConsumable else { continue }
            if AccessConfiguration.lifetimeIDs.contains(transaction.productID) { lifetime.append((transaction.productID, transaction.id)) }
            if transaction.productID == AccessConfiguration.trialID { trialStart = transaction.originalPurchaseDate; trialTransactionID = transaction.id }
        }
        // StoreKit caches current entitlements offline. An empty verified inventory is not payment.
        try? update { record in
            guard record.entitlementRevision == revision else { return } // A purchase/refund delivered during this scan wins.
            record.entitlementRevision += 1
            record.lifetimeProducts = lifetime.filter { !record.revokedTransactionIDs.contains($0.1) }.map { $0.0 }
            record.trialStart = trialTransactionID.map { record.revokedTransactionIDs.contains($0) } == true ? nil : trialStart
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

    #if DEBUG
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
        if scenario == "lifetime" { record.lifetimeProducts = [AccessConfiguration.lifetimeIDs[1]] }
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
