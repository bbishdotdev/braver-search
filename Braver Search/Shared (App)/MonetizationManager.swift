import Foundation
import StoreKit

@MainActor
final class MonetizationManager: ObservableObject {
    static let shared = MonetizationManager()

    @Published private(set) var access = AccessStore.decision()
    @Published private(set) var accessVerificationMessage: String?
    @Published private(set) var isVerifyingAccess = false
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
        access.state.canTip
    }

    var showsAccessVerificationNotice: Bool {
        // An unavailable Apple refresh is not a loss of existing access. Keep the
        // technical failure for explicit Restore, but don't alarm users who can search.
        !access.allowsRedirects && accessVerificationMessage != nil
    }

    func configureIfNeeded() {
        guard !hasConfigured else {
            refreshFromDefaults()
            return
        }

        #if os(macOS)
        // Older Mac builds wrote monetization preferences to the unprefixed suite.
        let legacy = UserDefaults(suiteName: MonetizationConfig.appGroupIdentifier)!
        for key in [MonetizationDefaultsKey.firstUseDate, MonetizationDefaultsKey.hasDonated,
                    MonetizationDefaultsKey.donationPurchaseCount, MonetizationDefaultsKey.lastDonationProductID] {
            if defaults.object(forKey: key) == nil, let value = legacy.object(forKey: key) { defaults.set(value, forKey: key) }
        }
        #endif
        #if DEBUG
        AccessStore.configurePreview()
        AccessStore.configureLocalTest()
        #endif

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
        access = AccessStore.decision()
        userState = MonetizationUserState(rawValue: defaults.string(forKey: MonetizationDefaultsKey.userState) ?? "") ?? .unknown
        hasDonated = defaults.bool(forKey: MonetizationDefaultsKey.hasDonated)
        donationPurchaseCount = defaults.integer(forKey: MonetizationDefaultsKey.donationPurchaseCount)
        redirectCount = defaults.integer(forKey: MonetizationDefaultsKey.redirectCount)
        lastDonationProductID = defaults.string(forKey: MonetizationDefaultsKey.lastDonationProductID)
    }

    func resolveUserState(forceRefresh: Bool = false) async {
        guard !isVerifyingAccess else { return }
        configureIfNeeded()
        isVerifyingAccess = true
        notifyChange()
        accessVerificationMessage = await AccessStore.refresh(forceRefresh: forceRefresh)
        refreshAccess()
        isVerifyingAccess = false
        notifyChange() // The Mac view also needs updates when the access decision is unchanged.
    }

    func refreshAccess() {
        let next = AccessStore.decision()
        guard access != next else { return }
        access = next
        // Retain the legacy presentation key for older popup consumers, never for entitlement proof.
        userState = access.state.canTip ? .grandfathered : .unknown
        defaults.set(userState.rawValue, forKey: MonetizationDefaultsKey.userState)
        notifyChange()
    }

    func recordDonation(productID: String, transactionID: String) {
        var ids = defaults.stringArray(forKey: "monetization.donationTransactionIDs") ?? []
        guard !ids.contains(transactionID) else { return }
        ids.append(transactionID)
        defaults.set(ids, forKey: "monetization.donationTransactionIDs")
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
