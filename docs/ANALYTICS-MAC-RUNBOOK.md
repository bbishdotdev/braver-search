# Braver Search analytics and setup verification

## Handoff

Branch: `codex/reliable-analytics-setup-verification`.

Continue this work on macOS. Read this runbook, inspect `git status`, and preserve existing work. Build and test both platforms, then verify the real Safari flow with the matrix below. Record what actually passed; compilation, simulated transport tests, and a real Safari redirect are different checks. Do not publish to the App Store as part of verification.

The Linux machine can SSH to the Mac mini as `bishop`. The isolated copy used for verification is `/Users/bishop/Work/braver-search-verification-20260912`; it is a source snapshot, not a git checkout. Build logs and DerivedData live there. Use the actual repository/branch for continued edits; do not overwrite an existing Mac checkout.

```bash
git fetch origin
git switch codex/reliable-analytics-setup-verification
git pull --ff-only
```

## What changed

- All four app/extension targets share `Shared (Telemetry)/DurableAnalytics.swift` and `SetupCheck.swift`.
- Events are atomically written to an App Group directory before native messaging reports `durablyQueued: true`. Files contain the original UUID, timestamp and anonymous identity; retries preserve those values for PostHog deduplication. No search terms or visited URLs enter analytics.
- The old anonymous ID migrates into a file protected by a cross-process file lock. The host and extension must resolve the **same App Group**. If the container is unavailable, enqueue fails rather than generating an unrelated identity.
- First-open flags and extension activation flags advance only after durable enqueue. Existing legacy flags stay intact, so upgrades do not become new installs. Missing historical milestones cannot be reconstructed.
- The queue drains on capture, host foreground/polling, and native extension requests, with exponential backoff and numeric Retry-After support. Only HTTP 2xx deletes an event. Both processes may deliver the same event; PostHog's UUID/event/timestamp/distinct-ID deduplication handles that eventually.
- Pending events survive process exit. Timers cannot run while a process is suspended; delivery resumes when the app/extension runs again. 4xx responses are retained with backoff for diagnosis. A 10,000-event cap rejects new enqueues without evicting old events. Uninstalling or clearing the shared container loses pending data.
- `extension_runtime_observed` records runtime presence at most once per UTC day, avoiding dependence on a one-time activation event.
- “Test my setup” opens a harmless Google search with a random test token. The redirect preserves that token; a top-level Brave navigation completion sends proof to the native extension. The native code checks the current token and its ten-minute lifetime, stores local success, and queues the analytics event. The host can recover the success analytics if the extension exits before enqueue.
- At thirty seconds without proof, the UI says “couldn’t verify,” never “disabled.” A valid late proof can still succeed within ten minutes. A new attempt supersedes the old token. This verifies Google → Brave, not every supported engine or every Safari profile.
- Setup searches do not emit `search_redirected` or increment the ordinary redirect count.
- iOS records playback progress at 25/50/75% and completion, once per player instance (automatic loops/restarts do not inflate completion). Guide rows use lazy rendering and record first appearance per guide view. Appearance is an exposure proxy, not proof someone read a step.
- macOS records opening Safari settings and setup help. Its extension identifier is resolved from the embedded extension bundle.
- Debug events carry `environment=development`; Release carries `environment=production`. All new events carry `analytics_version=2`.

## Xcode and simulator prerequisites

The Mac mini initially had macOS 15.5 / Xcode 16.4 and missing CoreSimulator components. The user ran first-launch setup, after which `simctl` worked; an iOS runtime still needed installation.

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
xcodebuild -version
xcodebuild -showsdks
xcrun simctl list runtimes
xcrun simctl list devices available
```

Install a runtime compatible with the selected Xcode from **Xcode → Settings (⌘ ,) → Components**, or use `xcodebuild -downloadPlatform iOS`. Do not start a second download while the UI download is running. `xcodebuild -help` lists supported flags for that Xcode version.

## Automated checks

From the repo root:

```bash
npm ci
npm test -- --runInBand
bash scripts/test-telemetry.sh
xcodebuild build -project 'Braver Search/Braver Search.xcodeproj' \
  -scheme 'Braver Search (macOS)' -destination 'generic/platform=macOS' \
  -derivedDataPath build/mac CODE_SIGNING_ALLOWED=NO
xcodebuild build -project 'Braver Search/Braver Search.xcodeproj' \
  -scheme 'Braver Search (iOS)' -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/ios
