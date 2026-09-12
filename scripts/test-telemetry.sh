#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
telemetry_test_dir=$(mktemp -d)
trap 'rm -rf "$telemetry_test_dir"' EXIT
xcrun swiftc -swift-version 5 'Braver Search/Shared (Telemetry)/DurableAnalytics.swift' 'Braver Search/Shared (Telemetry)/SetupCheck.swift' scripts/TelemetryTests.swift -o "$telemetry_test_dir/telemetry-tests"
"$telemetry_test_dir/telemetry-tests"
