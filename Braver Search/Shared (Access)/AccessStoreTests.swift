import XCTest
import StoreKit
import StoreKitTest
@testable import Braver_Search

/// Real Xcode StoreKit transactions. These never contact the production App Store or charge money.
@MainActor final class AccessStoreTests: XCTestCase {
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
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("access-tests-" + UUID().uuidString)
        AccessStore.testPersistence = DurableAnalytics(directory: root)
        // Keep late StoreKit callbacks isolated until the test host exits, too.
        defer { try? FileManager.default.removeItem(at: root) }
        AccessStore.configurePreview() // Clear any previous launch-only UI fixture.
        let session = try SKTestSession(configurationFileNamed: "Monetization")
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()
        defer { session.clearTransactions() }
        let ids = AccessConfiguration.lifetimeIDs + [AccessConfiguration.trialID]
        let products = try await Product.products(for: ids)
        XCTAssertEqual(products.count, 6)
        XCTAssertTrue(products.allSatisfy { $0.type == .nonConsumable })
        XCTAssertEqual(products.first { $0.id == AccessConfiguration.trialID }?.price, 0)

        let trial = try await session.buyProduct(identifier: AccessConfiguration.trialID, options: [])
        let verifiedTrial = try await verifiedTransaction(id: trial.productID, transactionID: trial.id)
        try AccessStore.accept(verifiedTrial)
        try AccessStore.update { $0.originalPurchaseDate = Date(); $0.legacyFirstUse = nil }
        let cutoff = Date(timeIntervalSince1970: 1)
        XCTAssertEqual(AccessStore.decision(cutoff: cutoff).state, .trial)
        XCTAssertEqual(AccessStore.decision(cutoff: cutoff).expiresAt, trial.originalPurchaseDate.addingTimeInterval(14 * 86400))
        await trial.finish()
        // Simulate loss of the local cache on reinstall; receipt restores the original trial date.
        try AccessStore.update { $0 = AccessRecord() }
        await AccessStore.refresh()
        try AccessStore.update { $0.originalPurchaseDate = Date() }
        XCTAssertEqual(AccessStore.decision(cutoff: cutoff).expiresAt, trial.originalPurchaseDate.addingTimeInterval(14 * 86400))

        let paid = try await session.buyProduct(identifier: AccessConfiguration.lifetimeIDs[1], options: [])
        let verifiedPaid = try await verifiedTransaction(id: paid.productID, transactionID: paid.id)
        try AccessStore.accept(verifiedPaid)
        XCTAssertEqual(AccessStore.decision(cutoff: cutoff).state, .lifetime)
        await paid.finish()
        try AccessStore.update { $0 = AccessRecord() }
        await AccessStore.refresh()
        try AccessStore.update { $0.originalPurchaseDate = Date() }
        XCTAssertEqual(AccessStore.decision(cutoff: cutoff).state, .lifetime)

        try session.refundTransaction(identifier: UInt(paid.id))
        let refunded = try await verifiedTransaction(id: paid.productID, transactionID: paid.id, revoked: true)
        try AccessStore.accept(refunded)
        await AccessStore.refresh()
        try AccessStore.update { $0.originalPurchaseDate = Date() }
        XCTAssertEqual(AccessStore.decision(cutoff: cutoff).state, .trial, "Refund must remove lifetime access while retaining a valid trial")
        await AccessStore.refreshExtension()
        XCTAssertEqual(AccessStore.decision(cutoff: cutoff).state, .trial, "Extension reconciliation must not revive the refunded transaction")
        XCTAssertEqual(AccessStore.decision(now: Date().addingTimeInterval(15 * 86400), cutoff: cutoff).state, .expired)
        try AccessStore.update { $0 = AccessRecord() }
    }
}
