import Foundation
import StoreKit
import os

@MainActor
final class MonetizationManager: ObservableObject {
    static let shared = MonetizationManager()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "xyz.bsquared.braversearch", category: "Monetization")

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

        guard let paidLaunchDate = MonetizationConfig.paidLaunchDate else {
            logger.notice("Paid launch date is not configured; resolving userState=grandfathered for all users")
            defaults.set(MonetizationUserState.grandfathered.rawValue, forKey: MonetizationDefaultsKey.userState)
            refreshFromDefaults()
            notifyChange()
            return
        }

        guard #available(iOS 16.0, macOS 13.0, *) else {
            let fallbackState = fallbackUserState(for: paidLaunchDate)
            logger.notice("StoreKit app transaction unavailable on this OS version; setting userState=\(fallbackState.rawValue, privacy: .public)")
            defaults.set(fallbackState.rawValue, forKey: MonetizationDefaultsKey.userState)
            refreshFromDefaults()
            notifyChange()
            return
        }

        do {
            let verificationResult = try await AppTransaction.shared
            let resolvedState: MonetizationUserState

            switch verificationResult {
            case .verified(let transaction):
                let originalPurchaseDate = transaction.originalPurchaseDate
                resolvedState = transaction.originalPurchaseDate < paidLaunchDate
                    ? .grandfathered
                    : .paidAppCustomer

                logger.notice(
                    """
                    Resolved StoreKit app transaction: verification=verified originalPurchaseDate=\(Self.iso8601String(from: originalPurchaseDate), privacy: .public) paidLaunchDate=\(Self.iso8601String(from: paidLaunchDate), privacy: .public) userState=\(resolvedState.rawValue, privacy: .public)
                    """
                )
            case .unverified:
                resolvedState = fallbackUserState(for: paidLaunchDate)
                logger.error("Resolved StoreKit app transaction: verification=unverified userState=\(resolvedState.rawValue, privacy: .public)")
            }

            defaults.set(resolvedState.rawValue, forKey: MonetizationDefaultsKey.userState)
        } catch {
            let fallbackState = fallbackUserState(for: paidLaunchDate)
            logger.error("Failed to resolve StoreKit app transaction: \(String(describing: error), privacy: .public); fallbackUserState=\(fallbackState.rawValue, privacy: .public)")
            defaults.set(fallbackState.rawValue, forKey: MonetizationDefaultsKey.userState)
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

    private func fallbackUserState(for paidLaunchDate: Date) -> MonetizationUserState {
        Date() < paidLaunchDate ? .grandfathered : .unknown
    }

    private static func iso8601String(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
