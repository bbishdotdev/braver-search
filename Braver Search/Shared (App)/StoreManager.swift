import Foundation
import StoreKit

@MainActor
final class StoreManager: ObservableObject {
    static let shared = StoreManager()

    @Published private(set) var productsByID: [String: Product] = [:]
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var purchaseMessage: String?
    @Published private(set) var activePurchaseProductID: String?

    private var updateTask: Task<Void, Never>?

    private init() {
        updateTask = observeTransactionUpdates()
    }

    deinit {
        updateTask?.cancel()
    }

    func loadProductsIfNeeded() async {
        if isLoadingProducts || !productsByID.isEmpty {
            return
        }

        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            let products = try await Product.products(for: MonetizationConfig.donationOptions.map(\.id))
            productsByID = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
        } catch {
            purchaseMessage = "Donations are unavailable right now."
        }
    }

    func priceText(for option: DonationOption) -> String {
        productsByID[option.id]?.displayPrice ?? option.fallbackPrice
    }

    func purchase(option: DonationOption) async {
        await loadProductsIfNeeded()

        guard let product = productsByID[option.id] else {
            purchaseMessage = "Donations are unavailable right now."
            return
        }

        activePurchaseProductID = option.id
        defer { activePurchaseProductID = nil }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try verifiedTransaction(from: verification)
                await transaction.finish()
                MonetizationManager.shared.recordDonation(productID: transaction.productID)
                purchaseMessage = "Thank you for supporting Braver Search."
            case .userCancelled:
                purchaseMessage = nil
            case .pending:
                purchaseMessage = "Your donation is pending approval."
            @unknown default:
                purchaseMessage = "Donations are unavailable right now."
            }
        } catch {
            purchaseMessage = "Donations are unavailable right now."
        }
    }

    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task {
            for await verification in Transaction.updates {
                guard let transaction = try? verifiedTransaction(from: verification) else {
                    continue
                }

                await transaction.finish()
                if MonetizationConfig.donationOptions.contains(where: { $0.id == transaction.productID }) {
                    MonetizationManager.shared.recordDonation(productID: transaction.productID)
                    purchaseMessage = "Thank you for supporting Braver Search."
                }
            }
        }
    }

    private func verifiedTransaction<T>(from verification: VerificationResult<T>) throws -> T {
        switch verification {
        case .verified(let signedType):
            return signedType
        case .unverified:
            throw StoreError.failedVerification
        }
    }
}

private enum StoreError: Error {
    case failedVerification
}
