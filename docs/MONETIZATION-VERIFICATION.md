# Monetization implementation and verification

Branch: `codex/lifetime-unlock`. Latest verification: September 23, 2026.

## Current status — September 23

This summary and the September 23 follow-ups supersede the historical implementation
record below. In particular, the old missing-products, signing, and uninstalled-phone
notes are not current blockers.

- Seven non-consumables are configured in App Store Connect: one free 14-day trial
  and six lifetime tiers at $2.99, $4.99, $9.99, $24.99, $49.99, and $99.99 US.
  The new `braversearch.lifetime.thanks` entry is Apple ID **6815506243**, at $2.99
  with worldwide availability. All seven products show **Ready for Review** in the
  existing draft submission. All six lifetime products have updated native review
  screenshots and six-tier review notes; this is not Apple approval or submission.
- The six-tier app has new matching High five! and Now that’s love! artwork, with
  $9.99 Cheers! suggested. Signed iPhone and Mac builds passed; the app is installed
  and launched on Brenden's iPhone for manual testing.
- Final local StoreKit suites passed: iOS **5 XCTest + 1 Swift Testing** and macOS
  **6 XCTest + 1 Swift Testing**, including the new $2.99 restoration/refund case.
  A verified-transaction fallback fixes a reproduced missing entitlement-inventory
  edge. Detailed evidence and Mac log paths appear in the last section.
- Real Apple sandbox purchases, cross-device restoration, signed Safari runtime,
  genuine legacy upgrades, and the no-payment-method account experience are not
  established by these local tests. Apple review and a public activation cutoff
  remain outstanding. `AccessConfiguration.launchDate` is still nil; production
  monetization enforcement is off.

Current native simulator screenshots (visual fixtures, not live purchases):
[Trial](monetization/six-tier-flow/trial.png),
[Thanks!](monetization/six-tier-flow/thanks.png),
[High five!](monetization/six-tier-flow/high-five.png),
[Cheers!](monetization/six-tier-flow/cheers.png),
[You’re a lifesaver!](monetization/six-tier-flow/lifesaver.png),
[Now that’s love!](monetization/six-tier-flow/love.png), and
[I can’t thank you enough!](monetization/six-tier-flow/gratitude.png).
See [artwork provenance](monetization/artwork.md) for the two new illustrations.

Before release, complete real-device purchase/restore/Safari and legacy-account
checks, attach the finished products to the app update and obtain Apple approval,
then announce and configure the UTC grandfathering cutoff. Product creation and
Mac signing are no longer tasks the user needs to repeat.

## Historical implementation record

The following September 15–16 notes preserve what was true at each checkpoint.
Their earlier product counts, artwork, copy, signing failures, and pending tasks
are superseded by the current summary and subsequent dated follow-ups.

### Historical follow-up: catalog and independent product copy

The six non-consumables have since been created in App Store Connect, with US prices of $0.00, $4.99, $9.99, $24.99, $49.99 and $99.99, worldwide availability, English localization and review notes. They remain drafts. Screenshot uploads were unsuccessful; none were attached. Both iOS and macOS are visible under the same app record. The user reports completing the local Mac signing step; signed runtime validation still needs a fresh successful run.

Promotional references to “Brave” have been removed from the shared purchase/trial copy. The headlines are now “Meet your search companion,” “Your 14 free days are underway,” “Keep your searches flowing,” and “Yours for good.” The $24.99 tier is “Big-hearted lion.” Product IDs, prices and access behavior are unchanged. Factual destination/website-permission references and the existing non-affiliation disclaimer remain. The existing 20 native policy checks and rollback checks pass after the change.

Fresh [in-app purchase review captures](monetization/review-screenshots/README.md) now show the updated copy and all five selected prices, captured directly from an iPhone 13 Pro Max simulator at 1284 × 2778. The older screenshots below document the earlier design and still contain the previous wording. The implementation-time results and outstanding checks below are preserved as the original verification record.

**Initial implementation checkpoint (September 15):** production enforcement was intentionally disabled pending Apple setup and an announced cutoff. At that checkpoint, no App Store products had been created, no real money had been charged, and this work had not been merged or deployed to TestFlight.

