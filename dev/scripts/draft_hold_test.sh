#!/bin/sh
# Exercise the actual documented check_hold, with no network or merge calls.
set -eu
ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)
DOC=${DRAFT_HOLD_DOC:-$ROOT/.claude/agents/lead-orchestrator.md}
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
awk '/^check_hold\(\) \{/ { copying=1 } copying { print } copying && /^}/ { exit }' "$DOC" > "$TMP/check_hold.sh"
test -s "$TMP/check_hold.sh"
passed=0
failed=0
check() {
  name=$1 PR_JSON=$2 TIMELINE=$3 expected=$4
  PR_RC=${5:-0} TIMELINE_RC=${6:-0}
  export PR_JSON TIMELINE PR_RC TIMELINE_RC
  actual=$(bash -c '
    source "$1"
    curl() {
      case "${*: -1}" in
        */pulls/*) printf "%s" "$PR_JSON"; return "$PR_RC" ;;
        */timeline*) printf "%s" "$TIMELINE"; return "$TIMELINE_RC" ;;
        *) return 99 ;;
      esac
    }
    GH_TOKEN=fixture REPO=fixture/repo PR_NUMBER=1
    check_hold
    printf "%s" "$HELD"
  ' bash "$TMP/check_hold.sh" 2> "$TMP/stderr")
  if [ "$actual" = "$expected" ]; then
    passed=$((passed + 1)); printf 'ok   %s\n' "$name"
  else
    failed=$((failed + 1)); printf 'FAIL %s: expected %s, got %s\n' "$name" "$expected" "$actual"
  fi
}
draft='{"labels":[],"draft":true}'
ready='{"labels":[],"draft":false}'
review='{"event":"reviewed","submitted_at":"2026-08-19T10:00:00Z"}'
conversion='{"event":"convert_to_draft","created_at":"2026-08-19T11:00:00Z"}'
# Mutation: reading created_at alone loses submitted_at precedence; changing
# the failure default to HELD=false loses malformed/transport cases below.
check 'review then conversion is held' "$draft" "[$review,$conversion]" true
check 'opened as draft without conversion is not held' "$draft" "[$review]" false
check 'conversion before review is not held' "$draft" '[{"event":"convert_to_draft","created_at":"2026-08-19T09:00:00Z"},{"event":"reviewed","submitted_at":"2026-08-19T10:00:00Z"}]' false
check 'ready PR without hold label is not held' "$ready" '[]' false
check 'hold label wins on a ready PR' '{"labels":[{"name":"do-not-merge"}],"draft":false}' '[]' true
check 'created_at review fallback works' "$draft" '[{"event":"reviewed","created_at":"2026-08-19T10:00:00Z"},{"event":"convert_to_draft","created_at":"2026-08-19T11:00:00Z"}]' true
check 'submitted_at takes precedence' "$draft" '[{"event":"reviewed","submitted_at":"2026-08-19T12:00:00Z","created_at":"2026-08-19T10:00:00Z"},{"event":"convert_to_draft","created_at":"2026-08-19T11:00:00Z"}]' false
check 'earliest review independent of event order' "$draft" '[{"event":"reviewed","submitted_at":"2026-08-19T12:00:00Z"},{"event":"convert_to_draft","created_at":"2026-08-19T11:00:00Z"},{"event":"reviewed","submitted_at":"2026-08-19T10:00:00Z"}]' true
check 'malformed timeline is held' "$draft" 'invalid' true
check 'API error object is held' "$draft" '{"message":"rate limited"}' true
check 'missing review timestamp is held' "$draft" '[{"event":"reviewed"}]' true
check 'missing conversion timestamp is held' "$draft" "[$review,{\"event\":\"convert_to_draft\"}]" true
check 'malformed PR is held' 'invalid' '[]' true
check 'missing PR fields are held' '{}' '[]' true
check 'PR transport failure is held' "$ready" '[]' true 22
check 'timeline transport failure is held' "$draft" '[]' true 0 22
printf '\n%s/%s checks passed\n' "$passed" "$((passed + failed))"
test "$failed" -eq 0
