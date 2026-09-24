#!/usr/bin/env python3
"""Run a command once in the current user's existing macOS desktop session.

Invoke on the Mac (including over SSH). Requires an already logged-in desktop
session. Does not unlock keychains, change permissions, or install a login item.
"""

import argparse
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import tempfile
import time
import uuid


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--timeout", type=int, default=1800)
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command
    if command[:1] == ["--"]:
        command = command[1:]
    if sys.platform != "darwin" or not command or args.timeout <= 0:
        parser.error("Run on macOS with a positive timeout and -- COMMAND [ARGS...]")
    executable = shutil.which(command[0])
    if not executable:
        parser.error("Command not found: " + command[0])
    command[0] = executable
    domain = "gui/" + str(os.getuid())
    subprocess.run(["/bin/launchctl", "print", domain], check=True,
                   stdout=subprocess.DEVNULL)

    root = Path(tempfile.mkdtemp(prefix="braver-desktop-job-"))
    label = "xyz.bsquared.braver-desktop-job-" + uuid.uuid4().hex
    log = root / "output.log"
    status = root / "exit-status"
    runner = root / "run.py"
    runner.write_text(
        "import pathlib, subprocess, sys\n"
        "result = subprocess.run(sys.argv[2:]).returncode\n"
        "pathlib.Path(sys.argv[1]).write_text(str(result))\n"
        "sys.exit(result)\n"
    )
    plist = root / "job.plist"
    plist.write_bytes(plistlib.dumps({
        "Label": label,
        "ProgramArguments": [sys.executable, str(runner), str(status), *command],
        "WorkingDirectory": os.getcwd(),
        "RunAtLoad": True,
        "StandardOutPath": str(log),
        "StandardErrorPath": str(log),
    }))
    print("Desktop job logs: " + str(root), flush=True)
    subprocess.run(["/bin/launchctl", "bootstrap", domain, str(plist)], check=True)
    deadline = time.monotonic() + args.timeout
    offset = 0

    def output():
        nonlocal offset
        if log.exists():
            with log.open("rb") as stream:
                stream.seek(offset)
                data = stream.read()
                offset = stream.tell()
            sys.stdout.buffer.write(data)
            sys.stdout.buffer.flush()

    try:
        while not status.exists():
            output()
            if time.monotonic() >= deadline:
                print("Desktop job timed out", file=sys.stderr)
                return 124
            time.sleep(0.5)
        # The child closes the status file before it exits; tolerate the tiny
        # interval between creating the file and writing its integer value.
        result = status.read_text().strip()
        while not result and time.monotonic() < deadline:
            time.sleep(0.05)
            result = status.read_text().strip()
        output()
        return int(result) if result else 124
    finally:
        subprocess.run(["/bin/launchctl", "bootout", domain + "/" + label],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


if __name__ == "__main__":
    sys.exit(main())
