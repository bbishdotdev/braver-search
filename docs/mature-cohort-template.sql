-- Run only after verifying events columns and analytics_version/environment/platform properties.
-- Example fixed cutoff. Replace all three boundaries together for the reporting period.
-- Entrants: August 13 through September 5, with outcomes observed through September 12.
-- Timestamp filters are required on every events scan. No raw events join is needed.
SELECT
    platform,
    count() AS first_openers,
    countIf(arrayExists(t -> t >= first_open AND t <= first_open + INTERVAL 7 DAY, proofs)) AS verified_setup,
    countIf(arrayExists(t -> t >= first_open AND t <= first_open + INTERVAL 7 DAY, searches)) AS ordinary_search_users
FROM (
    SELECT
        person_id,
        argMinIf(properties.platform, timestamp, event = 'first_app_open') AS platform,
        minIf(timestamp, event = 'first_app_open') AS first_open,
        countIf(event = 'first_app_open') AS opens,
        groupArrayIf(timestamp, event = 'setup_test_redirect_observed') AS proofs,
        groupArrayIf(timestamp, event = 'search_redirected') AS searches
    FROM events
    WHERE timestamp >= '2026-08-13 00:00:00'
      AND timestamp < '2026-09-12 00:00:00'
      AND event IN ('first_app_open', 'setup_test_redirect_observed', 'search_redirected')
      AND properties.analytics_version = 2
      AND properties.environment = 'production'
    GROUP BY person_id
)
WHERE opens > 0
  AND first_open < '2026-09-05 00:00:00'
GROUP BY platform
