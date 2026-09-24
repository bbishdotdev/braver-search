# App Review readiness — September 24, 2026

## 1. Executive summary

- Braver Search redirects supported Safari searches; the app provides setup, diagnostics, and Apple purchases.
- The trial is a **free non-consumable**, not a consumable or subscription. Six non-consumable lifetime prices grant identical access.
- **Public release is not ready:** the production activation/grandfathering cutoff is unset.
- **Privacy disclosure needs correction:** live App Store Connect says Data Not Collected, contrary to the shipped PostHog event transport.
- The live privacy policy is reachable, but its four-event list and statement that access status stays on-device are outdated.
- Added required-reason privacy declarations for UserDefaults and system uptime, and direct privacy links in both apps; all four Release bundle manifests validate.
- TestFlight/App Review sandbox acquisitions need a new-user path because Apple supplies a fixed 2013 acquisition date. This branch now implements it using verified StoreKit evidence.
- iPhone sandbox purchase/enforcement lifecycle was confirmed by the owner. Mac Safari and cross-device restoration still need actual runtime verification.

## 2. Risk register

| Priority | Area | Finding / review risk | Evidence | Recommendation | Effort | Confidence |
|---|---|---|---|---|---|---|
| P0 | IAP | Public build currently keeps access free; cannot launch the intended paid model as-is | `AccessConfiguration.launchDate == nil` | Choose announced UTC cutoff after product approval and ship a final configured build | S | High |
| P1 | Privacy | Published Data Not Collected label conflicts with telemetry | ASC App Privacy, read live Sep 24; `DurableAnalytics.capture` | Owner must update labels for actual collection; check PostHog server settings too | S | High |
| P1 | Privacy | Public policy lists only four events and says access status is not sent | `https://www.bbish.dev/braver-search/privacy`; `StoreManager.deliver`, `LifetimeAccessView.recordPageView` | Update policy with setup diagnostics, access state, product/purchase outcomes and retention practices | S | High |
| P1 → fixed | Privacy | Required-reason API manifest absent at start of audit | UserDefaults and `ProcessInfo.systemUptime` in shared native code | Bundle a manifest in both apps and extensions; verify built bundles | S | High |
| P1 | Technical | Native Mac Safari purchase/gating/restore not established | Remote signed hosted test stalls in OS sandbox initialization before app code | Manual Mac TestFlight matrix below, including cross-device restore | M | High |
| P2 → fixed | UX | No direct in-app privacy policy link | iOS MainView footer; Mac Main.html footer | Add clearly labeled link to existing policy URL on both platforms | S | High |
| P2 | IAP | Trial screen states duration and purchase requirement, but price is on a separate accessible screen | `LifetimeAccessView.actions` | Include localized minimum lifetime price beside expiry consequence before starting the trial | S | Medium |

## 3. Detailed findings

### Privacy and data handling

The custom HTTPS PostHog client sends a persistent random installation identifier, event name/time, platform, version, source, setup diagnostics, access state, selected product IDs and purchase outcomes. There is no search-query/full-URL collection in that native transport. Purchase transaction IDs are used locally for deduplication, not intentionally included in the event payload. No third-party analytics SDK is linked.

The public policy is **not** evidence that the ASC privacy label is correct. The label currently says no collection. Suggested categories to evaluate are Device ID, Product Interaction, Purchase History and Other Diagnostic Data, for analytics. Decide linked/not-linked using Apple's definition, not merely the word anonymous: events use a persistent installation identifier. Inspect PostHog IP enrichment, retention and other server-side processing before publishing declarations. No cross-company advertising tracking is evident in the repository; ATT is not required merely because first-party analytics exist.

Verify policy updates at the live URL and compare them with actual payloads and ASC labels. Public policy publication and ASC label changes are separate owner-controlled release tasks; this audit does not silently publish legal representations.

### Permissions and entitlements

Safari permissions cover supported search providers, navigation, tabs, local storage and native messaging. These support redirect/setup functionality. No camera, microphone, location, contacts or third-party login flow was found. App Groups share settings/access between the host and its extension. macOS is sandboxed and permits outgoing network requests. Required-reason declarations must cover same-app and same-App-Group UserDefaults and uptime-based local timers; validate the actual Release bundle contents.

### Monetization

Purchases use Apple StoreKit. Restore purchases is visible. Catalog prices use `Product.displayPrice`; unavailable products cannot be purchased. The free trial is explicitly started, lasts 14 days from the original verified transaction, does not renew, and pauses ordinary redirects on expiry. Setup diagnostics remain bounded to a native UUID and fixed query. Refund handling, allowlisted product IDs, and revision guards exist. Verify cross-device restoration with the same sandbox account; App Groups do not sync devices.

