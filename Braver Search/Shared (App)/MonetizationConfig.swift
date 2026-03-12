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
    let description: String
    let assetName: String
}

enum MonetizationConfig {
    static let appGroupIdentifier = "group.xyz.bsquared.braversearch"
    static let appStoreID = "6740840706"
    static let supportURL = URL(string: "braversearch://support")!
    static let reviewURL = URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review")!
    // Set to `nil` while the app is still free for everyone.
    static let paidLaunchDate: Date? = {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(identifier: "America/Los_Angeles")
        components.year = 2026
        components.month = 4
        components.day = 2
        components.hour = 0
        components.minute = 0
        return components.date!
    }()

    static let donationOptions: [DonationOption] = [
        DonationOption(
            id: "braversearch.tip.thanks",
            displayName: "Thanks!",
            fallbackPrice: "$1.99",
            description: "If you're enjoying this app, this means a lot to me.",
            assetName: "TipThanks"
        ),
        DonationOption(
            id: "braversearch.tip.cheers",
            displayName: "Cheers!",
            fallbackPrice: "$4.99",
            description: "Buy me a coffee and support future updates.",
            assetName: "TipCheers"
        ),
        DonationOption(
            id: "braversearch.tip.lifesaver",
            displayName: "You're a lifesaver!",
            fallbackPrice: "$9.99",
            description: "I'm deeply grateful for support like this!",
            assetName: "TipLifesaver"
        ),
        DonationOption(
            id: "braversearch.tip.max",
            displayName: "I can't thank you enough!",
            fallbackPrice: "$99.99",
            description: "Your generosity truly means the world to me!",
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
