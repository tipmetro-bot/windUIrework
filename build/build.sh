#!/usr/bin/env bash
# WindUI Rework build script.
# The upstream project used `darklua` (a Rust binary). This rework bundles
# the sources with a dependency-free Python script, so `npm run build` works
# on any machine with Python 3 (including GitHub Actions).
set -euo pipefail
cd "$(dirname "$0")/.."

MODE=${1:-"build"}

if [ "$MODE" = "check" ]; then
    python3 tools/bundle.py --check
elif [ "$MODE" = "dev" ]; then
    # `dev` used to bundle main.lua. The library entry point is always
    # src/Init.lua; the extra argument is accepted for compatibility.
    echo "[ DEV ] building src/Init.lua (dev argument '${2:-}' ignored)"
    python3 tools/bundle.py
else
    python3 tools/bundle.py
fi

echo "[ ✓ ] WindUI Rework build complete -> dist/main.lua"
