#!/bin/sh
# session_brief_test.sh -- fixture tests for dev/scripts/session_brief.sh (the SessionStart
# and PreCompact hooks). Offline: no gh, no network.
#
# Pins:
#   1. brief picks the newest doc by the date in its NAME, not by mtime (the older-named
#      doc is touched last, which is what a fresh checkout looks like).
#   2. brief warns when the newest doc is older than 3 days, and not when it is fresh.
#   3. precompact is silent when a doc is dated today, and emits a systemMessage when not.
#   4. both modes exit 0 with no docs at all.

set -eu

. "$(dirname "$0")/_check_lib.sh"

SCRIPT="$(repo_root)/dev/scripts/session_brief.sh"
TMP="${TMPDIR:-/tmp}/session-brief-test-$$"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/notes" "$TMP/empty"

FAIL=0
expect() {  # expect <label> <haystack> <needle>
  if printf '%s\n' "$2" | grep -q -- "$3"; then
    printf 'OK: session_brief_test -- %s\n' "$1"
  else
    printf 'FAIL: session_brief_test -- %s: expected "%s" in:\n%s\n' "$1" "$3" "$2" >&2
    FAIL=1
  fi
}
expect_not() {
  if printf '%s\n' "$2" | grep -q -- "$3"; then
    printf 'FAIL: session_brief_test -- %s: unexpected "%s" in:\n%s\n' "$1" "$3" "$2" >&2
    FAIL=1
  else
    printf 'OK: session_brief_test -- %s\n' "$1"
  fi
}

printf 'NEWER-BODY\n' > "$TMP/notes/next-session-priorities-2026-11-02.md"
sleep 1
printf 'OLDER-BODY\n' > "$TMP/notes/next-session-priorities-2026-10-13.md"

run() {  # run <mode> <today> <notes-dir>
  SESSION_BRIEF_OFFLINE=1 SESSION_BRIEF_TODAY="$2" SESSION_BRIEF_NOTES_DIR="$3" \
    sh "$SCRIPT" "$1"
}

out=$(run brief 2026-11-02 "$TMP/notes")
expect "picks newest by name" "$out" "next-session-priorities-2026-11-02.md (dated 2026-11-02, 0 day"
expect "prints the newest doc body" "$out" "NEWER-BODY"
expect_not "ignores the later-touched older doc" "$out" "OLDER-BODY"
expect_not "fresh doc is not stale" "$out" "WARNING: handoff is stale"

out=$(run brief 2026-11-10 "$TMP/notes")
expect "stale doc warns" "$out" "WARNING: handoff is stale"

out=$(run precompact 2026-11-02 "$TMP/notes")
[ -z "$out" ] && printf 'OK: session_brief_test -- precompact silent with today'"'"'s doc\n' \
  || { printf 'FAIL: session_brief_test -- precompact printed with today'"'"'s doc: %s\n' "$out" >&2; FAIL=1; }

out=$(run precompact 2026-11-03 "$TMP/notes")
expect "precompact warns without today's doc" "$out" '"systemMessage": "No handoff dated 2026-11-03 (newest: 2026-11-02)'

out=$(run brief 2026-11-02 "$TMP/empty")
expect "brief with no docs" "$out" "No next-session-priorities doc found"
out=$(run precompact 2026-11-02 "$TMP/empty")
expect "precompact with no docs" "$out" "newest: none"

[ "$FAIL" -eq 0 ] || exit 1
printf 'OK: session_brief_test -- all assertions passed\n'
