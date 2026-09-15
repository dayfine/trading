#!/bin/sh
# Settings hook path linter.
#
# `.claude/settings.json` hook commands must never hardcode a user-specific
# absolute path (macOS `/Users/<user>/...` or Linux `/home/<user>/...`) --
# every containerised workflow loads project settings (`settingSources:
# ["user","project","local"]`), so a hook pinned to one developer's machine
# silently fails on every CI run: nothing observes hook exit status, so the
# failure is invisible until someone goes looking (H-SETTINGS-HOOKS-ABSOLUTE-
# LOCAL-PATH, dev/status/harness.md -- both hooks in this file were pinned to
# `/Users/difan/Projects/trading-1/...` and had therefore never once run in
# CI). Hook commands must use a path relative to the project root, e.g.
# `bash dev/scripts/foo.sh` -- Claude Code invokes project hooks with the
# project directory as cwd, so a repo-relative path resolves correctly both
# locally and in CI.
#
# What is NOT flagged: absolute paths unrelated to a user's home directory
# (`/usr/bin/env`, `/tmp/...`, `/opt/homebrew/bin/jq`, etc.) -- those are
# ordinary system paths that work the same on every machine. Only the two
# known user-home prefixes are checked; this is a narrow, high-precision
# guard against the one failure mode observed, not a general absolute-path
# ban.
#
# Env override for testing:
#   SETTINGS_PATH_CHECK_FILE=<path> sh settings_path_check.sh

set -e

. "$(dirname "$0")/_check_lib.sh"

REPO_ROOT="$(repo_root)"

# Target file. Override SETTINGS_PATH_CHECK_FILE in tests to point at a
# temp fixture instead of the real repo settings file.
if [ -n "${SETTINGS_PATH_CHECK_FILE:-}" ]; then
  TARGET="$SETTINGS_PATH_CHECK_FILE"
else
  TARGET="${REPO_ROOT}/.claude/settings.json"
fi

[ -f "$TARGET" ] || die "settings_path_check: $TARGET does not exist"

# /Users/            -- macOS home directory root.
# /home/<name>/       -- Linux home directory root. The trailing "/" after
#   the username segment is required so this does not false-positive on
#   unrelated paths that merely start with the substring "home" without the
#   directory-separator boundary, e.g. "/opt/homebrew/bin/jq".
MATCHES=$(grep -nE '/Users/|/home/[A-Za-z0-9_.-]+/' "$TARGET" || true)

if [ -n "$MATCHES" ]; then
  echo "FAIL: settings_path_check -- ${TARGET} contains a user-specific absolute path:"
  echo "$MATCHES"
  echo ""
  echo "Fix: use a path relative to the project root, e.g. 'bash dev/scripts/foo.sh'."
  echo "     Claude Code invokes project hooks with the project directory as cwd, so"
  echo "     a repo-relative path resolves correctly both locally and in CI."
  exit 1
fi

echo "OK: settings_path_check -- ${TARGET} has no user-specific absolute paths."
