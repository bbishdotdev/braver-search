## TestFlight builds (September 24 update)

### Mac verification recovery

Build 2.0.10 (46) can show the free/donation UI if Apple's `AppTransaction.shared`
throws or returns an unverified result: that build discarded the error. The symptom
was reported on macOS 26.6.2 with no `appTransactionEnvironment` saved in the access
record. This does not establish Apple's underlying error or mean the Mac UI is missing.

Builds 2.0.11–2.0.12 showed a **Check your App Store access** warning for every
acquisition failure, even when existing access remained valid. The follow-up fix
limits that notice to users whose redirects are blocked. Free, grandfathered,
active-trial and lifetime users retain their normal home screen; free and
grandfathered users retain donations. An explicit Restore still reports a failed
Apple check, and technical failures remain logged.

The notice includes a technical error code and a **Retry verification** button on
Mac and iOS. The button explicitly
calls `AppTransaction.refresh()` and may ask for App Store authentication. Background
refresh never forces authentication. No receipt or account information is included
in the displayed code or log. A failed check preserves cached access and trial dates;
it cannot start a trial, extend expiry, or invent a lifetime purchase.

### Existing-user release gate

The same access-store regression runs on iOS and Mac. It injects an Apple
verification failure and checks donation-era first-use migration without an access
record, cached production grandfathering, cached lifetime ownership, expired trials,
and an unresolved download. Unresolved acquisition after rollout remains **unknown**,
not **eligible**; no failure may be treated as evidence that someone must pay.

These are deterministic failure tests, not proof of a live App Store upgrade. Before
activating the production cutoff, test an upgrade from the public donation build on
both platforms with a normal App Store account, including an offline launch. A
TestFlight new-user screen does not validate production grandfathering: the sandbox
policy deliberately exercises the new-user flow. Keep the cutoff disabled until that
upgrade validation is complete.

After retry succeeds with a verified Sandbox acquisition, the existing sandbox policy
shows the trial/purchase flow. If retry still fails, record the on-screen error code.
The recovery is not proof that Apple's failure is fixed on the affected Mac; that
requires retesting the TestFlight build there. Keep the production cutoff disabled.

### Expected sandbox behavior

Release builds now recognize Apple's **verified Sandbox app transaction** and show the new-user flow automatically, despite Apple's fixed 2013 original acquisition date. No Xcode launch arguments are needed. Existing sandbox purchases are restored, so use a fresh sandbox tester or clear its purchase history and sign out/in if you need to start over.

Both platforms use the same policy. Trial and lifetime access still require genuine verified Apple sandbox transactions; expiry remains **14 real days**. TestFlight has no time-shift or free-unlock controls. The Debug instructions below remain useful for accelerated expiry and legacy scenarios. Production stays free while `launchDate` is nil; sandbox testing does not set the public cutoff.

On Mac, install the new build from TestFlight, enable Braver Search in Safari Settings → Extensions, allow the supported search provider, and open the app once so it reads its receipt. Check blocked-before-trial, active trial, lifetime purchase and Restore purchases. To verify cross-device ownership, use the same sandbox purchasing account on iPhone and Mac, purchase once and restore on the other device. Do not clear purchase history between the purchase and restore.

