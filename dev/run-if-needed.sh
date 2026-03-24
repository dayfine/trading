#!/usr/bin/env bash
# Run the daily agent session if it hasn't run yet today.
# Hook this into Docker container startup, shell login, or OS wake.
# Safe to call multiple times — skips if today's summary already exists.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TODAY="$(date +%Y-%m-%d)"
SUMMARY="$REPO_ROOT/dev/daily/$TODAY.md"
LOCK="$REPO_ROOT/dev/logs/$TODAY.running"

# Already done today
if [ -f "$SUMMARY" ]; then
  echo "[weinstein] Today's run already complete: $SUMMARY"
  exit 0
fi

# Already running (another process)
if [ -f "$LOCK" ]; then
  echo "[weinstein] Run already in progress (lock: $LOCK)"
  exit 0
fi

echo "[weinstein] Starting daily run for $TODAY"
touch "$LOCK"
trap 'rm -f "$LOCK"' EXIT

"$REPO_ROOT/dev/run.sh"