## What is built

A shared native lifetime screen for iOS and macOS, a lion-art price slider, 14-day zero-price non-renewing trial, verified non-consumable unlocks, restore/approval/refund handling, legacy access with retained optional donations, and native extension access checks. The original tip IDs are preserved; lifetime IDs are new products. All paid prices unlock the same app.

The extension checks the native access decision before redirecting. Expired users' normal searches remain on their selected default search engine. Setup diagnostics remain available only for the current native test UUID and fixed diagnostic query. The native decision checks expiry locally on every search, without waiting for analytics or a network service.

## Historical passed checks (initial implementation)

- **79 JavaScript tests**: existing URL/bang/navigation safeguards and setup recovery, expiry/missing access, rejection of arbitrary JS payment flags, failed native messages, fake setup tokens, refund/expiry recheck, late navigation responses, popup error explanations.
- **20 native policy checks plus clock checks**: cutoff boundaries, signed acquisition versus local legacy evidence, unknown users, exact 14-day expiry, allowlisted lifetime tiers, non-entitling tips, restored state and clock rollback.
- **Native telemetry/setup regression suite**: durable delivery, shared locking, setup proof, and rejection of expired/future/fabricated diagnostic IDs.
- **iOS simulator XCTest and Swift Testing suites**: local StoreKit product catalog, zero-price non-consumable trial, verified transaction delivery, original trial date recovered after clearing local state, lifetime access recovered after clearing local state, refund removal, then trial expiry.
- **iOS and macOS Debug builds**, including their Safari extensions.
- **iOS and macOS Release builds**, including their Safari extensions. `scripts/check-release-access.py` checks the built executables for absence of development fixture switches, verifies the packaged redirect gate and setup-recovery script, and rejects the obsolete upfront-paid launch key.

The StoreKit test uses Apple's `SKTestSession`, real locally verified StoreKit transactions, and isolated temporary native persistence. These are Xcode tests, not live App Store purchases. UI cohort screenshots use separate DEBUG-only fixtures. The production code cannot accept scenario launch arguments or test persistence injection.

## Historical iPhone simulator screenshots (initial design)

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

## Historical Mac runtime status (before signing fix)

