import Foundation
import StoreKit

@MainActor
final class StoreManager: ObservableObject {
    static let shared = StoreManager()
    @Published private(set) var productsByID: [String: Product] = [:]
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var purchaseMessage: String?
    @Published private(set) var activePurchaseProductID: String?
    @Published private(set) var isRestoring = false
    private var updateTask: Task<Void, Never>?

    private init() {
        updateTask = Task { [weak self] in
            for await verification in Transaction.updates {
                guard let self else { return }
                do {
                    let transaction = try self.verified(verification)
                    try self.deliver(transaction)
                    await transaction.finish()
                } catch { self.purchaseMessage = "We couldn’t verify this purchase. Try Restore purchases." }
            }
        }
    }
    deinit { updateTask?.cancel() }

    func loadProductsIfNeeded() async {
        guard !isLoadingProducts else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let ids = MonetizationConfig.donationOptions.map(\.id) + AccessConfiguration.lifetimeIDs + [AccessConfiguration.trialID]
            let products = try await Product.products(for: ids)
            productsByID = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
            NotificationCenter.default.post(name: .monetizationStateDidChange, object: nil)
        } catch { purchaseMessage = "The App Store is unavailable. Please try again when you’re connected." }
    }
    func priceText(for option: DonationOption) -> String { productsByID[option.id]?.displayPrice ?? option.fallbackPrice }
    func isAvailable(_ id: String) -> Bool {
        guard let product = productsByID[id] else { return false }
        if id == AccessConfiguration.trialID { return product.type == .nonConsumable && product.price == 0 }
        return product.type == .nonConsumable && product.price > 0
    }
    func purchase(option: DonationOption) async { await purchase(id: option.id) }

    func purchase(id: String) async {
        guard activePurchaseProductID == nil, !isRestoring else { return }
        // Lock before the first await to prevent overlapping sheets.
        activePurchaseProductID = id
        purchaseMessage = nil
        defer { activePurchaseProductID = nil }
        if productsByID[id] == nil { await loadProductsIfNeeded() }
        let tip = MonetizationConfig.donationOptions.contains { $0.id == id }
        let decision = AccessStore.decision()
        guard tip ? decision.state.canTip : ![.free, .grandfathered, .lifetime].contains(decision.state) else { return }
        if id == AccessConfiguration.trialID && decision.state != .eligible {
            purchaseMessage = "Check your access with Restore purchases before starting a trial."
            return
        }
        guard let product = productsByID[id], tip || isAvailable(id) else {
            purchaseMessage = "This option isn’t available from the App Store yet. Please try again later."
            return
        }
        DurableAnalytics.shared.capture("purchase_started", properties: ["product_id": id])
        do {
            switch try await product.purchase() {
            case .success(let verification):
                let transaction = try verified(verification)
                try deliver(transaction)
                await transaction.finish() // Persist the verified entitlement before acknowledging delivery.
            case .pending:
                purchaseMessage = "Waiting for Apple’s approval. Your access will update when it arrives."
                DurableAnalytics.shared.capture("purchase_pending", properties: ["product_id": id])
            case .userCancelled:
                DurableAnalytics.shared.capture("purchase_cancelled", properties: ["product_id": id])
            @unknown default:
                purchaseMessage = "The purchase couldn’t finish. Please try again."
            }
        } catch {
            purchaseMessage = "The purchase couldn’t be verified or saved. Restore purchases to try again."
            DurableAnalytics.shared.capture("purchase_failed", properties: ["product_id": id])
        }
    }

    func restore() async {
        guard !isRestoring, activePurchaseProductID == nil else { return }
        isRestoring = true
        defer { isRestoring = false }
        do {
            try await AppStore.sync() // Only on an explicit user action; may request Apple authentication.
            await MonetizationManager.shared.resolveUserState()
            purchaseMessage = AccessStore.decision().allowsRedirects ? "Your access is ready." : "No active access found. You can start a trial if eligible or choose a lifetime price."
            DurableAnalytics.shared.capture("purchases_restored")
        } catch { purchaseMessage = "Couldn’t connect to the App Store. Your saved access hasn’t changed." }
    }

    private func deliver(_ transaction: Transaction) throws {
        if MonetizationConfig.donationOptions.contains(where: { $0.id == transaction.productID }) {
            if transaction.revocationDate == nil {
                MonetizationManager.shared.recordDonation(productID: transaction.productID, transactionID: String(transaction.id))
                purchaseMessage = "Thank you for supporting Braver Search."
            }
        } else if transaction.productID == AccessConfiguration.trialID || AccessConfiguration.lifetimeIDs.contains(transaction.productID) {
            guard transaction.productType == .nonConsumable else { throw StoreError.failedVerification }
            try AccessStore.accept(transaction)
            MonetizationManager.shared.refreshAccess()
            let revoked = transaction.revocationDate != nil
            purchaseMessage = revoked ? "This purchase is no longer active. Restore purchases to check your access." : (transaction.productID == AccessConfiguration.trialID ? "Your 14 free days start now. Happy searching!" : "You’re unlocked for good. Thank you!")
            DurableAnalytics.shared.capture(revoked ? "access_revoked" : "access_purchase_verified", properties: ["product_id": transaction.productID], once: "access_" + String(transaction.id) + (revoked ? "_revoked" : ""))
        }
    }
    private func verified<T>(_ result: VerificationResult<T>) throws -> T {
        guard case .verified(let value) = result else { throw StoreError.failedVerification }
        return value
    }
}
private enum StoreError: Error { case failedVerification }
