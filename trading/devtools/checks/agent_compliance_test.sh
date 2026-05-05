#!/bin/sh
# Smoke test for agent_compliance_check.sh.
#
# Assertions:
#  1. The as-checked-in tree passes (all jj-writing agents have ## Pre-Work Setup).
#  2. A deliberately-stripped temp copy of feat-data.md (## Pre-Work Setup removed)
#     causes the check to FAIL.

set -e

. "$(dirname "$0")/_check_lib.sh"

AGENTS_DIR="$(repo_root)/.claude/agents"
CHECK="$(dirname "$0")/agent_compliance_check.sh"

PASS=0
FAIL=0

# --- Assertion 1: as-is tree passes ---
if sh "$CHECK" >/dev/null 2>&1; then
  PASS=$((PASS + 1))
else
  echo "FAIL: assertion 1 — agent_compliance_check.sh failed on the as-checked-in tree"
  FAIL=$((FAIL + 1))
fi

# --- Assertion 2: stripped feat-data.md causes FAIL ---
TMPDIR_AGENTS=$(mktemp -d)
trap 'rm -rf "$TMPDIR_AGENTS"' EXIT INT TERM

# Copy all agent files into the temp dir
for f in "$AGENTS_DIR"/*.md; do
  [ -f "$f" ] || continue
  cp "$f" "$TMPDIR_AGENTS/$(basename "$f")"
done

# Strip ## Pre-Work Setup from feat-data.md in temp dir
# Remove the line "## Pre-Work Setup" and the block until the next "## " heading.
# We use a simple awk approach: skip from "## Pre-Work Setup" to the next ## heading.
awk '
  /^## Pre-Work Setup$/ { skip=1; next }
  skip && /^## / { skip=0 }
  !skip
' "$TMPDIR_AGENTS/feat-data.md" > "$TMPDIR_AGENTS/feat-data.md.tmp"
mv "$TMPDIR_AGENTS/feat-data.md.tmp" "$TMPDIR_AGENTS/feat-data.md"

# Run the check against the temp agents dir
if REPO_ROOT="$(repo_root)" sh "$CHECK" 2>/dev/null; then
  # Check used the real AGENTS_DIR (via repo_root), not our temp dir.
  # We need a different approach: override AGENTS_DIR inside the check.
  # Since the check uses repo_root()/.claude/agents, we can't trivially override
  # from outside. Instead, verify the stripped file actually lacks the section.
  :
fi

# Verify the stripped file truly lacks the section (sanity check)
if grep -qF "## Pre-Work Setup" "$TMPDIR_AGENTS/feat-data.md"; then
  echo "FAIL: assertion 2 setup — strip did not remove ## Pre-Work Setup from temp copy"
  FAIL=$((FAIL + 1))
else
  # Run the check with REPO_ROOT pointing to a temp structure
  # Build the full temp structure: REPO_ROOT needs .claude/agents/
  TMPROOT=$(mktemp -d)
  trap 'rm -rf "$TMPDIR_AGENTS" "$TMPROOT"' EXIT INT TERM
  mkdir -p "$TMPROOT/.claude/agents"
  cp "$TMPDIR_AGENTS"/*.md "$TMPROOT/.claude/agents/"

  if REPO_ROOT="$TMPROOT" sh "$CHECK" >/dev/null 2>&1; then
    echo "FAIL: assertion 2 — check passed on a tree where feat-data.md is missing ## Pre-Work Setup (expected FAIL)"
    FAIL=$((FAIL + 1))
  else
    PASS=$((PASS + 1))
  fi
fi

# --- Summary ---
if [ "$FAIL" -gt 0 ]; then
  echo "FAIL: agent_compliance_test — ${FAIL} assertion(s) failed, ${PASS} passed."
  exit 1
fi

echo "OK: agent_compliance_test — all ${PASS} assertions passed."
