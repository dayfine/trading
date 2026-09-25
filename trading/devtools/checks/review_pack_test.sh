#!/bin/sh
# review_pack_test.sh -- fixture-driven regression test for
# dev/scripts/review_pack.sh (host-side pipeline, --no-container) over
# trading/devtools/checks/fixtures/review_pack/: 100 synthetic trading days,
# three trades.
#
# What it pins:
#   - AAA: the low trades through the 4% stop on one bar and the exit fills at
#     the next open -> breach lag 1; the hard-stop replay (3/5/6/8/10/15 %) cuts
#     at 3 % and 5 % and keeps the actual -3 % beyond; 8-week pick return +20 %;
#     the stock then runs 24 % above the exit -> grade D;
#   - BBB: the entry fill sits on a later 2:1 split basis -> in-range code 2
#     (not an off-bar fill), and its adjusted entry lands on the bar's own basis;
#   - ZZZ: no bars in the store -> "nodata", the run still builds;
#   - every emitted JSON file parses (the SPY fixture carries a "321."-style
#     value the store really writes), manifest + year/quarter tables present.
#
# Run:
#   sh trading/devtools/checks/review_pack_test.sh

set -eu

. "$(dirname "$0")/_check_lib.sh"

PASS=0
FAILED=0
expect_eq() {
  # $1 = label, $2 = expected, $3 = actual
  if [ "$2" = "$3" ]; then
    printf 'OK: %s (%s)\n' "$1" "$3"; PASS=$((PASS + 1))
  else
    printf 'FAIL: %s: expected '\''%s'\'', got '\''%s'\''\n' "$1" "$2" "$3" >&2; FAILED=$((FAILED + 1))
  fi
}

ROOT="$(repo_root)"
SCRIPT="${ROOT}/dev/scripts/review_pack.sh"
FIX="${ROOT}/trading/devtools/checks/fixtures/review_pack"
[ -f "$SCRIPT" ] || { echo "FAIL: script under test not found: $SCRIPT" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "SKIP: review_pack_test needs jq"; exit 0; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT INT TERM

rc=0
sh "$SCRIPT" --no-container --data-dir "$FIX/data" --out "$TMP/pack" --title "Fixture" r0="$FIX/run/" >"$TMP/log" 2>&1 || rc=$?
expect_eq "builds: exit 0" 0 "$rc"
[ "$rc" = 0 ] || { cat "$TMP/log" >&2; exit 1; }
S="$TMP/pack/site"
T="$S/data/r0_trades.json"
q() { jq -r "$1" "$T"; }

expect_eq "index.html copied" yes "$([ -s "$S/index.html" ] && echo yes || echo no)"
expect_eq "manifest: one run, charts run 0" "Fixture r0 0" "$(jq -r '"\(.title) \(.runs[0].id) \(.charts_run)"' "$S/data/manifest.json")"
bad=0; for f in "$S"/data/*.json "$S"/data/charts/*.json; do jq -e true "$f" >/dev/null 2>&1 || bad=$((bad + 1)); done
expect_eq "every JSON file parses" 0 "$bad"
expect_eq "spy.json clipped to the run window" 100 "$(jq length "$S/data/spy.json")"
expect_eq "three trades joined" 3 "$(q length)"

expect_eq "AAA breach lag" 1 "$(q '.[]|select(.sym=="AAA")|.blag')"
expect_eq "AAA hard-stop replay" "-3,-5,-3,-3,-3,-3" "$(q '.[]|select(.sym=="AAA")|.cf|map(.+0|tostring)|join(",")')"
expect_eq "AAA 8-week pick return" 20 "$(q '.[]|select(.sym=="AAA")|.f40+0')"
expect_eq "AAA grade" D "$(q '.[]|select(.sym=="AAA")|.g')"
expect_eq "AAA fills on the bar" "1 1 1 1" "$(q '.[]|select(.sym=="AAA")|"\(.onE) \(.inE) \(.onX) \(.inX)"')"

expect_eq "BBB entry on a later split basis" 2 "$(q '.[]|select(.sym=="BBB")|.inE')"
expect_eq "BBB adjusted entry on the bar basis" 25.1 "$(q '.[]|select(.sym=="BBB")|.eadj+0')"
expect_eq "BBB entry vs prior close, split-corrected" 0.4 "$(q '.[]|select(.sym=="BBB")|.gap+0')"

expect_eq "ZZZ has no bars" true "$(q '.[]|select(.sym=="ZZZ")|.nodata')"
expect_eq "year table: one row" 2020 "$(jq -r '.[0].p' "$S/data/r0_years.json")"
expect_eq "quarter table: two rows" "2020Q1 2020Q2" "$(jq -r 'map(.p)|join(" ")' "$S/data/r0_quarters.json")"
expect_eq "validator check parsed" V13 "$(jq -r '.validator[1].id' "$S/data/r0_meta.json")"

printf '%s: %d passed, %d failed\n' "review_pack_test" "$PASS" "$FAILED"
[ "$FAILED" = 0 ]
