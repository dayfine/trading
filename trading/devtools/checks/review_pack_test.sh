#!/bin/sh
# review_pack_test.sh -- fixture-driven regression test for
# dev/scripts/review_pack.sh (host-side pipeline, --no-container) over
# trading/devtools/checks/fixtures/review_pack/: 100 synthetic trading days,
# six trades.
#
# What it pins:
#   - AAA: the low trades through the 4% stop on one bar and the exit fills at
#     the next open -> breach lag 1; the hard-stop replay (3/5/6/8/10/15 %) cuts
#     at 3 % and 5 % and keeps the actual -3 % beyond; 8-week pick return +20 %;
#     the stock then runs 24 % above the exit -> grade D;
#   - BBB: the entry fill sits on a later 2:1 split basis -> in-range code 2
#     (not an off-bar fill), and its adjusted entry lands on the bar's own basis;
#   - ZZZ: no bars in the store -> "nodata", the run still builds;
#   - CCC: entry dated a Saturday -> the prior Friday bar is used, not dropped;
#     exits on the last bar -> grade "A?" (no post-exit path);
#   - DDD: loss, then +58 % within 65 bars -> F; exit fill off the bar -> code 0;
#     its decision-time stop distance (1 %, line 39.60) is breached by the 39.50
#     lows, but the installed stop (entry_stop 37.50) is not before the exit day
#     -> breach lag -1: the breach line is the installed stop, not entry x (1 - sid);
#   - EEE: exit under 5 % of entry -> X;
#   - two runs (r0, r1) -> manifest lists both and both trade files exist;
#   - every emitted JSON file parses (the SPY fixture carries a "321."-style
#     value the store really writes), manifest + year/quarter tables present;
#   - the page's signal predicates (openSignal, oneTradeYear, alsoCause) are
#     extracted with sed and evaluated with node over named cases (#3084);
#     skipped with a notice when node is not installed.
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
sh "$SCRIPT" --no-container --data-dir "$FIX/data" --out "$TMP/pack" --title "Fixture" r0="$FIX/run/" r1="$FIX/run/" >"$TMP/log" 2>"$TMP/err" || rc=$?
expect_eq "builds: exit 0" 0 "$rc"
[ "$rc" = 0 ] || { cat "$TMP/log" "$TMP/err" >&2; exit 1; }
# --no-container never writes trade_audit_report.md: nothing may complain about the absent file (#2978)
expect_eq "no-container: stderr holds only progress lines" "" "$(grep -v '^\[review_pack ' "$TMP/err")"
S="$TMP/pack/site"
T="$S/data/r0_trades.json"
q() { jq -r "$1" "$T"; }

