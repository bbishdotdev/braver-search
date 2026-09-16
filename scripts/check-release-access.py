#!/usr/bin/env python3
"""Inspect built Release apps/extensions, never source-only assertions."""
import plistlib
import sys
from pathlib import Path

for argument in sys.argv[1:]:
    app = Path(argument)
    assert app.is_dir(), f"Missing Release app: {app}"
    extensions = list(app.glob('**/*.appex'))
    assert len(extensions) == 1, f"Expected one packaged extension in {app}"
    for bundle in [app, *extensions]:
        mac = (bundle / 'Contents').is_dir()
        root = bundle / 'Contents' if mac else bundle
        info = plistlib.loads((root / 'Info.plist').read_bytes())
        executable = root / 'MacOS' / info['CFBundleExecutable'] if mac else root / info['CFBundleExecutable']
        data = executable.read_bytes()
        for token in [b'access-preview.json', b'monetization-scenario', b'monetization-tier', b'show-lifetime', b'testPersistence', b'SKTestSession', b'access-local-test', b'monetization-test-cohort', b'monetization-test-cutoff', b'monetization-test-elapsed-days']:
            assert token not in data, f"Development-only token in {executable}: {token!r}"
        assert 'PAID_LAUNCH_ISO8601' not in info, 'Obsolete upfront-paid launch setting remains'
        if bundle.suffix == '.appex':
            resource = root / 'Resources' if mac else root
            assert b'getRedirectAccess' in (resource / 'background.js').read_bytes(), 'Native access gate not packaged'
            assert (resource / 'setup-test.js').is_file(), 'Setup recovery script missing'
        print(f"Release audit passed: {bundle.name} ({'macOS' if mac else 'iOS'})")
