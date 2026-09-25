import Foundation

@main struct AccessPolicyTests {
    static func main() {
        var checks = 0
        let releaseCutoff = AccessConfiguration.launchDate!
        precondition(ISO8601DateFormatter().string(from: releaseCutoff) == "2026-10-09T00:00:00Z")
        let existingOwner = AccessRecord(originalPurchaseDate: releaseCutoff.addingTimeInterval(-1))
        let newOwner = AccessRecord(originalPurchaseDate: releaseCutoff)
        precondition(AccessPolicy.evaluate(existingOwner, cutoff: releaseCutoff, now: releaseCutoff.addingTimeInterval(-1)).state == .free)
        precondition(AccessPolicy.evaluate(existingOwner, cutoff: releaseCutoff, now: releaseCutoff).state == .grandfathered)
        precondition(AccessPolicy.evaluate(newOwner, cutoff: releaseCutoff, now: releaseCutoff).state == .eligible)
        let cutoff = Date(timeIntervalSince1970: 1_800_000_000)
        let now = cutoff.addingTimeInterval(30 * 86400)
        func expect(_ record: AccessRecord, _ state: AccessState, at: Date? = nil, launch: Date? = nil) {
            let result = AccessPolicy.evaluate(record, cutoff: launch ?? cutoff, now: at ?? now)
            precondition(result.state == state, "Expected \(state), received \(result.state)")
            checks += 1
        }
        var fresh = AccessRecord(originalPurchaseDate: cutoff)
        expect(fresh, .eligible) // Boundary belongs to the new cohort, never 'paidAppCustomer'.
        expect(AccessRecord(), .unknown)
        expect(AccessRecord(originalPurchaseDate: cutoff.addingTimeInterval(-1)), .grandfathered)
        expect(AccessRecord(legacyFirstUse: cutoff.addingTimeInterval(-1)), .grandfathered)
        expect(AccessRecord(legacyFirstUse: cutoff), .unknown)
        expect(AccessRecord(originalPurchaseDate: cutoff, legacyFirstUse: cutoff.addingTimeInterval(-1)), .eligible)
        expect(AccessRecord(), .free, at: cutoff.addingTimeInterval(-1))
        precondition(AccessPolicy.evaluate(fresh, cutoff: nil, now: now).state == .free)
        fresh.trialStart = now
        expect(fresh, .trial)
        expect(fresh, .trial, at: now.addingTimeInterval(14 * 86400 - 1))
        expect(fresh, .expired, at: now.addingTimeInterval(14 * 86400))
        expect(fresh, .expired, at: now.addingTimeInterval(-1)) // Future trial dates do not grant access.
        fresh.lifetimeProducts = [AccessConfiguration.lifetimeIDs[0]]
        expect(fresh, .lifetime, at: now.addingTimeInterval(20 * 86400))
        fresh.lifetimeProducts = [] // Revoked purchase; original trial remains expired.
        expect(fresh, .expired, at: now.addingTimeInterval(20 * 86400))
        fresh.lifetimeProducts = ["braversearch.tip.max", "fabricated"]
        expect(fresh, .expired, at: now.addingTimeInterval(20 * 86400))
        for id in AccessConfiguration.lifetimeIDs {
            expect(AccessRecord(lifetimeProducts: [id]), .lifetime)
        }
        for state in [AccessState.eligible, .trial, .expired, .lifetime, .unknown] {
            precondition(!state.canTip, "Monetized and unverified users must not see donations")
        }
        precondition(AccessState.grandfathered.canTip)
        var clock = AccessRecord()
        precondition(clock.advanceClock(now: now, uptime: 100) == now)
        precondition(clock.advanceClock(now: now.addingTimeInterval(-86400), uptime: 160) == now.addingTimeInterval(60))
        precondition(clock.advanceClock(now: now.addingTimeInterval(-86400), uptime: 1) == now.addingTimeInterval(60))
        let restored = try! JSONDecoder().decode(AccessRecord.self, from: JSONEncoder().encode(fresh))
        expect(restored, .expired, at: now.addingTimeInterval(20 * 86400))
        // Exercise the same release policy for production, TestFlight and Xcode receipts.
        for environment in ["Production", "Sandbox", "Xcode"] {
            var record = AccessRecord(originalPurchaseDate: Date(timeIntervalSince1970: 1375340400),
                                      appTransactionEnvironment: environment,
                                      legacyFirstUse: cutoff.addingTimeInterval(-1))
            precondition(AccessPolicy.evaluate(record, cutoff: nil, now: now).state == .free)
            expect(record, .free, at: cutoff.addingTimeInterval(-1))
            expect(record, .grandfathered)
            record.trialStart = now.addingTimeInterval(-15 * 86400)
            expect(record, .grandfathered) // An expired test trial cannot override original ownership.
            record.originalPurchaseDate = cutoff
            record.trialStart = nil
            expect(record, .eligible)
            record.trialStart = now
            expect(record, .trial)
            expect(record, .expired, at: now.addingTimeInterval(14 * 86400))
            record.lifetimeProducts = [AccessConfiguration.thanksLifetimeID]
            expect(record, .lifetime)
            precondition(record.originalPurchaseDate == cutoff, "Evaluation must preserve acquisition evidence")
        }
        var beta = AccessRecord(originalPurchaseDate: now, appTransactionEnvironment: "Sandbox", trialStart: now,
                                lifetimeProducts: [AccessConfiguration.thanksLifetimeID])
        beta.setVerifiedAcquisition(date: now, environment: "Production")
        precondition(beta.trialStart == nil && beta.lifetimeProducts.isEmpty)
        precondition(AccessPolicy.evaluate(beta, cutoff: nil, now: now).state == .free)
        expect(beta, .eligible)
        beta.setVerifiedAcquisition(date: cutoff.addingTimeInterval(-1), environment: "Production")
        expect(beta, .grandfathered)
        beta.trialStart = now
        beta.setVerifiedAcquisition(date: beta.originalPurchaseDate!, environment: "Production")
        precondition(beta.trialStart == now, "Refreshing the same environment preserves purchases")
        beta.setVerifiedAcquisition(date: now, environment: "Sandbox")
        precondition(beta.trialStart == nil, "Purchases must remain isolated between StoreKit environments")
        print("Release policy: environment parity, grandfathering and purchase-isolation checks passed.")
        #if DEBUG
        let test = LocalAccessTest(cohort: .new, cutoff: cutoff, elapsedDays: 0)
        let legacyTest = LocalAccessTest(cohort: .legacy, cutoff: cutoff, elapsedDays: 0)
        var sandbox = AccessRecord(originalPurchaseDate: Date(timeIntervalSince1970: 1375340400), appTransactionEnvironment: "Sandbox")
        precondition(test.decision(record: sandbox, now: now).state == .eligible)
        precondition(legacyTest.decision(record: sandbox, now: now).state == .grandfathered)
        precondition(test.decision(record: AccessRecord(), now: now).state == .unknown)
        var production = sandbox
        production.appTransactionEnvironment = "Production"
        precondition(test.decision(record: production, now: now).state == .unknown)
        precondition(AccessPolicy.evaluate(sandbox, cutoff: cutoff, now: now).state == .grandfathered,
            "Test evaluation must not alter production acquisition evidence")
        sandbox.trialStart = now
        precondition(test.decision(record: sandbox, now: now).state == .trial)
        let expiredTest = LocalAccessTest(cohort: .new, cutoff: cutoff, elapsedDays: 15)
        precondition(expiredTest.decision(record: sandbox, now: now).state == .expired)
        sandbox.lifetimeProducts = [AccessConfiguration.lifetimeIDs[0]]
        precondition(expiredTest.decision(record: sandbox, now: now).state == .lifetime)
        print("Local sandbox cohort: 8 isolation, verification, real entitlement and expiry checks passed.")
        #endif
        print("Access policy: \(checks) cohort, boundary, restoration, entitlement and expiry checks passed; rollback checks passed.")
    }
}
