# Braver Search: 14-day trial and lifetime access

Implementation branch: `codex/lifetime-unlock`. Production enforcement is deliberately OFF: `AccessConfiguration.launchDate == nil`. This branch does not change the price of the download or create products in App Store Connect.

## Product experience

- Free download. The user explicitly starts a **14-day Trial**, a zero-price, non-consumable Apple in-app purchase. It is not a subscription, has no renewal, and authorizes no downstream payment or hold. Braver Search collects no payment details. Apple controls its authentication UI and may require account verification; we cannot guarantee Apple never requests billing/account information. Test with a real no-payment-method Apple Account before advertising that stronger guarantee.
- The free trial button appears before the optional lifetime price picker. The expiry and loss of redirect access are disclosed before starting.
- Lifetime prices: $4.99, $9.99 suggested, $24.99, $49.99, $99.99 in the US. All buy exactly the same access. Each is a separate non-consumable product, not a subscription or consumable tip.
- The slider uses the existing four lion illustrations, warm dark surfaces, rounded corners and gold actions. $25 and $50 share the existing lifesaver illustration. No invented “most popular” claim. VoiceOver names the selected tier and price; Reduce Motion suppresses transitions; content scrolls at larger text sizes.
- Actual checkout uses StoreKit's localized price. Missing/misconfigured products cannot be purchased; UI offers Retry App Store. Debug UI fixtures may display suggested US amounts, clearly separated from purchase availability.
- Legacy users keep optional donations with the original tip identifiers. New paid tiers must not reuse those identifiers.
- Help, setup instructions, and the current setup diagnostic remain available with no paid access. Expiry does not hijack Safari into a checkout; ordinary searches continue on the selected default search engine.

## Grandfathering

Select and announce one UTC cutoff immediately before the public monetization release. Do not use this development date implicitly.

1. Prefer the verified `AppTransaction.originalPurchaseDate`. Before the cutoff: grandfathered permanently; exactly at/after: new cohort. An app download is never proof of a lifetime IAP.
2. If Apple acquisition evidence is temporarily unavailable, a persisted first-use timestamp from before the cutoff preserves access for an existing installation. Verified acquisition evidence takes precedence if it subsequently arrives. This local fallback is upgrade evidence, not cryptographic proof.
3. The old `userState=grandfathered` boolean alone is ignored: older free builds wrote that for everyone. Post-cutoff first-use timestamps cannot grandfather someone.
4. iOS App Group preferences survive normal upgrades. Older Mac monetization preferences are migrated from the formerly unprefixed suite to the actual entitlement-derived App Group.
5. On another device or after reinstall, Apple's original acquisition date establishes the legacy cohort again. If a fresh installation has neither local evidence nor a verified receipt, the app shows “Let’s check your access” and offers Restore purchases; it does not sell an existing user a guessed entitlement.
6. With no configured cutoff, everyone retains free access and tips. A future cutoff also keeps access free until that date. The apps and extensions compile the same configuration file, preventing mismatched rollout dates.

## Trial and clock behavior

Trial access runs for exactly 14 × 24 hours from the verified trial transaction's original purchase date. Browsing, installation, or opening setup help does not start it. Reinstall/restore recovers the same start date; repurchasing the free non-consumable cannot create a second period. The endpoint is exclusive: at the expiry instant, ordinary redirects stop.

The local record retains the maximum observed clock and advances it with system uptime between calls. Turning the clock backward during a boot does not extend access, and a normal reboot cannot reduce the saved clock. Turning the clock far forward may expire the trial early. This is **not tamper-proof DRM**: root/jailbreak access, deleting all local state while manipulating time, or unusual reboot/clock combinations require server-side time/device enforcement to address completely. No server or per-search network dependency was added. Lifetime customers are not periodically forced online just to keep working.

## Redirect enforcement

`AccessPolicy.swift` is a pure policy shared by all four targets. `AccessStore.swift` stores the verified native record under the existing cross-process App Group file lock. Safari's background script requests `getRedirectAccess` before performing a redirect. Only `allowed: true` from native code permits it; JS storage flags, a generic `ok`, tip purchases, or made-up product IDs do not grant access. Native messaging failure denies that redirect and leaves the default search in place.

The native decision evaluates trial expiry on every search, even if the app has not been opened. It reads local storage, not PostHog or a web service. StoreKit refreshes in the app on foreground/transaction updates. The extension also makes a best-effort check for verified individual transactions at startup and on a later request after five minutes. An empty or unavailable extension receipt never erases host-app access, and background termination can postpone that check. Refunds therefore apply when StoreKit learns and reports them; they cannot be enforced instantly on an offline device. An access-record revision prevents an older asynchronous inventory scan from overwriting a newly delivered purchase or refund. Revoked transaction IDs are retained so delayed receipt data cannot regrant that same transaction.