expect_eq "index.html copied" yes "$([ -s "$S/index.html" ] && echo yes || echo no)"
expect_eq "manifest: two runs, charts run 0" "Fixture r0,r1 0" "$(jq -r '"\(.title) \(.runs|map(.id)|join(","))  \(.charts_run)"' "$S/data/manifest.json" | tr -s " ")"
bad=0; for f in "$S"/data/*.json "$S"/data/charts/*.json; do jq -e true "$f" >/dev/null 2>&1 || bad=$((bad + 1)); done
expect_eq "every JSON file parses" 0 "$bad"
expect_eq "spy.json clipped to the run window" 100 "$(jq length "$S/data/spy.json")"
expect_eq "six trades joined" 6 "$(q length)"

expect_eq "AAA breach lag" 1 "$(q '.[]|select(.sym=="AAA")|.blag')"
expect_eq "AAA hard-stop replay" "-3,-5,-3,-3,-3,-3" "$(q '.[]|select(.sym=="AAA")|.cf|map(.+0|tostring)|join(",")')"
expect_eq "AAA 8-week pick return" 20 "$(q '.[]|select(.sym=="AAA")|.f40+0')"
expect_eq "AAA grade" D "$(q '.[]|select(.sym=="AAA")|.g')"
expect_eq "AAA fills on the bar" "1 1 1 1" "$(q '.[]|select(.sym=="AAA")|"\(.onE) \(.inE) \(.onX) \(.inX)"')"

expect_eq "BBB entry on a later split basis" 2 "$(q '.[]|select(.sym=="BBB")|.inE')"
expect_eq "BBB adjusted entry on the bar basis" 25.1 "$(q '.[]|select(.sym=="BBB")|.eadj+0')"
expect_eq "BBB entry vs prior close, split-corrected" 0.4 "$(q '.[]|select(.sym=="BBB")|.gap+0')"

expect_eq "ZZZ has no bars" true "$(q '.[]|select(.sym=="ZZZ")|.nodata')"

# Saturday-dated entry: the last bar on/before the date (Friday) is used, the
# trade is NOT dropped as nodata, and the fill is not checked against a bar.
expect_eq "CCC Saturday entry uses the prior Friday" "2020-01-24 0 null" "$(q '.[]|select(.sym=="CCC")|"\(.ebar) \(.onE) \(.nodata)"')"
expect_eq "CCC exits on the last bar: A with no post-exit path" "A?" "$(q '.[]|select(.sym=="CCC")|.g')"
expect_eq "DDD loses, then runs >= 50 %: F" F "$(q '.[]|select(.sym=="DDD")|.g')"
expect_eq "DDD exit fill genuinely off the bar: code 0" 0 "$(q '.[]|select(.sym=="DDD")|.inX')"
expect_eq "DDD breach line = installed stop, not entry x (1 - sid); same-day fill = lag 0" 0 "$(q '.[]|select(.sym=="DDD")|.blag')"
expect_eq "page declares utf-8" yes "$(grep -q '<meta charset="utf-8">' "$S/index.html" && echo yes || echo no)"
expect_eq "charts can fit a 26y daily series (minBarSpacing set)" yes "$(grep -q 'minBarSpacing: 0.01' "$S/index.html" && echo yes || echo no)"
expect_eq "page <title> carries --title" yes "$(grep -q '^<title>Fixture</title>$' "$S/index.html" && echo yes || echo no)"
expect_eq "open-position signal present" yes "$(grep -q 'The return rests on open positions' "$S/index.html" && echo yes || echo no)"
expect_eq "gate-reopen signal present" yes "$(grep -q 'Gate reopen episodes' "$S/index.html" && echo yes || echo no)"

# Signal predicates (#3084): extract each top-level function from the shipped
# page with sed and pin it with node over named cases. The page keeps each
# closing brace at column 0 so the range ends where the function does.
if command -v node >/dev/null 2>&1; then
  FNS="$(sed -n -e '/^const REOPEN_CLOSED_WEEKS/p' -e '/^function openSignal(/,/^}/p' -e '/^function oneTradeYear(/,/^}/p' -e '/^function alsoCause(/,/^}/p' -e '/^function reopenFlag(/,/^}/p' "$S/index.html")"
  expect_eq "signal predicates extracted" 4 "$(printf '%s\n' "$FNS" | grep -c '^function ')"
  sig() { node -e "$FNS
console.log($1)"; }
  expect_eq "openSignal: opposite-sign specimen (T1 5r s0: NAV0 1M, move +115k, realised -222k) fires" true "$(sig 'openSignal(1e6, 115e3, -222e3)')"
  expect_eq "openSignal: open 200k of a 300k move (above half) fires" true "$(sig 'openSignal(1e6, 300e3, 100e3)')"
  expect_eq "openSignal: open 120k of a 300k move (below half, same sign) is quiet" false "$(sig 'openSignal(1e6, 300e3, 180e3)')"
  expect_eq "openSignal: open 80k < 10 % of NAV0 is quiet even at opposite sign" false "$(sig 'openSignal(1e6, 50e3, -30e3)')"
  expect_eq "openSignal: negative move, open -250k of -300k fires" true "$(sig 'openSignal(1e6, -300e3, -50e3)')"
  expect_eq "oneTradeYear: top 12 pp of a 20 pp gap fires" true "$(sig 'oneTradeYear(20, 12)')"
  expect_eq "oneTradeYear: top 8 pp of a 20 pp gap (under half) is quiet" false "$(sig 'oneTradeYear(20, 8)')"
  expect_eq "oneTradeYear: gap under 10 pp is quiet" false "$(sig 'oneTradeYear(8, 8)')"
  expect_eq "oneTradeYear: negative gap, same-sign top fires" true "$(sig 'oneTradeYear(-20, -15)')"
  expect_eq "oneTradeYear: top trade of the opposite sign is quiet" false "$(sig 'oneTradeYear(20, -15)')"
  expect_eq "alsoCause: second gap half the first fires" true "$(sig 'alsoCause(0.4, 0.25)')"
  expect_eq "alsoCause: second gap >= 0.15 log fires below half" true "$(sig 'alsoCause(0.6, 0.16)')"
  expect_eq "alsoCause: small second gap is quiet" false "$(sig 'alsoCause(0.4, 0.1)')"
  expect_eq "alsoCause: opposite-sign second gap is quiet" false "$(sig 'alsoCause(0.4, -0.3)')"
  expect_eq "reopenFlag: 2009-05 (0 entries, -1.5 % vs SPY +16.4 %) = sat out" "sat out" "$(sig 'reopenFlag(0, -1.5, 16.4)')"
  expect_eq "reopenFlag: 2025-05 (12 entries, -8.0 % vs +14.5 %) = invested and lagged" "invested and lagged" "$(sig 'reopenFlag(12, -8.0, 14.5)')"
  expect_eq "reopenFlag: 2010-10 (4 entries, +7.4 % vs +15.1 %, gap 7.7 pp) is quiet" "" "$(sig 'reopenFlag(4, 7.4, 15.1)')"
  expect_eq "reopenFlag: 2019-02 (2 entries, -0.5 % vs +5.1 %, SPY under 8 %) is quiet" "" "$(sig 'reopenFlag(2, -0.5, 5.1)')"
  expect_eq "reopenFlag: 4 entries trailing a +20 % SPY by 10 pp = lagged" "lagged" "$(sig 'reopenFlag(4, 10, 20)')"
  expect_eq "reopenFlag: 2020-06 (6 entries, +25.2 % vs +16.8 %, ahead) is quiet" "" "$(sig 'reopenFlag(6, 25.2, 16.8)')"
  expect_eq "reopenFlag: missing return is quiet" "" "$(sig 'reopenFlag(0, null, 16.4)')"
else
  echo "SKIP: review_pack signal-predicate cases need node"
fi
expect_eq "EEE exits under 5 % of entry: X" X "$(q '.[]|select(.sym=="EEE")|.g')"
expect_eq "second run r1 emitted" 6 "$(jq length "$S/data/r1_trades.json")"
expect_eq "year table: one row" 2020 "$(jq -r '.[0].p' "$S/data/r0_years.json")"
expect_eq "quarter table: two rows" "2020Q1 2020Q2" "$(jq -r 'map(.p)|join(" ")' "$S/data/r0_quarters.json")"
expect_eq "validator check parsed" V13 "$(jq -r '.validator[1].id' "$S/data/r0_meta.json")"

printf '%s: %d passed, %d failed\n' "review_pack_test" "$PASS" "$FAILED"
[ "$FAILED" = 0 ]
