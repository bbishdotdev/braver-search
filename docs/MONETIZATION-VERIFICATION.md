# Monetization implementation and verification

Branch: `codex/lifetime-unlock`. Verification date: September 15, 2026.

## Follow-up: catalog and independent product copy

The six non-consumables have since been created in App Store Connect, with US prices of $0.00, $4.99, $9.99, $24.99, $49.99 and $99.99, worldwide availability, English localization and review notes. They remain drafts. Screenshot uploads were unsuccessful; none were attached. Both iOS and macOS are visible under the same app record. The user reports completing the local Mac signing step; signed runtime validation still needs a fresh successful run.

Promotional references to “Brave” have been removed from the shared purchase/trial copy. The headlines are now “Meet your search companion,” “Your 14 free days are underway,” “Keep your searches flowing,” and “Yours for good.” The $24.99 tier is “Big-hearted lion.” Product IDs, prices and access behavior are unchanged. Factual destination/website-permission references and the existing non-affiliation disclaimer remain. The existing 20 native policy checks and rollback checks pass after the change.

Fresh [in-app purchase review captures](monetization/review-screenshots/README.md) now show the updated copy and all five selected prices, captured directly from an iPhone 13 Pro Max simulator at 1284 × 2778. The older screenshots below document the earlier design and still contain the previous wording. The implementation-time results and outstanding checks below are preserved as the original verification record.

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

## Local sandbox follow-up (September 16 UTC)

- Added DEBUG-only new/legacy cohort testing with yesterday's cutoff, separate app/extension
  access storage, a verified Sandbox/Xcode acquisition requirement, and a policy-only
  elapsed-days control. Real verified transactions are still required for trial and lifetime.
- iOS 18.6 / Xcode 16.4: both AccessStore XCTest cases passed, including real local
  StoreKit transactions, trial/restoration/refund, test-record isolation and expiry;
  all five XCTest cases plus the existing Swift Testing example passed.
- 79 JavaScript tests and 20 production policy checks plus 8 local test checks passed.
- Diagnosed run 34931737619: compilation completed, then no iOS test results were emitted
  before the six-hour cancellation. macOS never ran. The log does not establish the
  precise reason the test runner stalled. CI now separates platforms, explicitly boots
  iOS, disables parallel StoreKit test execution, pins Xcode 16.4/macOS 15, bounds time,
  and retains logs/results. Remote CI success is not yet claimed.
- Retried signed Mac testing: codesign still fails with errSecInternalComponent for the
  development private key. User-local unlock/key access is pending.
- The user successfully attached older donation artwork in App Store Connect. The new
  6.9-inch native PNG captures are in the Mac Downloads folder; accepted review imagery
  still needs to match the offers before submission.
- Production cutoff remains nil. This DEBUG test mode is not a TestFlight cohort solution,
  and no real App Store sandbox purchase or cross-device restore is claimed here.

The bounded CI rerun exposed a specific iOS timeout inside the first StoreKit test,
with an App Store authentication-context error during host startup. Mac CI passed.
Unit-test hosts now skip normal app startup/StoreKit work and use isolated preferences;
local Mac tests now run instead of waiting on shared preferences. Receipt-restoration
assertions poll the asynchronous StoreKit inventory for up to five seconds. All six
Mac XCTest cases plus its Swift Testing example passed locally with ad-hoc signing;
this is not a developer-signed Safari runtime pass. The cold-simulator test initializes
its local StoreKit catalog before asking for AppTransaction.

The setup dashboard now has two validated release-build views (Debug excluded;
TestFlight still included): outcomes by result and a 30-minute start→success funnel.
Purchase/access events are absent from the live schema, so monetization views remain
pending real event validation. See docs/LOCAL-PURCHASE-TESTING.md for the user walkthrough.
