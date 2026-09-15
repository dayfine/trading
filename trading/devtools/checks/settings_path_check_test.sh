#!/bin/sh
# Fixture-driven test for settings_path_check.sh.
#
# Drives the linter over temp fixtures via SETTINGS_PATH_CHECK_FILE -- never
# over the live .claude/settings.json alone, since that file being clean
# would make this test pass vacuously the moment the file happens to be
# fixed (which is exactly what H-SETTINGS-HOOKS-ABSOLUTE-LOCAL-PATH's fix
# does). Each scenario is an independent JSON fixture under mktemp.

set -e

. "$(dirname "$0")/_check_lib.sh"

LINTER="$(dirname "$0")/settings_path_check.sh"
[ -f "$LINTER" ] || die "settings_path_check_test: linter not found at $LINTER"

TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT

_run_linter() {
  # $1 = fixture path. Sets ACTUAL_OUTPUT / ACTUAL_EXIT.
  ACTUAL_OUTPUT="$(SETTINGS_PATH_CHECK_FILE="$1" sh "$LINTER" 2>&1)" && ACTUAL_EXIT=0 || ACTUAL_EXIT=$?
}

# ---- Scenario 1: macOS /Users/ absolute path -- must FAIL ----

MACOS_FIXTURE="${TMPDIR_BASE}/macos.json"
cat > "$MACOS_FIXTURE" << 'EOF'
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          { "type": "command", "command": "bash /Users/difan/Projects/trading-1/dev/scripts/sweep_stale_worktrees.sh" }
        ]
      }
    ]
  }
}
EOF

_run_linter "$MACOS_FIXTURE"
if [ "$ACTUAL_EXIT" -eq 0 ]; then
  echo "FAIL: settings_path_check_test -- linter exited 0 on /Users/ fixture (expected non-zero)"
  echo "  output: $ACTUAL_OUTPUT"
  exit 1
fi
if ! printf '%s' "$ACTUAL_OUTPUT" | grep -q "FAIL"; then
  echo "FAIL: settings_path_check_test -- 'FAIL' not in /Users/ fixture output"
  echo "  output: $ACTUAL_OUTPUT"
  exit 1
fi

# ---- Scenario 2: Linux /home/<user>/ absolute path -- must FAIL ----

LINUX_FIXTURE="${TMPDIR_BASE}/linux.json"
cat > "$LINUX_FIXTURE" << 'EOF'
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          { "type": "command", "command": "bash /home/alice/trading-1/dev/scripts/cleanup_merged_worktrees.sh" }
        ]
      }
    ]
  }
}
EOF

_run_linter "$LINUX_FIXTURE"
if [ "$ACTUAL_EXIT" -eq 0 ]; then
  echo "FAIL: settings_path_check_test -- linter exited 0 on /home/ fixture (expected non-zero)"
  echo "  output: $ACTUAL_OUTPUT"
  exit 1
fi
if ! printf '%s' "$ACTUAL_OUTPUT" | grep -q "FAIL"; then
  echo "FAIL: settings_path_check_test -- 'FAIL' not in /home/ fixture output"
  echo "  output: $ACTUAL_OUTPUT"
  exit 1
fi

# ---- Scenario 3: clean fixture, repo-relative hook paths only -- must PASS ----

CLEAN_FIXTURE="${TMPDIR_BASE}/clean.json"
cat > "$CLEAN_FIXTURE" << 'EOF'
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          { "type": "command", "command": "bash dev/scripts/sweep_stale_worktrees.sh --threshold-percent 85 --stale-hours 24" }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          { "type": "command", "command": "bash dev/scripts/cleanup_merged_worktrees.sh" }
        ]
      }
    ]
  }
}
EOF

_run_linter "$CLEAN_FIXTURE"
if [ "$ACTUAL_EXIT" -ne 0 ]; then
  echo "FAIL: settings_path_check_test -- linter failed on clean fixture (expected exit 0)"
  echo "  output: $ACTUAL_OUTPUT"
  exit 1
fi
if ! printf '%s' "$ACTUAL_OUTPUT" | grep -q "OK"; then
  echo "FAIL: settings_path_check_test -- 'OK' not in clean-fixture output"
  echo "  output: $ACTUAL_OUTPUT"
  exit 1
fi

# ---- Scenario 4: legitimate absolute paths that are NOT user-home -- must PASS ----
# Covers the "fail direction" requirement: a real absolute path that any
# machine has (system binaries, /tmp) must never be flagged, including the
# "/opt/homebrew/..." near-miss that contains the substring "home" but not
# the "/home/<user>/" directory-boundary shape this linter targets.

NONHOME_FIXTURE="${TMPDIR_BASE}/nonhome.json"
cat > "$NONHOME_FIXTURE" << 'EOF'
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          { "type": "command", "command": "/usr/bin/env bash dev/scripts/sweep_stale_worktrees.sh" }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          { "type": "command", "command": "/opt/homebrew/bin/jq -e . /tmp/some-output.json" }
        ]
      }
    ]
  }
}
EOF

_run_linter "$NONHOME_FIXTURE"
if [ "$ACTUAL_EXIT" -ne 0 ]; then
  echo "FAIL: settings_path_check_test -- linter failed on non-home-absolute-path fixture (expected exit 0, false positive)"
  echo "  output: $ACTUAL_OUTPUT"
  exit 1
fi
if ! printf '%s' "$ACTUAL_OUTPUT" | grep -q "OK"; then
  echo "FAIL: settings_path_check_test -- 'OK' not in non-home-absolute-path fixture output"
  echo "  output: $ACTUAL_OUTPUT"
  exit 1
fi

# ---- Scenario 5: missing target file -- must fail loudly, never pass silently ----

MISSING_FIXTURE="${TMPDIR_BASE}/does-not-exist.json"

_run_linter "$MISSING_FIXTURE"
if [ "$ACTUAL_EXIT" -eq 0 ]; then
  echo "FAIL: settings_path_check_test -- linter exited 0 on a missing target file (expected non-zero; a missing file must never read as clean)"
  echo "  output: $ACTUAL_OUTPUT"
  exit 1
fi
if ! printf '%s' "$ACTUAL_OUTPUT" | grep -q "FAIL"; then
  echo "FAIL: settings_path_check_test -- 'FAIL' not in missing-file output"
  echo "  output: $ACTUAL_OUTPUT"
  exit 1
fi

echo "OK: settings_path_check_test -- all 5 scenarios passed (macOS FAIL, Linux FAIL, clean PASS, non-home-absolute PASS, missing-file FAIL)."
