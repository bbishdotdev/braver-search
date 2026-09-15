# Monetization implementation and verification

Branch: `codex/lifetime-unlock`. Verification date: September 15, 2026.

**Implemented, with production enforcement intentionally disabled pending Apple setup and an announced grandfathering cutoff.** No App Store products were created, no real money was charged, and this work has not been merged or deployed to TestFlight.

## What is built

A shared native lifetime screen for iOS and macOS, a lion-art price slider, 14-day zero-price non-renewing trial, verified non-consumable unlocks, restore/approval/refund handling, legacy access with retained optional donations, and native extension access checks. The original tip IDs are preserved; lifetime IDs are new products. All paid prices unlock the same app.

The extension checks the native access decision before redirecting. Expired users' normal searches remain on their selected default search engine. Setup diagnostics remain available only for the current native test UUID and fixed diagnostic query. The native decision checks expiry locally on every search, without waiting for analytics or a network service.

## Passed checks

- **79 JavaScript tests**: existing URL/bang/navigation safeguards and setup recovery, expiry/missing access, rejection of arbitrary JS payment flags, failed native messages, fake setup tokens, refund/expiry recheck, late navigation responses, popup error explanations.
- **20 native policy checks plus clock checks**: cutoff boundaries, signed acquisition versus local legacy evidence, unknown users, exact 14-day expiry, allowlisted lifetime tiers, non-entitling tips, restored state and clock rollback.
- **Native telemetry/setup regression suite**: durable delivery, shared locking, setup proof, and rejection of expired/future/fabricated diagnostic IDs.
- **iOS simulator XCTest and Swift Testing suites**: local StoreKit product catalog, zero-price non-consumable trial, verified transaction delivery, original trial date recovered after clearing local state, lifetime access recovered after clearing local state, refund removal, then trial expiry.
- **iOS and macOS Debug builds**, including their Safari extensions.
- **iOS and macOS Release builds**, including their Safari extensions. `scripts/check-release-access.py` checks the built executables for absence of development fixture switches, verifies the packaged redirect gate and setup-recovery script, and rejects the obsolete upfront-paid launch key.

The StoreKit test uses Apple's `SKTestSession`, real locally verified StoreKit transactions, and isolated temporary native persistence. These are Xcode tests, not live App Store purchases. UI cohort screenshots use separate DEBUG-only fixtures. The production code cannot accept scenario launch arguments or test persistence injection.

## Actual iPhone simulator screenshots

Captured with `xcrun simctl io … screenshot` on the dedicated iPhone 16 simulator, iOS 18.6, using Xcode 16.4. These show the native implementation, not browser mockups. The local StoreKit catalog supplies the test prices; the cohort/expiry states are explicitly development fixtures.

| Screenshot | What it demonstrates |
|---|---|
| [Start free](monetization/screenshots/eligible.png) | Free trial is the primary action, before the optional price picker. |
| [Trial active](monetization/screenshots/trial.png) | Time-limited free access with an optional lifetime purchase. |
| [Trial complete](monetization/screenshots/expired.png) | Gold one-time unlock action, same lion art and warm dark surfaces. |
| [Highest tier](monetization/screenshots/legend-tier.png) | Price and lion illustration change with the selected tier. |
| [Lifetime unlocked](monetization/screenshots/lifetime.png) | Permanent access confirmation with purchase controls removed. |
| [Grandfathered](monetization/screenshots/grandfathered.png) | Explicit assurance that existing access stays free. |
| [Legacy home](monetization/screenshots/legacy-home.png) | Compact access summary integrated with existing setup UI; optional donations remain below the guide. The incomplete setup result here predates this monetization check. |
| [Large text](monetization/screenshots/accessibility.png) | Largest accessibility text wraps, with a fixed close control and scrolling content. Text size was restored to its prior “large” setting afterward. |

## Mac runtime status

The Mac now runs macOS 26.6.2 / Xcode 16.4. Both platform configurations compile, but **the hosted macOS tests are not a pass**: the ad-hoc test host stalled during shared-preferences access before executing tests. The developer-signed retry encountered stale development provisioning; automatic provisioning got past that issue, then codesign failed with `errSecInternalComponent` when accessing the existing private key. The exact local signing command and retry are in [the runbook](MONETIZATION-RUNBOOK.md#remaining-mac-runtime-signing-step). No physical iPhone installation or Mac Safari runtime success is claimed.

## Limits of this verification

- Simulator screenshots do not prove a production user's original App Store acquisition date or cross-device ownership. Those need a sandbox/TestFlight/real legacy-account check.
- Actual Safari end-to-end permission behavior with monetization enabled has not been reverified on a physical iPhone or Mac in this run. The redirect decision path is covered by native policy/StoreKit and actual background-script tests. Production enforcement remains disabled until the device checks in the runbook are complete.
- Pending, cancellation, unverified transaction and purchase-sheet overlap branches were implemented and reviewed; the automated StoreKit integration test focuses on success, restoration and revocation, rather than claiming every Apple UI interaction was automated.
- A device cannot instantly learn a refund while offline. The app reconciles on foreground and transaction updates. The extension makes best-effort verified transaction checks without erasing access when its own receipt is unavailable.
- Local clock protection resists simple rollback but is not a server-backed anti-tampering system. The signed original trial date prevents an ordinary reinstall from restarting the trial.
- Braver Search collects no payment information and the trial authorizes no charge or hold. Apple controls account authentication/verification; a no-payment-method account must be tested before promising Apple will never ask for billing information.

## What is needed from you before release

1. Create the **six new non-consumables**, including the free `braversearch.trial.14day`. Existing donation products cannot be repurposed into lifetime products. Exact IDs, prices, descriptions and Apple steps are in [the runbook](MONETIZATION-RUNBOOK.md#apple-setup--exact-products).
2. Choose the announced UTC grandfathering cutoff. It is deliberately unset; changing it activates the shared release policy for both apps and both extensions.
3. Complete the cross-device/legacy-account and real Safari checks from the runbook. Confirm the shared universal App Store record and the zero-price trial's Apple Account experience.

The full [runbook](MONETIZATION-RUNBOOK.md) documents migration evidence, trial start/expiry, offline behavior, redirect enforcement, refund safeguards, product setup, debug fixtures, remote commands, analytics events, and the release sequence.
