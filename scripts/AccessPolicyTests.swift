import Foundation

@main struct AccessPolicyTests {
    static func main() {
        var checks = 0
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
        var clock = AccessRecord()
        precondition(clock.advanceClock(now: now, uptime: 100) == now)
        precondition(clock.advanceClock(now: now.addingTimeInterval(-86400), uptime: 160) == now.addingTimeInterval(60))
        precondition(clock.advanceClock(now: now.addingTimeInterval(-86400), uptime: 1) == now.addingTimeInterval(60))
        let restored = try! JSONDecoder().decode(AccessRecord.self, from: JSONEncoder().encode(fresh))
        expect(restored, .expired, at: now.addingTimeInterval(20 * 86400))
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