Setup bypass requires the current native UUID, a non-future start less than ten minutes old, and the exact fixed diagnostic query. Appending `braver_setup` to an arbitrary search does not bypass payment. Diagnostic requests remain subject to the redirect toggle and URL safeguards. Navigation version tracking prevents an awaited native response from pulling a user back after navigating away.

The extension popup explains expired/missing access and links back to the app. It also shows a recovery message when its native access request fails.

## Purchases, restoration and refunds

- Only verified StoreKit non-consumable transactions for the allowlisted lifetime IDs grant lifetime access. The trial SKU must have price zero before it can be started through the app.
- Entitlements are persisted before `transaction.finish()`. Failed persistence leaves delivery retryable.
- `Transaction.updates` handles approvals and revocations; `currentEntitlements` reconciles the inventory on refresh. StoreKit maintains its local receipt for offline use. An empty inventory does not invent ownership.
- Restore purchases explicitly invokes `AppStore.sync()`, then refreshes acquisition and IAP evidence. This may request Apple authentication.
- Pending/cancelled/failed/unverified results do not unlock redirects. The app prevents concurrent purchase sheets and shows purchase/restore status.
- Refunding a lifetime tier removes that tier. Another valid purchased tier still grants access; otherwise the original trial's remaining time determines access.
- Tip deliveries are deduplicated by transaction ID. Tips never become lifetime unlock proof.
- iPhone/iPad/Mac ownership requires both platforms under the existing universal App Store record, using the same product IDs and Apple Account. App Groups alone do not sync across devices. Confirm the App Store record in the release checklist.

## Apple setup — exact products

Use App Store Connect → My Apps → Braver Search → Monetization → In-App Purchases. Create **Non-Consumable** for every row; identifiers are immutable.

| Product ID | Reference/display name | Suggested US price |
|---|---|---:|
| `braversearch.trial.14day` | 14-day Trial | Free / price tier 0 |
| `braversearch.lifetime.coffee` | Lifetime · A little love | $4.99 |
| `braversearch.lifetime.supporter` | Lifetime · A happy lion | $9.99 |
| `braversearch.lifetime.champion` | Lifetime · Big-hearted lion | $24.99 |
| `braversearch.lifetime.hero` | Lifetime · Lionhearted | $49.99 |
| `braversearch.lifetime.legend` | Lifetime · Legend | $99.99 |

Descriptions: trial — “14 days of search redirects. No automatic renewal or charge. After the trial, choose a separate lifetime purchase to continue redirects.” Paid — “Unlock all Braver Search redirects with one payment. Every lifetime price provides the same features.” Add localizations, availability and review screenshots, and complete the relevant agreements/tax/banking setup if Apple requests it. Keep the app download free.

Apple supports App Store Connect API product management, but no authenticated App Store Connect tool/CLI was available in this session. GitHub signing secrets are not a substitute for an exposed authorized API connection. These product entries still need creation in Apple; the local `.storekit` file does not create them.

Apple's documented non-subscription trial route: [App Review Guidelines 3.1.1](https://developer.apple.com/app-store/review/guidelines/#in-app-purchase). Product type: [non-consumable IAP](https://developer.apple.com/help/app-store-connect/reference/in-app-purchases-and-subscriptions/in-app-purchase-types/). [Universal purchase](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-platforms/).

## Development and verification

Local StoreKit catalog: `Braver Search/Shared (App)/Resources/Monetization.storekit`. The shared `AccessStoreTests` uses Apple's SKTestSession, with no real charges. It tests the verified free trial, original-date restoration, lifetime restoration and refund removal. The native pure-policy suite tests legacy/new/unknown cohorts, cutoff and expiry boundaries, allowlisted products and clock rollback. The existing setup suite tests bounded diagnostic IDs. JavaScript tests exercise actual background redirect gating and race recovery.

```bash
npm test -- --runInBand
bash scripts/test-access.sh       # Mac / Xcode
bash scripts/test-telemetry.sh     # Mac / Xcode
```

Remote checkout snapshot: `/Users/bishop/Work/braver-search-monetization-20260915` on `bishop@192.168.1.142`. Use `ssh -F /dev/null` on the PC because its unrelated default SSH configuration has a permissions problem. The dedicated iPhone simulator is `C6DFC7F9-981D-4450-AAF0-58A675549C8A`.

```bash
xcodebuild test -project 'Braver Search/Braver Search.xcodeproj' \
  -scheme 'Braver Search (iOS)' \
  -destination 'id=C6DFC7F9-981D-4450-AAF0-58A675549C8A' \
  -parallel-testing-enabled NO -derivedDataPath build/ios
```