Trial and lifetime IAPs remain Ready for Review in the same seven-item draft, **not approved**. The saved simulator trial prompt replaced the old trial review image on Sep 24. A new app version must accompany the first non-consumable submission. Product approval alone will not activate production charging while launchDate is nil.

### Account and authentication

No app account or social login exists. Apple handles purchase authentication. Sign in with Apple and in-app account deletion requirements for developer accounts are not applicable. Test an Apple Account with no payment method; do not promise Apple will never request account verification.

### Content, external links and identity

No app-hosted UGC/messaging service is present. Search results open in Safari. The app identifies itself as independent and disclaims Brave Software affiliation. Support and search-engine links exist; verify them in the shipping builds. This audit cannot guarantee trademark review outcomes.

### Technical stability

The iOS CI StoreKit test repeatedly exceeded its 180-second limit on Xcode 16.4/iOS 18.5 after loading the catalog. Seeding a real test purchase before acquisition checks did not resolve CI; the exact stalled operation was not established by those logs. The same suite passes locally on Xcode 26.6/iOS 18.6, including on a newly created simulator. CI now uses deployment's Xcode 26.3 toolchain and explicitly selects iOS 26.2; final results must still be checked. Signed Mac compilation passes, but a hosted test stalled inside OS sandbox initialization before application code, so this is not Mac Safari verification.

### UX and reviewability

The eligible, expired and unlocked popups have native iOS Safari screenshots. Expired home state is prominent and blocked users see diagnostics under Setup help. A direct privacy link and concise expiry/price disclosure reduce reviewer ambiguity without restoring the previous text-heavy paywall.

## 4. Reviewer experience checklist

- [x] iPhone: owner verified blocked before trial, allowed during trial, blocked after expiry, restored after lifetime purchase.
- [x] Native iOS Safari popup screenshots for eligible, expired and lifetime states (visual fixtures).
- [x] Local iOS StoreKit purchase, restore and refund tests.
- [ ] Final-commit CI green and both TestFlight uploads processed.
- [ ] Mac TestFlight: launch, enable Safari extension, open popup and verify ordinary redirect gating before/after trial/purchase.
- [ ] Purchase on iPhone, restore on Mac using the same sandbox Apple Account; repeat after reinstall without resetting purchase history.
- [ ] No-payment-method Apple Account experience.
- [ ] Genuine production legacy upgrade remains free.
- [ ] Privacy labels/policy agree with current telemetry, including server configuration.
- [ ] Choose production cutoff, approve products, then ship the configured public candidate.

## 5. Suggested reviewer notes (draft)

Braver Search is an independent Safari search-redirect extension for iOS and macOS. No developer account/login is required. Enable it in Safari extension settings and permit access to the supported search provider used by Safari. Search from Safari's address bar to exercise ordinary redirects. Setup help explains these steps and includes a diagnostic check.

New users can explicitly start the free, non-renewing 14-day Trial non-consumable. Redirects pause afterward until a separate lifetime purchase. The six lifetime prices all unlock the same features, with no recurring charges. Restore purchases is available on the purchase screens. Existing production users remain free according to the announced acquisition cutoff [INSERT FINAL UTC CUTOFF].

Apple sandbox acquisitions use a fixed historical date, so sandbox/TestFlight runs intentionally exercise the new-user flow using real sandbox purchases instead of that date for grandfathering. Production uses verified original acquisition evidence. No preview unlock or test-time acceleration ships in Release. Trial expiry remains 14 real days in sandbox; local developer expiry tests use Debug-only controls.

The version submitted for production must include the finalized cutoff and match these notes. Do not submit this placeholder text or claim monetization is active while launchDate is nil.

## 6. Follow-up implementation and release gate

The release preparation added one shared privacy manifest to all four bundles and direct privacy links in both apps. The manifest conservatively marks installation-associated analytics categories as linked, with no advertising tracking. This is separate from the ASC privacy questionnaire and live policy, which still require owner review. Release build and CI verification follow. The owner must complete external privacy declarations, Mac/cross-device purchase checks and release timing before public submission. TestFlight can be used for these checks and does not charge for sandbox transactions.

Sources checked Sep 24: [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) (2.1, 2.3, 3.1.1, 5.1.1), [sandbox testing](https://developer.apple.com/documentation/storekit/testing-in-app-purchases-with-sandbox), [sandbox original acquisition date](https://developer.apple.com/documentation/storekit/apptransaction/originalpurchasedate), [required-reason APIs](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype). Review method: [GitHub Awesome Copilot apple-appstore-reviewer skill](https://github.com/github/awesome-copilot/blob/main/skills/apple-appstore-reviewer/SKILL.md), read from a temporary local copy; no third-party code installed. This is an evidence-based readiness audit, not a guarantee of Apple approval.
