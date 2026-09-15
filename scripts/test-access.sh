#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
access_test_dir=$(mktemp -d)
trap 'rm -rf "$access_test_dir"' EXIT
xcrun swiftc -swift-version 5 'Braver Search/Shared (Access)/AccessPolicy.swift' scripts/AccessPolicyTests.swift -o "$access_test_dir/access-tests"
"$access_test_dir/access-tests"