Debug-only visual fixtures: launch the app with `-monetization-scenario eligible|trial|expired|lifetime|grandfathered|unknown`, optionally `-show-lifetime` and `-monetization-tier 0..4`. These populate a separate development record read by the debug app/extension; they do not forge a StoreKit purchase. Launch without the scenario flag to clear it. Release compiles out all fixture parsing and test persistence injection. Never use fixtures as evidence of production purchase, migration, or Safari permission behavior.

## Release checklist

1. Create and approve the six products; verify both iOS and macOS belong to the same universal app record. If adding the higher amounts later, the UI safely disables those missing options; at least trial and a paid tier must work before enforcement.
2. Verify a no-payment-method Apple Account can obtain the free trial under real App Store conditions. Apple's account prompts are outside the app's control.
3. Agree/announce the grandfathering cutoff. Set the single shared `AccessConfiguration.launchDate` to that exact UTC Date. Do not enable it via an unrelated remote analytics flag.
4. Sandbox/TestFlight on actual iPhone and Mac: start trial, use Safari with permissions on/off, restore on a second device, check a legacy App Store download's original date, and verify production SKU availability. Use the App Store sandbox refund tooling and check reconciliation.
5. Verify expiration with a development test clock, not by altering the personal device clock. Verify ordinary search remains on Google after expiry and the real current diagnostic still reaches Brave.
6. Archive Release and confirm fixture code is absent. Review the privacy-safe purchase events. Only then merge/release enforcement.

## Measurement

Events added: `lifetime_screen_viewed` (access_state), `lifetime_tier_selected` (product_id), `purchase_started`, `purchase_pending`, `purchase_cancelled`, `purchase_failed`, `access_purchase_verified`, `access_revoked`, `purchases_restored`, `redirect_access_blocked` (once per state/day). Existing durable delivery labels platform, version and development/production. No search queries or visited URLs are added.

Suggested PostHog views: new-cohort setup verified → trial verified → first ordinary redirect → lifetime verified; trial-expired cohort → price view → paid; purchase failures by product/platform/version; grandfathered users who unexpectedly see blocked access. Filter development traffic and split verified trial vs paid product IDs. Do not count selecting a slider tier as revenue or a diagnostic search as normal activation.

## Verified results and screenshots

See `MONETIZATION-VERIFICATION.md` for the completed checks, actual screenshots, limitations and remaining Apple-side release work.

## Remaining Mac runtime signing step

The remote Mac now reports **macOS 26.6.2**, with Xcode 16.4. Unsigned Debug and Release builds compile. The ad-hoc-signed hosted test stalled before tests began, inside macOS shared-preferences access. The project’s pinned Mac development profiles also did not include the current certificate/device; an automatic-provisioning retry got past that mismatch, but `codesign` then returned `errSecInternalComponent` for the existing Apple Development key.

On the Mac itself, run this in Terminal (do not send any password in chat):

```bash
/usr/bin/codesign --force \
  --sign 'Apple Development: Brenden Bishop (4DNC4UZ685)' \
  --timestamp=none \
  '/Users/bishop/Work/braver-search-monetization-20260915/build/mac-signed/Build/Products/Debug/Braver Search Extension.appex/Contents/MacOS/Braver Search Extension.debug.dylib'
```

If macOS asks to use the signing key, approve that request locally (Always Allow for codesign if desired). If the login keychain is locked, unlock it locally first. If signing still fails, open Xcode → Settings → Accounts, select the team, and inspect Manage Certificates; do not delete certificates or change broad keychain access controls as a shortcut.

Then retry:

```bash
cd /Users/bishop/Work/braver-search-monetization-20260915
xcodebuild test -project 'Braver Search/Braver Search.xcodeproj' \
  -scheme 'Braver Search (macOS)' -configuration Debug \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath build/mac-signed \
  -parallel-testing-enabled NO CODE_SIGN_STYLE=Automatic \
  PROVISIONING_PROFILE_SPECIFIER='' PROVISIONING_PROFILE='' \
  DEVELOPMENT_TEAM=A947N6H5GS CODE_SIGN_IDENTITY='Apple Development' \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration
```

These command-line development signing overrides do not alter the repository's App Store distribution signing configuration. If macOS shows an app-data access dialog during launch, inspect and approve it locally for this development build. The Mac runtime test is not counted as passing until that run actually completes.

## Local sandbox testing (production remains off)

Use a **Debug** build for this procedure. `AccessConfiguration.launchDate` stays nil.
In Xcode, Product → Scheme → Edit Scheme → Run → Arguments, add each token as a separate enabled argument:

```
-monetization-test-cohort
new
-show-lifetime
```

This selects a cutoff 24 hours before launch. For a stable explicit cutoff, also pass
`-monetization-test-cutoff` and an ISO8601 UTC value, for example `2026-09-15T00:00:00Z`.
Use a timestamp before the test begins, not a proposed public launch date.
The screen labels this as a local sandbox test.

Unlike `-monetization-scenario` screenshot fixtures, this mode does **not** manufacture
trial/lifetime ownership or skip StoreKit refresh. Disable all screenshot scenario
arguments when testing real purchases. Apple's sandbox app acquisition date is fixed
in 2013; a verified Sandbox/Xcode app transaction is required before the local cohort
override applies. Missing or Production evidence shows unknown access in test mode.
The original evidence is preserved; the policy evaluates a copy.

The host and extension share a separate `access-local-test-v1.json` record and local
configuration. Normal `access-v1.json` is untouched. Do not change the device clock.
To simulate expiry, add `-monetization-test-elapsed-days` and `15`, relaunch, then search
in Safari. This advances only the policy evaluation time; it does not rewrite the
verified transaction or the persisted real clock. A genuine verified lifetime purchase
still restores access. Change `new` to `legacy` to inspect grandfathered behavior.
Launching the Debug host without the local test arguments disables this mode for the
app and extension. These controls and files are not read by Release builds.

For Apple sandbox testing, disable the Xcode scheme's local StoreKit Configuration
(select None), use a Sandbox Apple Account, and verify the Apple purchase sheet identifies
the sandbox. The automated XCTest suite uses Monetization.storekit instead and incurs
no charges. Sandbox purchase history can be reset through App Store Connect's Sandbox
account controls; resetting it does not reset the local cached record until receipt
reconciliation. Reinstall alone does not prove a new production customer.

Test on iPhone and Mac with the same sandbox account: fresh trial, ordinary Safari search,
setup diagnostic, expiry, lifetime purchase, then Restore Purchases on the other device.
Also test cancellation and refund reconciliation. Legacy fixture success is separate
from the still-required genuine production upgrade/receipt test.

**TestFlight:** these DEBUG controls are intentionally absent. A review/TestFlight-safe
sandbox cohort path still needs implementation before an enabled release candidate;
do not set a modern production cutoff and assume a fresh sandbox account will be new.
Keep production enforcement disabled until this and the release timing are settled.

## Remote Mac signing from SSH

September 23 diagnosis: SSH and bishop's existing Aqua desktop used different
security sessions (observed audit session IDs 102806 and 100016). The SSH session
could enumerate the development identity but could not access keychain settings
or sign; a temporary launch job in `gui/501` could do both. Local signing success
does not guarantee keychain access in a separate SSH session. Do not repeatedly
request unlocks or broaden the private key ACL when this comparison explains the
failure. Apple's [multiple-user documentation](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPMultipleUsers/)
describes SSH connections as separate login sessions.

Run the following **on the Mac checkout**, including via SSH as bishop:

```bash
cd /Users/bishop/Work/braver-search-monetization-20260915
/usr/bin/python3 scripts/run-in-macos-session.py -- \
  /usr/bin/xcodebuild build \
  -project 'Braver Search/Braver Search.xcodeproj' \
  -scheme 'Braver Search (macOS)' \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/mac-signed-desktop \
  CODE_SIGN_STYLE=Automatic \
  PROVISIONING_PROFILE_SPECIFIER='' PROVISIONING_PROFILE='' \
  DEVELOPMENT_TEAM=A947N6H5GS CODE_SIGN_IDENTITY='Apple Development' \
  -allowProvisioningUpdates
```

The helper targets the calling user's existing GUI session, streams output,
returns the command's result, and unregisters its one-shot job on completion or
timeout. Logs remain at the printed temporary directory. It does not unlock a
keychain, alter permissions, store credentials, or install a persistent agent.
It requires that user's desktop session to remain logged in. The launched command
uses the desktop environment rather than inheriting SSH environment variables;
provide build settings explicitly as above. Use separate derived-data directories
for app builds and test builds: the old `build/mac-signed` contained an invalid
leftover `Braver Search macOS Tests.xctest`, which independently blocked bundle
signing after key access was resolved.

Validated output:
`build/mac-signed-desktop/Build/Products/Debug/Braver Search.app`.
Both the app and embedded `Braver Search Extension.appex` passed
`codesign --verify --strict --verbose=2`, signed with Apple Development team
A947N6H5GS. This confirms build/signature integrity, not Safari runtime behavior,
App Store product availability, or cross-device purchase restoration.
