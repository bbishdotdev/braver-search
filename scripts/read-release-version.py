#!/usr/bin/env python3
"""Read the app's resolved release version; reject extension/version mismatches."""
import json
from pathlib import Path
import re
import sys

settings = json.loads(Path(sys.argv[1]).read_text())
platforms = [sys.argv[3]] if len(sys.argv) > 3 else ["iOS", "macOS"]
targets = {f"{name} ({platform})" for platform in platforms
           for name in ["Braver Search", "Braver Search Extension"]}
versions = {
    item["target"]: item["buildSettings"].get("MARKETING_VERSION", "")
    for item in settings if item["target"] in targets
}
if set(versions) != targets or len(set(versions.values())) != 1:
    sys.exit(f"App and extension must resolve to the same release version: {versions}")
version = next(iter(versions.values()))
if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", version):
    sys.exit(f"Expected a three-component release version, received {version!r}")
manifest = json.loads(Path(sys.argv[2]).read_text())
if manifest.get("version") != version:
    sys.exit(f"Safari manifest version must match the app's {version}")
print(f"marketing_version={version}")