The Mac now runs macOS 26.6.2 / Xcode 16.4. Both platform configurations compile, but **the hosted macOS tests are not a pass**: the ad-hoc test host stalled during shared-preferences access before executing tests. The developer-signed retry encountered stale development provisioning; automatic provisioning got past that issue, then codesign failed with `errSecInternalComponent` when accessing the existing private key. The exact local signing command and retry are in [the runbook](MONETIZATION-RUNBOOK.md#remaining-mac-runtime-signing-step). No physical iPhone installation or Mac Safari runtime success is claimed.

## Limits of this verification

- Simulator screenshots do not prove a production user's original App Store acquisition date or cross-device ownership. Those need a sandbox/TestFlight/real legacy-account check.
- Actual Safari end-to-end permission behavior with monetization enabled has not been reverified on a physical iPhone or Mac in this run. The redirect decision path is covered by native policy/StoreKit and actual background-script tests. Production enforcement remains disabled until the device checks in the runbook are complete.
- Pending, cancellation, unverified transaction and purchase-sheet overlap branches were implemented and reviewed; the automated StoreKit integration test focuses on success, restoration and revocation, rather than claiming every Apple UI interaction was automated.
- A device cannot instantly learn a refund while offline. The app reconciles on foreground and transaction updates. The extension makes best-effort verified transaction checks without erasing access when its own receipt is unavailable.
- Local clock protection resists simple rollback but is not a server-backed anti-tampering system. The signed original trial date prevents an ordinary reinstall from restarting the trial.
- Braver Search collects no payment information and the trial authorizes no charge or hold. Apple controls account authentication/verification; a no-payment-method account must be tested before promising Apple will never ask for billing information.

## Historical release checklist (superseded above)

1. At this checkpoint, create the **six new non-consumables**, including the free `braversearch.trial.14day`. Existing donation products cannot be repurposed into lifetime products. Exact IDs, prices, descriptions and Apple steps are in [the runbook](MONETIZATION-RUNBOOK.md#apple-setup--exact-products).
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

## Signed Mac build follow-up (September 23)

- The final September 16 CI run 35051844031 at commit 4340fcc passed iOS, macOS,
  and JavaScript jobs. This is historical evidence for that commit, not a claim
  about checks on later commits.
- Confirmed remote-only signing failure: bishop's SSH and Aqua desktop have
  distinct security sessions. Desktop-session signing succeeded without new
  keychain permissions or credentials, while SSH signing still failed.
- Added `scripts/run-in-macos-session.py` to submit a one-shot command to the
  existing desktop session and remove its job afterward. The actual signed Mac
  build succeeded using this helper.
- Used fresh `build/mac-signed-desktop` derived data after finding an invalid
  leftover test bundle in the older `build/mac-signed` app output.
- Strict signature verification passed for the complete Mac app and its Safari
  extension, using Apple Development team A947N6H5GS.
- Signed Safari runtime, real Apple sandbox transactions, iPhone deployment,
  cross-platform restoration, genuine legacy upgrades, and production/TestFlight
  activation remain separate outstanding checks. Production cutoff remains nil.

## Trial and purchase UX follow-up (September 23)

- Eligible users first see a trial introduction, with no price picker. "See lifetime
  prices" opens the separate lifetime page, with Back navigation. Trial/expired users
  open pricing directly; grandfathered users retain the existing donation flow.
- The trial introduction explains Safari address-bar search redirection, states the
  duration once, and places "No automatic charge" above the action. A verified trial
  activation dismisses the offer; cancellation/pending approval does not grant access.
- The lifetime page omits the large introductory heading to give its lion artwork
  and playful tier descriptions more room. Tier text reserves consistent space,
  and the entire card no longer animates on each selection.
  The iOS control uses a continuous drag without haptic calls; VoiceOver adjustments
  still select discrete prices. macOS retains its native slider.
- The primary action stays outside the scrolling content. The sandbox cohort footer
  exists only in DEBUG local-test mode and has no production replacement.
- Gold emphasizes the primary trial action. The no-charge reassurance keeps its gold check, lifetime pricing
  is an underlined secondary link, and a divider separates purchase restoration.
- Restore purchases uses an outlined neutral secondary button with a restore icon,
  a 44-point minimum target, and a progress indicator while checking with Apple.
- Signed iPhone and Mac builds and a simulator build passed with Xcode 26.6. The
  device build was installed and launched on Brenden's iPhone for manual sandbox QA.
  Simulator images exercise visual fixtures, not actual purchases; physical haptic
  feel and a completed Apple sandbox purchase still require the user's verification.
- Trial-offer, lifetime-pricing, and access-status page views now have separate events.
  No access-policy rules or production activation settings were changed.

Native iPhone 16 Pro simulator captures: [trial introduction](monetization/two-screen-flow/trial.png)
and [compact lifetime pricing](monetization/two-screen-flow/lifetime.png). These use
the existing eligible/expired visual fixtures; the phone uses real sandbox-test mode.

## Six-tier artwork and pricing follow-up (September 23)

- The lifetime selector now offers $2.99 Thanks!, $4.99 High five!, $9.99 Cheers!,
  $24.99 You’re a lifesaver!, $49.99 Now that’s love!, and $99.99 I can’t thank you enough!.
  Only the $2.99 product has a new identifier; all previously configured lifetime IDs
  remain stable. Donations keep their original prices, products, artwork, and names.
- The $9.99 default and suggested badge follow the supporter product ID, so inserting
  a lower-priced option does not silently change the suggested purchase. Both native
  and custom slider ranges follow the catalog size, including VoiceOver and fixtures.
- High five! and Now that’s love! reference dedicated artwork; the other four tiers
  reuse the matching donation illustrations. The trial screen restores the gold
  no-charge reassurance and adds a warm charcoal background with a subtle amber glow.
- StoreKit catalog coverage now checks the exact product IDs and the new $2.99 price.
  The restoration/refund integration scenario exercises the new entry-level purchase.
  Pure-policy coverage continues to check every allowlisted lifetime product and now
  explicitly rejects donation visibility for trial, expired, and lifetime states.
- Found and reproduced a StoreKit restoration edge in Xcode 26.6: after finishing the
  trial, `Transaction.currentEntitlements` returned an empty inventory through 50 polls,
  while `Transaction.latest(for:)` already returned its verified non-consumable transaction.
  This failed both in the full Mac suite and with the restoration test isolated.
- Host refresh now checks individual transactions for missing allowlisted products.
  Only verified, unrevoked, non-upgraded non-consumables can restore access. Trial
  restoration retains the original purchase date; it never restarts the 14 days.
  The existing revision guard rejects scans overtaken by purchase/refund delivery,
  and remembered revoked transaction IDs are filtered before saving either paid or
  trial access. No acquisition cutoff, trial duration, or price-based access rule changed.
- With that fix, the complete Mac suite passed at 20:43:50 on September 23:
  **6 XCTest tests and 1 Swift Testing example**. The integration scenario covered
  trial restoration, the new $2.99 lifetime purchase and restoration, refund removal,
  and extension reconciliation without reviving the refunded purchase.
  Mac log: `/tmp/braver-six-test-mac-fixed.log`; result bundle:
  `/tmp/braver-six-test-mac/Logs/Test/Test-Braver Search (macOS)-2026.09.23_20-43-42--0700.xcresult`.
- The complete iOS simulator suite passed at 20:45:40:
  **5 XCTest tests and 1 Swift Testing example**. Log: `/tmp/braver-ux-sim.log`;
  result bundle: `/tmp/braver-ux-sim/Logs/Test/Test-Braver Search (iOS)-2026.09.23_20-45-17--0700.xcresult`.
  These timestamps are the Mac's local time; paths above are on the Mac.
- Final signed iPhone and Mac builds passed with the fix included. The iPhone build
  was installed and launched for manual testing. Logs on the Mac:
  `/tmp/braver-ux-iphone.log` and `/tmp/braver-ux-mac.log`.
- Automated purchase results use Xcode's local StoreKit catalog, not Apple's live
  sandbox or TestFlight. Real product availability, actual sandbox purchases,
  cross-device restoration, no-payment-method account behavior, and signed Safari
  runtime remain separate release checks. Production activation remains disabled.

## App Store Connect catalog update — September 23

Verified through the user’s Brave App Store Connect tab after saving each change:

| US price | App tier | Product ID suffix | Apple ID | State |
| --- | --- | --- | --- | --- |
| Free | 14-day Trial | `trial.14day` | 6812554033 | Ready for Review |
| $2.99 | Thanks! | `lifetime.thanks` | 6815506243 | Ready for Review |
| $4.99 | High five! | `lifetime.coffee` | 6812558291 | Ready for Review |
| $9.99 | Cheers! | `lifetime.supporter` | 6812559175 | Ready for Review |
| $24.99 | You’re a lifesaver! | `lifetime.champion` | 6812559628 | Ready for Review |
| $49.99 | Now that’s love! | `lifetime.hero` | 6812560112 | Ready for Review |
| $99.99 | I can’t thank you enough! | `lifetime.legend` | 6812560922 | Ready for Review |

All IDs are prefixed `braversearch.`. Existing IDs/prices were preserved; Thanks!
is the new non-consumable, US base $2.99 with Apple-generated regional prices and
all countries/regions selected. Existing approved consumable tips were untouched.
English lifetime display names use `Lifetime · <tier>`, with `Lifetime · Endless
thanks!` for the longest tier to fit Apple’s field. Their shared description is
“Lifetime Safari search redirects. No subscription.” Each lifetime product now
has its matching native simulator screenshot and review notes explaining the six
equal-access prices. Products were temporarily removed from the existing draft
to unlock metadata editing, then restored to that same draft. Nothing was sent
for final review or released.

Final screenshot copies are also on the Mac at
`/Users/bishop/Downloads/Braver-Search-Six-Tiers/`. The iPhone build was installed
and launched with the existing DEBUG new-user sandbox arguments at 20:46 on the
Mac clock. A real Apple sandbox checkout still needs manual verification; the
passing StoreKitTest suites and screenshot fixtures do not establish it.
