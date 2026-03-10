import Foundation
import StoreKit

@MainActor
final class MonetizationManager: ObservableObject {
    static let shared = MonetizationManager()

    @Published private(set) var userState: MonetizationUserState
    @Published private(set) var hasDonated: Bool
    @Published private(set) var donationPurchaseCount: Int
    @Published private(set) var redirectCount: Int
    @Published private(set) var lastDonationProductID: String?

    private let defaults = sharedMonetizationDefaults()
    private var hasConfigured = false

    private init() {
        userState = MonetizationUserState(rawValue: defaults.string(forKey: MonetizationDefaultsKey.userState) ?? "") ?? .unknown
        hasDonated = defaults.bool(forKey: MonetizationDefaultsKey.hasDonated)
        donationPurchaseCount = defaults.integer(forKey: MonetizationDefaultsKey.donationPurchaseCount)
        redirectCount = defaults.integer(forKey: MonetizationDefaultsKey.redirectCount)
        lastDonationProductID = defaults.string(forKey: MonetizationDefaultsKey.lastDonationProductID)
    }

    var canShowSupport: Bool {
        userState.canTip
    }

    func configureIfNeeded() {
        guard !hasConfigured else {
            refreshFromDefaults()
            return
        }

        if defaults.object(forKey: MonetizationDefaultsKey.firstUseDate) == nil {
            defaults.set(Date().timeIntervalSince1970, forKey: MonetizationDefaultsKey.firstUseDate)
        }

        if defaults.string(forKey: MonetizationDefaultsKey.userState)?.isEmpty != false {
            defaults.set(MonetizationUserState.unknown.rawValue, forKey: MonetizationDefaultsKey.userState)
        }

        hasConfigured = true
        refreshFromDefaults()
    }

    func refreshFromDefaults() {
        userState = MonetizationUserState(rawValue: defaults.string(forKey: MonetizationDefaultsKey.userState) ?? "") ?? .unknown
        hasDonated = defaults.bool(forKey: MonetizationDefaultsKey.hasDonated)
        donationPurchaseCount = defaults.integer(forKey: MonetizationDefaultsKey.donationPurchaseCount)
        redirectCount = defaults.integer(forKey: MonetizationDefaultsKey.redirectCount)
        lastDonationProductID = defaults.string(forKey: MonetizationDefaultsKey.lastDonationProductID)
    }

    func resolveUserState() async {
        configureIfNeeded()

        guard #available(iOS 16.0, macOS 13.0, *) else {
            defaults.set(MonetizationUserState.unknown.rawValue, forKey: MonetizationDefaultsKey.userState)
            refreshFromDefaults()
            notifyChange()
            return
        }

        do {
            let verificationResult = try await AppTransaction.shared
            let resolvedState: MonetizationUserState

            switch verificationResult {
            case .verified(let transaction):
                resolvedState = transaction.originalPurchaseDate < MonetizationConfig.paidLaunchDate
                    ? .grandfathered
                    : .paidAppCustomer
            case .unverified:
                resolvedState = .unknown
            }

            defaults.set(resolvedState.rawValue, forKey: MonetizationDefaultsKey.userState)
        } catch {
            defaults.set(MonetizationUserState.unknown.rawValue, forKey: MonetizationDefaultsKey.userState)
        }

        refreshFromDefaults()
        notifyChange()
    }

    func recordDonation(productID: String) {
        defaults.set(true, forKey: MonetizationDefaultsKey.hasDonated)
        defaults.set(defaults.integer(forKey: MonetizationDefaultsKey.donationPurchaseCount) + 1, forKey: MonetizationDefaultsKey.donationPurchaseCount)
        defaults.set(productID, forKey: MonetizationDefaultsKey.lastDonationProductID)
        refreshFromDefaults()
        notifyChange()
    }

    func openSupportFlow() {
        NotificationCenter.default.post(name: .openSupportFlow, object: nil)
    }

    private func notifyChange() {
        NotificationCenter.default.post(name: .monetizationStateDidChange, object: nil)
    }
}