Apple uses sandbox transactions for TestFlight, with no real charge. For a specifically configured sandbox tester, follow [Apple's current sandbox sign-in instructions](https://developer.apple.com/documentation/storekit/testing-in-app-purchases-with-sandbox); do not assume TestFlight automatically uses the tester selected for an Xcode-installed build. Confirm the account/environment shown in Apple's purchase sheet.

# Local purchase testing: steps for Brenden

Production remains free. Yesterday's cutoff is used only in Debug local-test mode.
The code, CI, simulator checks and remote builds can be handled remotely. Apple
password/keychain prompts, sandbox sign-in and Safari permission choices need local interaction.

## 1. Signing is working; keep the bishop desktop session logged in

Confirmed September 23: the developer-signed Mac build succeeds, and both the app
and Safari extension pass strict signature verification with team A947N6H5GS.
No further keychain changes are needed for the current session.

The earlier failure was specific to the SSH security session. A command launched
in bishop's existing desktop session can access the keychain and sign successfully;
the same identity fails with `errSecInternalComponent` in the separate SSH session.
Another user's active desktop does not establish which account ran your Terminal
command. Local codesign printing only "replacing existing signature" and exiting
successfully is normal; an approval dialog is not required.

Remote builds now use `scripts/run-in-macos-session.py` to run once in bishop's
existing desktop session. It does not store passwords, change keychain permissions,
or install a login item. Keep that session logged in. After a restart or logout,
log into bishop again and unlock the login keychain locally if needed.

The [remote build instructions](MONETIZATION-RUNBOOK.md#remote-mac-signing-from-ssh)
include the verified command. Safari behavior and actual sandbox purchases remain
separate validation steps; a signed build alone does not prove those flows.

## 2. Prepare a Sandbox Apple Account

App Store Connect → Users and Access → Sandbox → create a dedicated tester.
Keep its credentials private. Use the same sandbox tester for iPhone and Mac restoration.
Sandbox purchases do not incur charges. A sandbox tester is distinct from the ordinary
Apple Account with no payment method that will be needed for the final real-account check.

Follow Apple's [sandbox testing instructions](https://developer.apple.com/documentation/storekit/testing-in-app-purchases-with-sandbox)
for sign-in on each device. Do not sign out of iCloud or change the device clock.
If using TestFlight sandbox controls, Apple's instructions may require signing out of
Media & Purchases; that affects access to existing purchased media, so prefer a test device.
The current local controls described below require a development build, not TestFlight.

## 3. Run the development build

The active Xcode checkout on the Mac is:

`/Users/bishop/Developer/braver-search/Braver Search/Braver Search.xcodeproj`

The older `/Users/bishop/Work/braver-search-monetization-20260915` directory is a
separate build snapshot. Use the active checkout above for the current UI.

Codex can attempt device builds/install/launch on the paired iPhone. Keep it
unlocked and connected. If running directly in Xcode, select **Braver Search (iOS)** and
**Brenden's iPhone**. For Mac choose **Braver Search (macOS)** / **My Mac**.

Product → Scheme → Edit Scheme → Run:

- Build Configuration: Debug.
- Options → StoreKit Configuration: **None** for actual App Store Connect sandbox products.
- Arguments Passed On Launch, one token per row:

```
-monetization-test-cohort
new
-show-lifetime
```

Remove any `-monetization-scenario` screenshot arguments. Those are visual previews,
not real purchase tests. The `Sandbox · new user` footer must be visible. It is
DEBUG-only and never appears in the shipped app. The cutoff defaults
to 24 hours ago. Verified sandbox acquisition is remapped to the test cohort only;
purchase transactions and their original dates remain genuine.

## 4. Check the actual flows

1. An eligible user sees **Try it in Safari**, with **Start free trial** and no
   price slider. **See lifetime prices** opens a separate page with the lion,
   slider, and **Unlock forever** button. **Back** returns to the trial offer.
   Confirm all six localized prices load and the card stays still while dragging.
2. Start the free trial. Confirm the Apple sheet is a sandbox transaction. Report any
   unavailable-product, sign-in or verification error without entering real payment details.
   Successful activation closes the offer and returns to the app. Cancellation or
   pending approval must not grant access or dismiss the offer as a success.
   Existing trial users and expired users open lifetime pricing directly.
3. Enable the development extension in Safari and allow its required search sites.
   Search normally and run Test my setup. Both should work during the trial.
4. Add `-monetization-test-elapsed-days` and `15` to launch arguments, then relaunch.
   Ordinary searches should remain on the default engine. Setup help and the bounded
   Test my setup diagnostic must still work.
5. Buy a lifetime tier. Ordinary redirects should resume even with +15 days selected.
6. On the other platform, use the same sandbox account and the `new` local test mode,
   then Restore Purchases. Lifetime access should appear there too.
7. Change the cohort argument from `new` to `legacy`. Access should remain free, and
   optional donations should remain available. This simulates legacy policy; it does
   not replace a genuine App Store upgrade/acquisition-date validation.
8. Launch without local-test arguments to leave test mode. Normal access storage is
   unchanged. To repeat purchases, clear only the dedicated sandbox tester's purchase
   history and refresh/restore so the local test record reconciles with Apple.

Codex can switch launch arguments and collect logs between these steps. Report the
step, platform, and visible message; no password or payment information is needed.

## Still separate before public release

- TestFlight/review-safe new-customer handling (DEBUG controls intentionally do not ship).
- A genuine legacy-user upgrade, not just a fixture.
- A normal Apple Account with no payment method: sandbox proves no charge handling,
  but does not prove which verification prompts Apple will show in production.
- Announced grandfathering cutoff, manual release timing, matching review screenshots,
  and app-plus-products approval.
