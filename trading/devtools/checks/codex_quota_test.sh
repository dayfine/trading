#!/bin/sh
# Offline test for dev/scripts/codex_quota.sh (Codex hand-off pacing, AGENTS.md "Usage budget"). Fixture rollout logs
# in a temp $CODEX_HOME stand in for ~/.codex/sessions; --no-probe keeps the real codex CLI out of it. Pins:
# the newest rollout wins; primary = five-hour and secondary = weekly; --guard / --weekly-guard exit 3 at or above
# the threshold and 0 below it; no rollout, or rate_limits without used_percent, exits 4; each reading is logged.
set -eu
. "$(dirname "$0")/_check_lib.sh"
ROOT=$(repo_root)
Q="$ROOT/dev/scripts/codex_quota.sh"
[ -f "$Q" ] || { echo "FAIL: $Q missing" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not installed"; exit 0; }

W=$(mktemp -d)
trap 'rm -rf "$W"' EXIT
FAILS=0
fail() { echo "FAIL: $1" >&2; FAILS=$((FAILS + 1)); }
expect() { grep -Eq "$2" "$1" || { fail "$3 (no match for: $2)"; sed 's/^/    | /' "$1" >&2; }; }
rc_is() { [ "$1" = "$2" ] || fail "$3: exit $1, expected $2"; }

# rollout line with the token_count shape codex-cli 0.163.0 writes
line() { # line <five%> <weekly%>
  printf '{"timestamp":"t","type":"event_msg","payload":{"type":"token_count","info":null,"rate_limits":{"limit_id":"codex","primary":{"used_percent":%s,"window_minutes":300,"resets_at":%s},"secondary":{"used_percent":%s,"window_minutes":10080,"resets_at":%s}}}}\n' \
    "$1" "$(($(date -u +%s) + 3600))" "$2" "$(($(date -u +%s) + 86400))"
}
run() { # run <home> <args...>; output in $W/out, exit code in $RC
  h=$1; shift
  RC=0; CODEX_HOME=$h CODEX_QUOTA_LOG="$W/log.csv" sh "$Q" --no-probe --max-age 999999999 "$@" > "$W/out" 2>&1 || RC=$?
}

H="$W/home"; D="$H/sessions/2026/10/21"; mkdir -p "$D"
{ echo '{"type":"session_meta"}'; line 10 20; } > "$D/rollout-old.jsonl"
touch -t 202610210100 "$D/rollout-old.jsonl"
{ echo '{"type":"session_meta"}'; line 40 50; line 64 76; echo '{"type":"turn.completed"}'; } > "$D/rollout-new.jsonl"
echo '{"type":"session_meta"}' > "$D/rollout-nolimits.jsonl"   # newest by mtime, but no rate_limits: skipped

# 1. newest rollout with rate_limits, last reading in it; primary = five-hour, secondary = weekly
run "$H"; rc_is "$RC" 0 "plain read"
expect "$W/out" '^codex five-hour: 64 % used' "five-hour from the last primary"
expect "$W/out" '^codex weekly: 76 % used' "weekly from the last secondary"
# 2. guards: below -> 0, at/above -> 3, naming the window
run "$H" --guard 70; rc_is "$RC" 0 "five-hour 64 under guard 70"
run "$H" --guard 64; rc_is "$RC" 3 "five-hour 64 at guard 64"
expect "$W/out" 'five-hour 64 % >= guard 64 %' "five-hour guard message"
run "$H" --weekly-guard 80; rc_is "$RC" 0 "weekly 76 under guard 80"
run "$H" --weekly-guard 75; rc_is "$RC" 3 "weekly 76 over guard 75"
expect "$W/out" 'weekly 76 % >= guard 75 %' "weekly guard message"
# 3. the log gets one row per reading
[ "$(grep -c '^[0-9]*,64,76,' "$W/log.csv")" = 5 ] || fail "log rows: $(cat "$W/log.csv")"
# 4. no rollout at all -> 4
mkdir -p "$W/empty/sessions"
run "$W/empty"; rc_is "$RC" 4 "no rollout"
expect "$W/out" 'no rollout with rate_limits' "no-rollout message"
# 5. rate_limits without used_percent -> 4
H2="$W/home2"; mkdir -p "$H2/sessions/x"
echo '{"payload":{"rate_limits":{"primary":null,"secondary":null}}}' > "$H2/sessions/x/rollout-a.jsonl"
run "$H2"; rc_is "$RC" 4 "rate_limits without used_percent"
# 6. a stale reading with --no-probe is still read (no CLI call), and its age is printed
run "$H" --max-age 0; rc_is "$RC" 0 "stale reading, no probe"
expect "$W/out" '^reading age: [0-9]+ s' "reading age line"
# 7. usage error
RC=0; sh "$Q" --bogus > "$W/out" 2>&1 || RC=$?; rc_is "$RC" 2 "unknown flag"

[ "$FAILS" = 0 ] || { echo "codex_quota_test: $FAILS failure(s)" >&2; exit 1; }
echo "codex_quota_test: OK"
