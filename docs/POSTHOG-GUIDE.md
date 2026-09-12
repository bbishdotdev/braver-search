# Braver Search reporting

Configured in PostHog project **193615** on 2026-09-12. Both dashboards are pinned. All 14 saved insights were executed successfully after saving. This is reporting configuration; it does not deploy the new app build.

## Start here

- [Product health](https://us.posthog.com/project/193615/dashboard/463016): actual search usage, frequency, repeat usage, and release mix.
- [Setup and friction](https://us.posthog.com/project/193615/dashboard/2090082): setup activity, observed searches, help engagement, and redirect-toggle changes.

The original dashboard became Product health. Existing insight links were preserved, including the old redirect funnel, which now lives on Setup and friction. No event data was deleted. Eight event descriptions now explain what their events actually mean.

## A weekly review

1. Open Product health. Check weekly active searchers and searches per active searcher. Compare **complete weeks**, separately for iOS and macOS where available. The headline redirect count excludes today and compares the last 30 complete UTC days with the previous period.
2. Read weekly search retention. Each cohort contains installations that searched in that week; later columns show whether they searched again. Compare completed cells at the same age. This is repeat search usage, not new-install onboarding retention.
3. If usage changes, inspect daily searchers, redirect volume, and app-version mix. A version's audience can differ from another version's audience; that comparison alone does not establish a regression.
4. Open Setup and friction. Compare the two mature-cohort funnels using their defaults. Check platform differences, then time to search, first tracked opens, help interactions and toggle changes for supporting evidence.
5. Choose a concrete hypothesis and verify it in Safari on the affected platform. After releasing a change, allow the full conversion window before comparing cohorts with equal follow-up.

Do not add daily or weekly unique-user counts to calculate monthly users. An installation active on multiple days/weeks appears in multiple buckets. The version chart can also count an installation under both versions during an upgrade week.

## What the charts mean

| Product health chart | Question answered |
| --- | --- |
| Search redirects, last 30 complete days | Is recorded search volume changing? |
| Weekly active searchers, by platform | How many installations actually search each week? |
| Searches per active searcher, weekly | Is search frequency changing among active installations? |
| Weekly search retention | Do existing searchers search again in later weeks? |
| Daily active searchers, by platform | Is a change concentrated on particular days or platforms? |
| Daily search redirects, by platform | Does volume move with audience size or frequency? |
| Search habit, active days | How many days did each active installation search in the last 30 complete days? |
| Active searchers by app version | Which releases are represented in search activity? |

| Setup and friction chart | Question answered |
| --- | --- |
| First app open → observed search | Was a redirect recorded within seven days of a mature entrant's first tracked open? |
| First app open → any extension activity | Was activation, a popup open, or a redirect recorded within that same window? |
| First tracked app opens, by platform | Is the volume or platform mix entering setup changing? |
| Time to first observed search | Among observed converters, how long did conversion take? |
| Setup help engagement | How many installations encountered video playback, used its controls, or opened the guide? |
| Redirect setting changes, off/on | Are changes to the extension's redirect toggle increasing? |

### Mature setup cohorts

The default query covers the last 30 days through today. **Only the first funnel step** has this SQL expression filter:

```sql
timestamp < now() - INTERVAL 7 DAY
```

That selects first opens approximately 30–7 days ago while retaining their next seven days of outcomes. The funnel conversion window is seven days, ordered, with first-touch platform attribution. The same cohort definition is used for both setup funnels and the time-to-convert distribution.

Keep the default rolling dates for these three insights. Changing the whole dashboard to a historical end date does not automatically move the expression's `now()` cutoff. For a historical cutoff T, replace it with `timestamp < T - INTERVAL 7 DAY` while retaining outcomes through T. Setting the entire query end date seven days earlier alone truncates outcomes too.

The two-step funnels deliberately allow users to skip the optional video, guide, popup, and setup test. Requiring those optional events would exclude valid paths.

### Interpret signals carefully

- IDs represent anonymous installations, not identified people across devices.
- `search_redirected` means Safari accepted the extension's redirect update. It is the ordinary search signal, not proof the destination page finished loading.
- `first_app_open` is a first tracked launch milestone, not an App Store download. Legacy delivery could lose that event.
- `extension_activated` is a one-time runtime observation, not a permissions audit. Historical missing milestones cannot be recovered.
- Video autoplay is exposure, not watched content. Help use can be normal learning; it is not automatically frustration.
- `redirect_setting_changed` counts toggle changes, not the number currently disabled. It does not report Safari's extension or website permissions.
- The active-days distribution includes new and existing searchers. A recent entrant has fewer possible active days.
- Current views use the existing event stream across versions. Development/production separation is part of the upcoming analytics-v2 release; these baseline views do not yet enforce a production-only filter.

PostHog's standard Lifecycle insight excludes anonymous events. It returned zeros for this project's search events and was replaced with the validated active-days chart. See [Lifecycle definitions](https://posthog.com/docs/product-analytics/lifecycle). The existing anonymous capture model remains unchanged.

## After the analytics-v2 app release

The new setup-test, video-completion, and guide-step events were **not present in the live schema** during configuration. Empty charts for those events would be misleading, so those views are pending release.

Use [ANALYTICS-MAC-RUNBOOK.md](ANALYTICS-MAC-RUNBOOK.md) for build and real Safari verification. Then:

1. Record the actual release date/version and verify new event/property names and values in PostHog. Use a staging project for debug validation when available.
2. Create the separate production analytics-v2 views from [posthog-analytics-v2.json](posthog-analytics-v2.json). Verify `analytics_version=2` and `environment=production` exist on every relevant event before applying those filters. Test each query and execute the saved insight afterward.
3. Apply the mature first-step cohort filter above to first-open funnels before treating them as fully observed conversion metrics. The supplied v2 queries are initially rolling diagnostics.
4. Add a daily setup-result view for `setup_test_result_shown`, broken down by `result`, and an open-failure trend for `setup_test_open_failed`. **Inconclusive is not disabled**: it can mean missing permissions, a different browser, a timeout, or an unobserved result.
5. For attempt success, correlate `setup_test_started` with `setup_test_redirect_observed` using the same anonymous identity and `test_id`, and respect the token's ten-minute lifetime. A person-level funnel does not match attempts. A thirty-second inconclusive result can later be followed by valid proof, so results are not necessarily mutually exclusive terminal outcomes.
6. Add iOS video progress/completion and guide-step exposure views using the actual live property schema. Step appearance is exposure, not proof it was read. Compare these signals with setup outcomes without making them required setup steps.
7. Check new-release adoption, production event delivery, and matching host/extension identity before interpreting a change as a UX effect. Compare cohorts with equal observation windows and platform eligibility. Seven full days are needed for the first new-install cohort; existing upgraders do not emit another first-open event.

Keep the baseline dashboards available for historical context. Missing legacy data cannot be backfilled, and all-version trends may change when telemetry becomes more reliable.

## Maintenance and recovery

- [posthog-dashboards.json](posthog-dashboards.json) records the live dashboard IDs, insight IDs, queries, descriptions, layout order, and event descriptions.
- [posthog-dashboard-backup-2026-09-12.json](posthog-dashboard-backup-2026-09-12.json) preserves the seven original insight definitions and dashboard metadata. Restore by original insight ID if needed; no data deletion is necessary.
- No replay capture, search terms, visited URLs, outbound subscriptions, alerts, or project-wide ingestion/identity changes were enabled as part of this reporting work.
- Useful references: [Funnels](https://posthog.com/docs/product-analytics/funnels), [Retention](https://posthog.com/docs/product-analytics/retention), [Stickiness](https://posthog.com/docs/product-analytics/stickiness), [time filters](https://posthog.com/tutorials/hogql-date-time-filters).
