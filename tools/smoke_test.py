#!/usr/bin/env python3
"""
WindUI Rework / bundle smoke test runner
=======================================

Luau's CLI `require()` gives every module a *fresh* global environment, so a
Roblox mock defined in the test script would not be visible to the bundled
modules. Instead this script inlines `dist/main.lua` into the mock harness
(`tests/bundle_smoke.luau`) and runs the combined chunk with the Luau CLI.

    LUAU_BIN=/path/to/luau python3 tools/smoke_test.py
    python3 tools/smoke_test.py            # auto-detects `luau` in PATH

If the Luau CLI is not installed the test is skipped (CI still validates the
bundle with tools/check_syntax.mjs and tools/bundle.py --check).
"""
from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TEMPLATE = ROOT / "tests" / "bundle_smoke.luau"
BUNDLE = ROOT / "dist" / "main.lua"
MATH_TEST = ROOT / "tests" / "slider_math_test.luau"
MARKER = "-- __WINDUI_BUNDLE__"


def find_luau() -> str | None:
    return os.environ.get("LUAU_BIN") or shutil.which("luau")


def run(argv: list[str], label: str, expected: str) -> bool:
    try:
        result = subprocess.run(argv, capture_output=True, text=True, timeout=120)
    except (OSError, subprocess.TimeoutExpired) as exc:
        print(f"[smoke] {label}: could not run ({exc})")
        return False
    output = (result.stdout or "") + (result.stderr or "")
    if result.returncode != 0 or expected not in output:
        print(f"[smoke] {label}: FAILED (exit {result.returncode})")
        print(output[:2000])
        return False
    print(f"[smoke] {label}: OK")
    return True


def main() -> int:
    luau = find_luau()
    if not luau:
        print("[smoke] SKIPPED: Luau CLI not found (set LUAU_BIN or install luau).")
        print("[smoke] CI still runs `npm run check` (parser + bundle freshness).")
        return 0

    template = TEMPLATE.read_text(encoding="utf-8")
    bundle = BUNDLE.read_text(encoding="utf-8")
    if MARKER not in template:
        print(f"[smoke] marker {MARKER!r} missing in {TEMPLATE}", file=sys.stderr)
        return 1
    combined = template.replace(MARKER, bundle.rstrip())

    with tempfile.TemporaryDirectory(prefix="windui-smoke-") as tmp:
        generated = Path(tmp) / "bundle_smoke_generated.luau"
        generated.write_text(combined, encoding="utf-8")
        ok = run([luau, str(generated)], "bundle loads with Roblox mocks", "bundle_smoke: OK")
        ok = run([luau, str(MATH_TEST)], "zero-safe slider math", "ALL OK") and ok

    if not ok:
        print("[smoke] FAILED", file=sys.stderr)
        return 1
    print("[smoke] ALL OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
