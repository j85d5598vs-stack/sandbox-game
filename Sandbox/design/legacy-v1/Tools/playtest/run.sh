#!/bin/zsh
# Builds and runs the Sandbox playtest bot against the real game rules.
# Usage: Sandbox/Tools/playtest/run.sh [saves per style, default 300]
set -e
HERE="${0:A:h}"
GAME="$HERE/../../Sandbox"
OUT="${TMPDIR:-/tmp}/sandbox-playtest"
xcrun swiftc -O -target arm64-apple-macos14 -module-name playtest \
  "$GAME/Content.swift" "$GAME/GameStore.swift" "$HERE/main.swift" -o "$OUT"
"$OUT" "${1:-300}"
defaults delete sandbox-playtest >/dev/null 2>&1 || true