```

The standalone native suite uses an isolated directory, isolated UserDefaults suite and intercepted URLSession; it sends no analytics. It covers persistence without credentials, failed enqueue, identity migration, idempotent milestones, process restart, retry payload stability, HTTP failure/acknowledgement, setup tokens, expiry, and offline success.

For hosted Xcode tests, choose an available device ID, then run:

```bash
xcodebuild test -project 'Braver Search/Braver Search.xcodeproj' \
  -scheme 'Braver Search (iOS)' -destination 'id=SIMULATOR_UUID' \
  -derivedDataPath build/ios
xcodebuild test -project 'Braver Search/Braver Search.xcodeproj' \
  -scheme 'Braver Search (macOS)' -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/mac CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO
```

Some pre-existing Xcode tests are scaffolds and some require Safari state. Report individual failures rather than treating them as verification of the new native queue.

## Simulator operation from SSH

```bash
xcrun simctl list devicetypes
# Use a runtime identifier returned by simctl list runtimes.
xcrun simctl create 'Braver verification' 'com.apple.CoreSimulator.SimDeviceType.iPhone-16' 'com.apple.CoreSimulator.SimRuntime.iOS-18-6'
xcrun simctl boot SIMULATOR_UUID
xcrun simctl bootstatus SIMULATOR_UUID -b
open -a Simulator
xcrun simctl install SIMULATOR_UUID 'build/ios/Build/Products/Debug-iphonesimulator/Braver Search.app'
xcrun simctl launch SIMULATOR_UUID xyz.bsquared.Braver-Search
xcrun simctl io SIMULATOR_UUID screenshot /tmp/braver-setup.png
```

Confirm the actual app bundle identifier from the built Info.plist before launching; do not assume it from this example. `simctl openurl` can open known test links, but simctl does not provide arbitrary taps. Use local Simulator UI/XCUITest or explicitly authorized Accessibility automation for enabling Safari extensions and permissions. Screen Sharing clicks can also work. Do not reset TCC, disable SIP, or modify system databases to bypass permission prompts.

For macOS Safari extension testing, a build without signing is sufficient for compilation only. Run a correctly signed development build from Xcode, confirm matching App Group entitlements in host and extension, and enable the extension in Safari. If using an unsigned development extension, Safari's development option to allow unsigned extensions may be required. Avoid replacing an installed production app during verification; prefer a dedicated test user or separately configured development bundle identifiers/App Groups.

## Manual acceptance matrix: run on macOS and iOS

1. **Clean onboarding:** fresh test install, start app, verify one first-open event. Restart the app and confirm no second first-open. Upgrade an existing test install and confirm its anonymous identity is preserved and no new first-open appears.
2. **Disabled extension:** tap Test my setup. A Google page may open; after returning and thirty seconds, show inconclusive with enablement/permission guidance. Never show verified.
3. **Website permission missing:** enable extension but deny Google/Brave website access. Verify inconclusive and useful guidance. Test enabling only one of the two permissions.
4. **Redirect toggle off:** extension enabled, website permissions allowed, redirects off in popup. Verify no successful test or ordinary redirect; enable and retry.
5. **Working setup:** test with extension enabled, both website permissions allowed, redirects on. Confirm the actual tab reaches `search.brave.com`, return to the host, and see Setup verified. Confirm same test ID on started/proof/result events and same anonymous ID across host/extension. Confirm no ordinary `search_redirected` for this test.
6. **Normal searches:** search from Safari's address bar using supported engines. Verify redirection and ordinary search events; ensure authentication links and Brave bang searches still behave as before. Check each supported engine/profile whose permissions matter.
7. **Wrong/default browser:** on iOS, if the test opens the user's non-Safari default browser, it must remain inconclusive. Open the result row, then use Share test link to open the same link in Safari. Do not claim the app can force Safari through the public HTTPS open API.
8. **Retries and late results:** start twice; the old token cannot verify the new attempt. No unrelated page/subframe can verify it. A result after thirty seconds but before ten minutes can change inconclusive to success; an expired token cannot.
9. **Offline analytics:** with a working Safari test but analytics endpoint unavailable, local success still appears. Kill/relaunch the host/extension and restore the analytics endpoint. Pending events drain, retaining original UUID/timestamp/identity. Verify retries do not create permanent duplicates in PostHog. Use a local/staging collector or a network tool, not global firewall changes on the user's Mac.
10. **Video/guide:** play, pause, restart, loop, leave and return. Verify milestones and one completion per view instance. Confirm every guide screenshot renders and steps are exposed as scrolled. Check small iPhone, large text and macOS window sizes.

## PostHog rollout and measurement

Use Braver Search project **193615**. Production credentials remain in the existing ignored `AnalyticsSecrets.xcconfig` / CI secret mechanism. Prefer a staging project for debug validation. Never paste API keys into this runbook or logs.

The live baseline dashboards were reorganized on 2026-09-12: [Product health](https://us.posthog.com/project/193615/dashboard/463016) and [Setup and friction](https://us.posthog.com/project/193615/dashboard/2090082). All 14 saved queries were executed successfully. See [POSTHOG-GUIDE.md](POSTHOG-GUIDE.md) for interpretation, mature-cohort filters, saved definitions, and the release follow-up.

Do not replace the old live funnel with new event names before this build emits them. The exact new query definitions are in `docs/posthog-analytics-v2.json`. After validation and release:

1. Verify event/property names and values exist with the PostHog schema tool.
2. Create a separate **Setup and search — analytics v2** dashboard using the definitions. Exclude `environment=development`; filter `analytics_version=2`.
3. Keep setup verification, runtime diagnostics, and ordinary search funnels separate. Do not require a separately captured runtime event between first open and proof; proof already establishes that the extension ran. Use first-touch platform attribution, a seven-day conversion window and a thirty-day observation period. Video is diagnostic, never a required conversion step.
4. For a fully observed cohort, select entrants whose first open occurred at least seven days before the data cutoff, while retaining subsequent events through the cutoff. Merely moving the whole query's end date seven days back still truncates their outcomes. Use cohort/step timestamp filtering or the supplied SQL template after schema verification.
5. Report both iOS/macOS and release version. Compare the same cohort and eligibility; never divide all search users by new app opens and call it conversion.
6. Count weekly **ordinary search** users and redirects per user. Existing users may never open the host app again.
7. Document the release date/build and allow seven full days for the first cohort to mature. Historical missing events remain unknown. A Google-only test does not certify access to all sites, profiles or private browsing.

PostHog deduplication reference: https://posthog.com/docs/data/events
Funnel reference: https://posthog.com/docs/product-analytics/funnels
Apple simulator component reference: https://developer.apple.com/documentation/xcode/downloading-and-installing-additional-xcode-components

## Verification record

Fill this with exact commit, Xcode/OS, device/runtime, test counts, screenshots, and PostHog evidence. Explicitly mark pending signing, permission, simulator or real-device checks. A simulator pass does not replace physical iPhone/iPad verification before release.

### Results obtained from the Linux PC via SSH (2026-09-12)

- Xcode 16.4 / macOS 15.5; iOS 18.6 runtime installed by the user.
- Both macOS architectures (arm64/x86_64) build, including the extension.
- iOS Simulator app and extension build; installed in dedicated iPhone 16 simulator `C6DFC7F9-981D-4450-AAF0-58A675549C8A`.
- JavaScript: 45 tests passed.
- Standalone native telemetry suite passed.
- macOS Xcode test action passed.
- iOS Xcode test action: 4 tests passed, zero failures/skips.
- No Apple development signing identities were available on this Mac. Physical-device and signed macOS Safari verification remain required before release.
- Analytics-v2 PostHog queries are prepared but await release and live schema verification. The separate baseline reporting refresh uses existing events and is live; see `POSTHOG-GUIDE.md`.
- The final iOS design uses a compact warm-accent action above the walkthrough, with inline results only after testing. macOS integrates the same action inside the existing status card.
- Additional native tests cover competing writers and recovery when a process exits between event persistence and milestone persistence.
- Simulator UI launch was verified visually; the walkthrough video renders. Real Safari success/permissions and physical-device behavior are still checklist items, not inferred from the unit tests.

- Host-recovered setup proofs preserve the extension’s original completion timestamp, so delayed delivery does not move conversions into a later cohort/window.

### Setup-result feedback fix (2026-09-12)

Branch: `codex/fix-setup-test-feedback`, based on merged PR #11.

- Reproduced the reported failure in the dedicated iOS simulator: the original app stayed on “Waiting for the test in Safari” after a successful result was written while Safari was foregrounded and the same app process was brought back.
- The SwiftUI view is hosted by UIKit's `SceneDelegate`. Its result refresh depended on SwiftUI `scenePhase`, which did not update in this setup. Refresh now observes `UIApplication.didBecomeActiveNotification`, refreshes on appearance, and polls while UIKit reports that the app is active. No manual refresh is needed.
- Added durable, token-validated `setup_test_progress` stages: `extension_seen` (with `enabled`), `redirect_requested`, and `redirect_failed`. These distinguish a disabled redirect toggle, a rejected redirect, and missing Brave page confirmation. Progress never substitutes for successful destination completion. Result events include a `reason`.
- iOS and macOS show the observed state with next steps. Storage-read problems are visible instead of silently resetting to idle. A later valid success replaces earlier inconclusive feedback.
- iOS keeps the result inside the existing warm-accent action: **Checking Safari…** with a spinner while pending and **Setup verified** after completion. While waiting, it becomes a readable, noninteractive status to prevent overlapping tests. Inconclusive results offer **Test again**, with one compact result row that opens the explanation, setup guide, and browser-sharing fallback. The home screen has no timing paragraph or separate refresh/help links. The success action can start another test.
- 48 JavaScript tests passed. The standalone native suite passed, including stage persistence across readers, timeout explanations, stale/expired tokens, disabled redirects, failed redirects, and success preservation.
- iOS Simulator and macOS app/extension builds passed on the Mac mini (Xcode 16.4).
- Visual simulator regression passed with the same running app process: a saved success appears after returning from Safari, and an unanswered test transitions automatically from waiting to actionable feedback after 30 seconds. These used synthetic state only in the dedicated simulator to isolate lifecycle behavior; they do not establish real Safari permission/navigation success.
- The polished iOS Simulator and macOS app/extension builds passed; 48 JavaScript tests and the standalone native suite passed again. Waiting, verified, and inconclusive simulator layouts were inspected, including the largest accessibility text size. Screenshots on the Mac are `/tmp/braver-polish-*.png`.
- The paired iPhone is reachable and has Developer Mode enabled. An Apple Development identity and provisioning profile are available, but remote device signing still fails with `errSecInternalComponent` after the user unlocked the login keychain. The user was asked to run the failing `codesign` command locally and allow that tool to use the private key. Installation and launch of this revision remain pending; do not count simulator state injection as physical-device verification.

For a real-device acceptance check, tap **Test my setup**, allow Safari to open the search, and return without force-quitting Braver Search. Expect **Setup verified** when Brave completion is received, without tapping anything to refresh. Otherwise, open the result row: its details should distinguish no extension response, redirects off, redirect failure, or an accepted redirect awaiting Brave confirmation. Verify navigation to the setup guide and back, and the Share test link fallback. Repeat once with redirects switched off, then restore the setting and verify a fresh test succeeds. Check the waiting, verified, and inconclusive layouts at large Dynamic Type sizes.

UIKit lifecycle reference: https://developer.apple.com/documentation/uikit/uiapplication/didbecomeactivenotification

### First-attempt navigation recovery (2026-09-12)

Branch: `codex/fix-first-setup-navigation`, based on merged PR #12.

- Report: an already configured setup sometimes opens Google on the first test, reports no response, and succeeds on the next attempt. The exact device build and cold-versus-warm Safari trigger still need confirmation.
- The early navigation handler awaited native diagnostic persistence before redirecting. A regression test demonstrates that an unanswered diagnostic message prevented the redirect. It now sends that diagnostic without holding up navigation.
- Added a narrowly scoped content script on the tagged Google and Brave setup pages. A Google page message wakes the background and recovers the existing attempt if the early navigation event was missed. It requires the native app to accept the current, unexpired test token, respects the redirect toggle, and rechecks the tab before redirecting. Duplicate early/page events produce one redirect; ordinary searches do not send page messages.
- A Brave page message reports success only after document completion. The existing navigation-completion path remains active, and native proof persistence is idempotent. Neither a Google page load nor an accepted redirect is success.
- The new script uses existing website permissions. Both Xcode target memberships were updated, and built iOS/macOS extension bundles were checked for the correct script, manifest, and background code.
- 69 JavaScript tests passed. They model a missed early navigation event, slow enabled-state loading, a stalled or throwing diagnostic bridge, duplicate events, expired/superseded tests, disabled redirects, navigation away, Google-added URL parameters, subframes, and completion timing. These demonstrate the recovery behavior, not the exact cause of the reported Safari event loss on the physical phone.

Remote source/build directory: `/Users/bishop/Work/braver-search-first-navigation-20260912`.

Physical Safari acceptance remains required: with Google/Brave website access allowed and redirects on, test once after Safari has been unused or terminated, then repeat several tests back-to-back using the redo action. Each attempt should reach Brave without starting a second test, and returning to the app should show verified for that attempt. Repeat with redirects off and with website permission denied; neither may verify. Record the TestFlight version/build, iOS/Safari version, and whether the failure occurred after a cold or warm start. Keep development signing access separate from these behavioral results.

Apple background-lifecycle reference: https://developer.apple.com/videos/play/wwdc2021/10027/
