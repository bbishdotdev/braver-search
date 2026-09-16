# Local purchase testing: steps for Brenden

Production remains free. Yesterday's cutoff is used only in Debug local-test mode.
The code, CI, simulator checks and remote builds can be handled remotely. Apple
password/keychain prompts, sandbox sign-in and Safari permission choices need local interaction.

## 1. Unblock signing on the Mac

In Mac Terminal:

```bash
security unlock-keychain "$HOME/Library/Keychains/login.keychain-db"
/usr/bin/codesign --force \
  --sign 'Apple Development: Brenden Bishop (4DNC4UZ685)' \
  --timestamp=none \
  '/Users/bishop/Work/braver-search-monetization-20260915/build/mac-signed/Build/Products/Debug/Braver Search Extension.appex/Contents/MacOS/Braver Search Extension.debug.dylib'
```

Enter passwords locally only. Approve access for codesign if macOS asks. Report the
result; do not send a password. The certificate exists, but the latest remote signed
build failed with `errSecInternalComponent`.

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

The remote checkout is:

`/Users/bishop/Work/braver-search-monetization-20260915/Braver Search/Braver Search.xcodeproj`

Codex can build/install/launch on the paired iPhone after signing is unblocked. Keep it
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
not real purchase tests. The local-testing header must be visible. The cutoff defaults
to 24 hours ago. Verified sandbox acquisition is remapped to the test cohort only;
purchase transactions and their original dates remain genuine.

## 4. Check the actual flows

1. Confirm the free trial plus all five localized paid prices load.
2. Start the free trial. Confirm the Apple sheet is a sandbox transaction. Report any
   unavailable-product, sign-in or verification error without entering real payment details.
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
