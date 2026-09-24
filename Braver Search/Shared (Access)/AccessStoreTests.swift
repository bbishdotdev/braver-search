import XCTest
import StoreKit
import StoreKitTest
@testable import Braver_Search

/// Real Xcode StoreKit transactions. These never contact the production App Store or charge money.
@MainActor final class AccessStoreTests: XCTestCase {
    private func restoredDecision(_ expected: AccessState, cutoff: Date) async throws -> AccessDecision {
        print("StoreKit test: restoring \(expected)")
        // StoreKit Test updates its entitlement inventory asynchronously after delivery/refund.
        for _ in 0..<50 {
            await AccessStore.refresh()
            try AccessStore.update { $0.originalPurchaseDate = Date() }
            let decision = AccessStore.decision(cutoff: cutoff)
            if decision.state == expected { return decision }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        return AccessStore.decision(cutoff: cutoff)
    }
    private func verifiedTransaction(id: String, transactionID: UInt64, revoked: Bool = false) async throws -> Transaction {
        // StoreKit Test publishes to the receipt asynchronously after buyProduct returns.
        for _ in 0..<50 {
            if let result = await Transaction.latest(for: id) {
                switch result {
                case .verified(let transaction):
                    if transaction.id == transactionID && (!revoked || transaction.revocationDate != nil) { return transaction }
                case .unverified(_, let error): throw error
                }
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        throw NSError(domain: "AccessStoreTests.receiptTimeout", code: 1)
    }
    func testTrialLifetimeRestorationAndRefund() async throws {
        print("StoreKit test: preparing lifetime session")
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("access-tests-" + UUID().uuidString)
        AccessStore.testPersistence = DurableAnalytics(directory: root)
        // Keep late StoreKit callbacks isolated until the test host exits, too.
        defer { try? FileManager.default.removeItem(at: root) }
        AccessStore.configurePreview() // Clear any previous launch-only UI fixture.
        let session = try SKTestSession(configurationFileNamed: "Monetization")
        print("StoreKit test: lifetime session ready")
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()
        defer { session.clearTransactions() }
        let ids = AccessConfiguration.lifetimeIDs + [AccessConfiguration.trialID]
        let products = try await Product.products(for: ids)
        print("StoreKit test: lifetime catalog loaded, \(products.count) products")
        XCTAssertEqual(Set(products.map(\.id)), Set(ids))
        await StoreManager.shared.loadProductsIfNeeded()
        XCTAssertTrue(StoreManager.shared.isAvailable(AccessConfiguration.thanksLifetimeID))
        XCTAssertFalse(StoreManager.shared.isAvailable("braversearch.lifetime.not-configured"))
        XCTAssertNil(StoreManager.shared.productLoadMessage)
        XCTAssertEqual(MonetizationConfig.lifetimeOptions.map(\.id), AccessConfiguration.lifetimeIDs)
        XCTAssertEqual(MonetizationConfig.lifetimeOptions[MonetizationConfig.suggestedLifetimeIndex].id, AccessConfiguration.suggestedLifetimeID)
        XCTAssertEqual(products.first { $0.id == AccessConfiguration.thanksLifetimeID }?.price, Decimal(string: "2.99"))
        XCTAssertTrue(products.allSatisfy { $0.type == .nonConsumable })
        XCTAssertEqual(products.first { $0.id == AccessConfiguration.trialID }?.price, 0)

        let trial = try await session.buyProduct(identifier: AccessConfiguration.trialID, options: [])
        print("StoreKit test: trial delivered")
        let verifiedTrial = try await verifiedTransaction(id: trial.productID, transactionID: trial.id)
        try AccessStore.accept(verifiedTrial)
        try AccessStore.update { $0.originalPurchaseDate = Date(); $0.legacyFirstUse = nil }
        let cutoff = Date(timeIntervalSince1970: 1)
        XCTAssertEqual(AccessStore.decision(cutoff: cutoff).state, .trial)
        XCTAssertEqual(AccessStore.decision(cutoff: cutoff).expiresAt, trial.originalPurchaseDate.addingTimeInterval(14 * 86400))
        await trial.finish()
        // Simulate loss of the local cache on reinstall; receipt restores the original trial date.
        try AccessStore.update { $0 = AccessRecord() }
        let restoredTrial = try await restoredDecision(.trial, cutoff: cutoff)
        XCTAssertEqual(restoredTrial.state, .trial)
        XCTAssertEqual(restoredTrial.expiresAt, trial.originalPurchaseDate.addingTimeInterval(14 * 86400))

        let paid = try await session.buyProduct(identifier: AccessConfiguration.thanksLifetimeID, options: [])
        let verifiedPaid = try await verifiedTransaction(id: paid.productID, transactionID: paid.id)
        try AccessStore.accept(verifiedPaid)
        XCTAssertEqual(AccessStore.decision(cutoff: cutoff).state, .lifetime)
        await paid.finish()
        try AccessStore.update { $0 = AccessRecord() }
        let restoredLifetime = try await restoredDecision(.lifetime, cutoff: cutoff)
        XCTAssertEqual(restoredLifetime.state, .lifetime)

        try session.refundTransaction(identifier: UInt(paid.id))
        let refunded = try await verifiedTransaction(id: paid.productID, transactionID: paid.id, revoked: true)
        try AccessStore.accept(refunded)
        let afterRefund = try await restoredDecision(.trial, cutoff: cutoff)
        XCTAssertEqual(afterRefund.state, .trial, "Refund must remove lifetime access while retaining a valid trial")
        await AccessStore.refreshExtension()
        XCTAssertEqual(AccessStore.decision(cutoff: cutoff).state, .trial, "Extension reconciliation must not revive the refunded transaction")
        XCTAssertEqual(AccessStore.decision(now: Date().addingTimeInterval(15 * 86400), cutoff: cutoff).state, .expired)
        try AccessStore.update { $0 = AccessRecord() }
    }

    func testLocalSandboxConfigurationIsIsolatedAndRestorable() async throws {
        print("StoreKit test: preparing local cohort session")
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("local-access-tests-" + UUID().uuidString)
        AccessStore.testPersistence = DurableAnalytics(directory: root)
        defer { try? FileManager.default.removeItem(at: root) }
        AccessStore.configurePreview()
        AccessStore.configureLocalTest(arguments: [])
        let original = Date(timeIntervalSince1970: 1_500_000_000)
        try AccessStore.update { $0.originalPurchaseDate = original; $0.appTransactionEnvironment = "Production" }
        AccessStore.configureLocalTest(arguments: ["-monetization-test-cohort", "new"])
        XCTAssertEqual(AccessStore.decision().state, .unknown, "A new test record must not inherit real ownership")
        let session = try SKTestSession(configurationFileNamed: "Monetization")
        print("StoreKit test: cohort session ready")
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()
        defer { session.clearTransactions() }
        // Initialize the local StoreKit catalog before requesting the app transaction on a cold simulator.
        let products = try await Product.products(for: [AccessConfiguration.trialID])
        print("StoreKit test: cohort catalog loaded, \(products.count) products")
        XCTAssertEqual(products.count, 1)
        // A cold Xcode StoreKit session can wait indefinitely for AppTransaction.shared
        // before it has created a receipt. Seed a real test purchase first; cohort-only
        // eligible behavior is covered separately by the pure policy tests.
        let trial = try await session.buyProduct(identifier: AccessConfiguration.trialID, options: [])
        _ = try await verifiedTransaction(id: trial.productID, transactionID: trial.id)
        await AccessStore.refresh()
        print("StoreKit test: cohort acquisition refreshed")
        XCTAssertEqual(AccessStore.decision().state, .trial, "Verified Xcode acquisition and receipt must restore the trial in the new-user cohort")
        try AccessStore.accept(try await verifiedTransaction(id: trial.productID, transactionID: trial.id))
        XCTAssertEqual(AccessStore.decision().state, .trial)
        AccessStore.configureLocalTest(arguments: ["-monetization-test-cohort", "new", "-monetization-test-elapsed-days", "15"])
        XCTAssertEqual(AccessStore.decision().state, .expired)
        AccessStore.configureLocalTest(arguments: ["-monetization-test-cohort", "legacy"])
        XCTAssertEqual(AccessStore.decision().state, .grandfathered)
        AccessStore.configureLocalTest(arguments: [])
        try AccessStore.update {
            XCTAssertEqual($0.originalPurchaseDate, original)
            XCTAssertNil($0.trialStart, "Sandbox testing must not modify the normal access record")
        }
        XCTAssertEqual(AccessStore.decision().state, .free, "Local test flags must not activate the production cutoff")
    }
}
