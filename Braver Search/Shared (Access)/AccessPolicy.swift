import Foundation

/// One policy compiled into both apps and both extensions. No UI or analytics decides access.
enum AccessConfiguration {
    // RELEASE GATE: set an announced UTC cutoff only after all StoreKit products are approved.
    // nil keeps the currently free app free. Never infer payment from an app download.
    static let launchDate: Date? = nil
    static let trialDuration: TimeInterval = 14 * 24 * 60 * 60
    static let trialID = "braversearch.trial.14day"
    static let lifetimeIDs = ["braversearch.lifetime.coffee", "braversearch.lifetime.supporter",
                              "braversearch.lifetime.champion", "braversearch.lifetime.hero", "braversearch.lifetime.legend"]
}

struct AccessRecord: Codable {
    var originalPurchaseDate: Date?
    var legacyFirstUse: Date?
    var trialStart: Date?
    var lifetimeProducts: [String] = []
    var entitlementRevision: Int = 0
    var revokedTransactionIDs: [UInt64] = []
    var lastObservedAt: Date?
    var lastUptime: TimeInterval?

    /// Resist wall-clock rollback within a boot and across normal launches. This is not a server clock.
    mutating func advanceClock(now: Date, uptime: TimeInterval) -> Date {
        var effective = max(now, lastObservedAt ?? now)
        if let previous = lastObservedAt, let previousUptime = lastUptime, uptime >= previousUptime {
            effective = max(effective, previous.addingTimeInterval(uptime - previousUptime))
        }
        lastObservedAt = effective
        lastUptime = uptime
        return effective
    }
}

enum AccessState: String, Codable {
    case free, grandfathered, unknown, eligible, trial, expired, lifetime
    var allowsRedirects: Bool { [.free, .grandfathered, .trial, .lifetime].contains(self) }
    var canTip: Bool { self == .free || self == .grandfathered }
}

struct AccessDecision: Equatable {
    let state: AccessState
    let expiresAt: Date?
    var allowsRedirects: Bool { state.allowsRedirects }

    var title: String {
        switch state {
        case .free: return "Free access"
        case .grandfathered: return "Yours to keep"
        case .unknown: return "Let’s check your access"
        case .eligible: return "Meet your search companion"
        case .trial: return "Your 14 free days are underway"
        case .expired: return "Keep your searches flowing"
        case .lifetime: return "Yours for good"
        }
    }
    var message: String {
        switch state {
        case .free: return "Braver Search is free to use."
        case .grandfathered: return "You were here early. Your redirects stay free, always."
        case .unknown: return "Connect to the App Store to check your existing access. Setup help is always available."
        case .eligible: return "Try every redirect for 14 days. No automatic payment."
        case .trial: return "Enjoy every redirect. Choose a one-time price whenever you’re ready."
        case .expired: return "Your free trial is complete. Choose a price to bring your redirects back."
        case .lifetime: return "One payment. Every redirect. Thanks for supporting this little lion."
        }
    }
}

enum AccessPolicy {
    static func evaluate(_ record: AccessRecord, cutoff: Date?, now: Date) -> AccessDecision {
        func result(_ state: AccessState, _ expires: Date? = nil) -> AccessDecision { AccessDecision(state: state, expiresAt: expires) }
        guard let cutoff, now >= cutoff else { return result(.free) }
        // A verified original acquisition date takes precedence over local upgrade evidence.
        if let original = record.originalPurchaseDate {
            if original < cutoff { return result(.grandfathered) }
        } else if let firstUse = record.legacyFirstUse, firstUse < cutoff {
            return result(.grandfathered)
        }
        if record.lifetimeProducts.contains(where: AccessConfiguration.lifetimeIDs.contains) { return result(.lifetime) }
        if let start = record.trialStart {
            let expires = start.addingTimeInterval(AccessConfiguration.trialDuration)
            return result(now >= start && now < expires ? .trial : .expired, expires)
        }
        return result(record.originalPurchaseDate == nil ? .unknown : .eligible)
    }
}
