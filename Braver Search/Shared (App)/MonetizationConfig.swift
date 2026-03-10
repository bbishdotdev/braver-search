import Foundation

enum MonetizationUserState: String {
    case unknown
    case grandfathered
    case paidAppCustomer

    var canTip: Bool {
        self == .grandfathered
    }
}

struct DonationOption: Identifiable {
    let id: String
    let displayName: String
    let fallbackPrice: String
    let assetName: String
}

enum MonetizationConfig {
    static let appGroupIdentifier = "group.xyz.bsquared.braversearch"
    static let appStoreID = "6740840706"
    static let supportURL = URL(string: "braversearch://support")!
    static let reviewURL = URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review")!
    static let paidLaunchDate: Date = {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = 2026
        components.month = 4
        components.day = 2
        return components.date!
    }()

    static let donationOptions: [DonationOption] = [
        DonationOption(
            id: "braversearch.tip.thanks",
            displayName: "Thanks",
            fallbackPrice: "$1.99",
            assetName: "TipThanks"
        ),
        DonationOption(
            id: "braversearch.tip.cheers",
            displayName: "Cheers",
            fallbackPrice: "$4.99",
            assetName: "TipCheers"
        ),
        DonationOption(
            id: "braversearch.tip.lifesaver",
            displayName: "You're a lifesaver",
            fallbackPrice: "$9.99",
            assetName: "TipLifesaver"
        ),
        DonationOption(
            id: "braversearch.tip.max",
            displayName: "I can't thank you enough",
            fallbackPrice: "$99.99",
            assetName: "TipMax"
        ),
    ]
}

enum MonetizationDefaultsKey {
    static let userState = "monetization.userState"
    static let firstUseDate = "monetization.firstUseDate"
    static let redirectCount = "monetization.redirectCount"
    static let hasDonated = "monetization.hasDonated"
    static let donationPurchaseCount = "monetization.donationPurchaseCount"
    static let lastDonationProductID = "monetization.lastDonationProductID"
}

extension Notification.Name {
    static let monetizationStateDidChange = Notification.Name("MonetizationStateDidChange")
    static let openSupportFlow = Notification.Name("OpenSupportFlow")
}

func sharedMonetizationDefaults() -> UserDefaults {
    UserDefaults(suiteName: MonetizationConfig.appGroupIdentifier)!
}
