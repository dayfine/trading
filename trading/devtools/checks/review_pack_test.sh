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
#   - open at the window end (#3125): an open_positions.csv row joins the
#     exposure series (last day 11.9 % = 12,000 / 101,000), the macro cards
#     count it, and the last-day check vs actual.sexp open_positions_value
#     warns on a mismatch; a market holiday (no SPY bar) is dropped from the
#     exposure series and from the period Invested average; a delisting exit
#     is not counted as the Saturday-fill defect;
#   - every emitted JSON file parses (the SPY fixture carries a "321."-style
#     value the store really writes), manifest + year/quarter tables present;
#   - the page's signal predicates (openSignal, oneTradeYear, alsoCause) are
#     extracted with sed and evaluated with node over named cases (#3084);
#     skipped with a notice when node is not installed.
#   - short leg (#3111): a run whose params enable shorts gets meta.short_leg
#     (tickets, fills, short P&L, Bearish weeks, weeks with short_top_n_admitted
#     > 0) over a fixture shaped like shorts-liveness s0-shB; audit counts are
#     null without trade_audit.sexp; shorts off -> null; shortLegLine pinned.
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

# --title / --subtitle with JSON- and HTML-special characters (#3076 follow-up): the manifest must stay valid
# JSON with both round-tripping exactly, and the page <title> carries the HTML-escaped form.
ODD_TITLE='A&B <x> "q" \d \t'
ODD_SUB='sub "s" \n <y>'
rc=0
sh "$SCRIPT" --no-container --data-dir "$FIX/data" --out "$TMP/odd" --title "$ODD_TITLE" --subtitle "$ODD_SUB" r0="$FIX/run/" >"$TMP/odd.log" 2>"$TMP/odd.err" || rc=$?
expect_eq "odd title: builds, exit 0" 0 "$rc"
expect_eq "odd title: manifest title round-trips" "$ODD_TITLE" "$(jq -r .title "$TMP/odd/site/data/manifest.json")"
expect_eq "odd title: manifest subtitle round-trips" "$ODD_SUB" "$(jq -r .subtitle "$TMP/odd/site/data/manifest.json")"
expect_eq "odd title: page <title> HTML-escaped" '<title>A&amp;B &lt;x&gt; "q" \d \t</title>' "$(grep '^<title>' "$TMP/odd/site/index.html")"
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
expect_eq "short-leg signal wired into What stands out" yes "$(grep -q 'const sl = shortLegLine(D.meta\[CH()\].short_leg);' "$S/index.html" && echo yes || echo no)"

# Signal predicates (#3084): extract each top-level function from the shipped
# page with sed and pin it with node over named cases. The page keeps each
# closing brace at column 0 so the range ends where the function does.
if command -v node >/dev/null 2>&1; then
  FNS="$(sed -n -e '/^const REOPEN_CLOSED_WEEKS/p' -e '/^function openSignal(/,/^}/p' -e '/^function oneTradeYear(/,/^}/p' -e '/^function alsoCause(/,/^}/p' -e '/^function reopenFlag(/,/^}/p' -e '/^function reopenEpisodes(/,/^}/p' -e '/^function shortLegLine(/,/^}/p' "$S/index.html")"
  expect_eq "signal predicates extracted" 6 "$(printf '%s\n' "$FNS" | grep -c '^function ')"
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
  expect_eq "reopenFlag: missing SPY is quiet" "" "$(sig 'reopenFlag(0, 5, null)')"
  # boundaries (mutation probe on #3086: each pair kills one operator or constant mutant)
  expect_eq "reopenFlag: e13 = 2 is sat out" "sat out" "$(sig 'reopenFlag(2, -5, 20)')"
  expect_eq "reopenFlag: e13 = 3 is lagged" "lagged" "$(sig 'reopenFlag(3, -5, 20)')"
  expect_eq "reopenFlag: e13 = 5 is lagged" "lagged" "$(sig 'reopenFlag(5, -5, 20)')"
  expect_eq "reopenFlag: e13 = 6 is invested and lagged" "invested and lagged" "$(sig 'reopenFlag(6, -5, 20)')"
  expect_eq "reopenFlag: SPY exactly 8 % with a 8 pp gap fires" "sat out" "$(sig 'reopenFlag(0, 0, 8)')"
  expect_eq "reopenFlag: SPY 7.99 % is quiet even 28 pp behind" "" "$(sig 'reopenFlag(0, -20, 7.99)')"
  expect_eq "reopenFlag: gap exactly 8 pp fires" "sat out" "$(sig 'reopenFlag(0, 12, 20)')"
  expect_eq "reopenFlag: gap 7.99 pp is quiet" "" "$(sig 'reopenFlag(0, 12.01, 20)')"
  # reopenEpisodes over synthetic series: day(n) = 2020-01-03 + n days; macro(c) = c Bearish weeks then
  # one Bullish week on day 7c; daily(a, b, f) = rows [date, f(i), 0, 0] for days a..b.
  EP="const day = n => new Date(Date.UTC(2020, 0, 3) + n * 864e5).toISOString().slice(0, 10);
const macro = c => { const m = []; for (let i = 0; i < c; i++) m.push([day(7 * i), 'Bearish', 'x']); m.push([day(7 * c), 'Bullish', 'x']); return m; };
const daily = (a, b, f) => { const r = []; for (let i = a; i <= b; i++) r.push([day(i), f(i), 0, 0]); return r; };
const flat = daily(0, 400, () => 1000), ramp = daily(0, 400, i => 1000 + i);
const ep = (m, nav, spy, tr) => reopenEpisodes(m, nav, spy, tr);"
  epi() { node -e "$FNS
$EP
console.log($1)"; }
  expect_eq "reopenEpisodes: 8 closed weeks make one episode, on the Bullish week" '["2020-02-28",8]' "$(epi 'JSON.stringify(ep(macro(8), flat, flat, []).map(e => [e.d, e.closed])[0])')"
  expect_eq "reopenEpisodes: 7 closed weeks make none" 0 "$(epi 'ep(macro(7), flat, flat, []).length')"
  expect_eq "reopenEpisodes: an entry on day 90 counts in both windows" '[1,1]' "$(epi 'JSON.stringify(ep(macro(8), flat, flat, [{ ed: day(56 + 90) }]).map(e => [e.e13, e.e26])[0])')"
  expect_eq "reopenEpisodes: an entry on day 91 counts only in the 26-week window" '[0,1]' "$(epi 'JSON.stringify(ep(macro(8), flat, flat, [{ ed: day(56 + 91) }]).map(e => [e.e13, e.e26])[0])')"
  expect_eq "reopenEpisodes: entries on day 182 and before the reopen count in neither" '[0,0]' "$(epi 'JSON.stringify(ep(macro(8), flat, flat, [{ ed: day(56 + 182) }, { ed: day(55) }]).map(e => [e.e13, e.e26])[0])')"
  expect_eq "reopenEpisodes: a 26-week window past the NAV data is dropped" 0 "$(epi 'ep(macro(8), daily(0, 237, () => 1000), flat, []).length')"
  expect_eq "reopenEpisodes: a window ending on the last NAV row is kept" 1 "$(epi 'ep(macro(8), daily(0, 238, () => 1000), flat, []).length')"
  expect_eq "reopenEpisodes: a reopen before the NAV data is dropped" 0 "$(epi 'ep(macro(8), daily(60, 400, () => 1000), flat, []).length')"
  expect_eq "reopenEpisodes: returns are last-row-on-or-before (NAV 1056 -> 1238 = +17.23 %)" "17.23" "$(epi 'ep(macro(8), ramp, flat, [])[0].ret.toFixed(2)')"
  expect_eq "reopenEpisodes: a missing reopen-day row reads the prior day, not the next" "0.00" "$(epi 'ep(macro(8), flat.filter(r => r[0] !== day(56)).map(r => r[0] === day(57) ? [r[0], 2000, 0, 0] : r), flat, [])[0].ret.toFixed(2)')"
  expect_eq "reopenEpisodes: flag is wired from reopenFlag (flat NAV vs SPY +17 %, no entries = sat out)" "sat out" "$(epi 'ep(macro(8), flat, ramp, [])[0].flag')"
  expect_eq "reopenEpisodes: the flag reads e13, not e26 (3 entries after week 13 keep it sat out)" "sat out" "$(epi 'ep(macro(8), flat, ramp, [{ ed: day(56 + 100) }, { ed: day(56 + 101) }, { ed: day(56 + 102) }])[0].flag')"
  expect_eq "reopenEpisodes: the closed-weeks counter resets (two Bullish weeks in a row = one reopen)" 1 "$(epi 'ep(macro(8).concat([[day(63), macro(1)[1][1], macro(1)[1][2]]]), flat, flat, []).length')"
  expect_eq "reopenEpisodes: an entry on the reopen day counts" '[1,1]' "$(epi 'JSON.stringify(ep(macro(8), flat, flat, [{ ed: day(56) }]).map(e => [e.e13, e.e26])[0])')"
else
  echo "SKIP: review_pack signal-predicate cases need node"
fi

# Short leg (#3111): params with (enable_short_side true) -> meta.short_leg, from trades.csv (fills, P&L)
# and trade_audit.sexp (tickets, Bearish weeks, weeks with short_top_n_admitted > 0). The fixture is shaped
# like shorts-liveness-2026-10-03 s0-shB: two short tickets, neither filled. A shorts-off run gets null.
SHRUN="$TMP/shrun"; mkdir -p "$SHRUN"
cp "$FIX"/run/* "$SHRUN"/; cp "$FIX"/shorts/params.sexp "$FIX"/shorts/trade_audit.sexp "$SHRUN"/
rc=0
sh "$SCRIPT" --no-container --data-dir "$FIX/data" --out "$TMP/shpack" r0="$FIX/run/" sh="$SHRUN/" >"$TMP/sh.log" 2>"$TMP/sh.err" || rc=$?
expect_eq "short leg: pack with a shorts run builds" 0 "$rc"
SL0="$TMP/shpack/site/data/sh_meta.json"
expect_eq "short leg: shorts-off run has no short leg" null "$(jq -c .short_leg "$TMP/shpack/site/data/r0_meta.json")"
expect_eq "short leg: 0-fill run (shB shape)" '{"fills":0,"pnl":0,"tickets":2,"bearish_weeks":2,"bearish_admitted":1}' "$(jq -c ".short_leg|.pnl+=0" "$SL0")"
rm "$SHRUN/trade_audit.sexp"
expect_eq "short leg: no trade audit -> audit counts null, never 0" '{"fills":0,"pnl":0,"tickets":null,"bearish_weeks":null,"bearish_admitted":null}' "$(sh "$ROOT/dev/lib/review_pack/meta.sh" "$SHRUN" | jq -c ".short_leg|.pnl+=0")"
sed 's/^AAA,LONG,/AAA,SHORT,/' "$FIX/run/trades.csv" > "$SHRUN/trades.csv"
expect_eq "short leg: a SHORT row counts as a fill with its P&L" '{"fills":1,"pnl":-3000}' "$(sh "$ROOT/dev/lib/review_pack/meta.sh" "$SHRUN" | jq -c '.short_leg|{fills,pnl:(.pnl+0)}')"
if command -v node >/dev/null 2>&1; then
  slp() { node -e "$FNS
console.log(shortLegLine($1))"; }
  expect_eq "shortLegLine: 0-fill line names tickets, fills, P&L, Bearish weeks and the top-N gate" \
    '<b>Short leg on:</b> 2 short tickets placed, 0 short entries filled, short realised P&amp;L $0. The macro read Bearish in 2 screening weeks; 1 of them admitted a short to the top-N (<code>short_top_n_admitted</code> &gt; 0).' \
    "$(slp "$(jq -c .short_leg "$SL0")")"
  expect_eq "shortLegLine: missing audit reads n/a, never 0" \
    '<b>Short leg on:</b> n/a short tickets placed, 0 short entries filled, short realised P&amp;L $0. The macro read Bearish in n/a screening weeks; n/a of them admitted a short to the top-N (<code>short_top_n_admitted</code> &gt; 0).' \
    "$(slp '{fills: 0, pnl: 0, tickets: null, bearish_weeks: null, bearish_admitted: null}')"
  expect_eq "shortLegLine: with fills, no gate clause" \
    '<b>Short leg on:</b> 3 short tickets placed, 1 short entries filled, short realised P&amp;L −$3,000.' \
    "$(slp '{fills: 1, pnl: -3000, tickets: 3, bearish_weeks: 5, bearish_admitted: 2}')"
  expect_eq "shortLegLine: shorts off prints nothing" "" "$(slp null)"
else
  echo "SKIP: review_pack short-leg predicate cases need node"
fi
expect_eq "EEE exits under 5 % of entry: X" X "$(q '.[]|select(.sym=="EEE")|.g')"
expect_eq "second run r1 emitted" 6 "$(jq length "$S/data/r1_trades.json")"
expect_eq "year table: one row" 2020 "$(jq -r '.[0].p' "$S/data/r0_years.json")"
expect_eq "quarter table: two rows" "2020Q1 2020Q2" "$(jq -r 'map(.p)|join(" ")' "$S/data/r0_quarters.json")"
expect_eq "validator check parsed" V13 "$(jq -r '.validator[1].id' "$S/data/r0_meta.json")"


# Open positions at the window end (#3125). A copy of the fixture run gains
# open_positions.csv and an actual.sexp holding their value marked at the last
# close, the way the simulator writes it:
#   AAA  100 sh from 2020-04-02 (a Bearish macro week), last close 120; in this
#        copy AAA's adjusted_close is 0.9 x close on every row (a dividend after
#        the window), so a mark on adjusted_close alone would read 10,800;
#   BBB 2000 sh (post-split count) from 2020-02-03, through its 2:1 split of
#        2020-03-11 (raw close 50 -> 26, adjusted 25 -> 26), last close 26.
# Together 12,000 + 52,000 = 64,000. The bar-store copy also drops 2020-04-10
# (Good Friday) from every symbol, so the equity curve's carried-forward row
# for it is a market holiday.
mkdir -p "$TMP/oe"
cp -R "$FIX/run" "$TMP/oe/run"; cp -R "$FIX/data" "$TMP/oe/data"
printf 'symbol,side,entry_date,entry_price,quantity\nAAA,LONG,2020-04-02,120.00,100\nBBB,LONG,2020-02-03,50.00,2000\n' > "$TMP/oe/run/open_positions.csv"
printf '((total_return_pct 1.0) (open_positions_value 64000.00))\n' > "$TMP/oe/run/actual.sexp"
for f in "$TMP"/oe/data/*/*/*/data.csv; do grep -v '^2020-04-10,' "$f" > "$f.x"; mv "$f.x" "$f"; done
AAA_CSV="$TMP/oe/data/A/A/AAA/data.csv"
awk -F, 'BEGIN { OFS = "," } NR > 1 { $6 = sprintf("%.4f", $5 * 0.9) } { print }' "$AAA_CSV" > "$AAA_CSV.x"; mv "$AAA_CSV.x" "$AAA_CSV"
rc=0
sh "$SCRIPT" --no-container --data-dir "$TMP/oe/data" --out "$TMP/oe/pack" r0="$TMP/oe/run/" >"$TMP/oe.log" 2>"$TMP/oe.err" || rc=$?
expect_eq "open-at-end: builds, exit 0" 0 "$rc"
OD="$TMP/oe/pack/site/data"
expect_eq "open-at-end: the open position is listed with its entry macro week" "AAA 2020-04-02 Bearish" "$(jq -r '.rows[]|select(.sym=="AAA")|"\(.sym) \(.ed) \(.mE)"' "$OD/r0_open.json")"
expect_eq "open-at-end: last-day check = qty x last close (not adjusted close), pack vs actual.sexp" "2020-05-20 64000 64000" "$(jq -r '.check|"\(.date) \(.pack+0) \(.actual+0)"' "$OD/r0_open.json")"
expect_eq "open-at-end: last day reads both open positions as invested (64,000 / 101,000 NAV)" "63.4 2" "$(jq -r '.[-1]|"\(.[2]) \(.[3])"' "$OD/r0_nav.json")"
expect_eq "open-at-end: no jump across a split inside the hold (BBB 50,000 -> 52,000 = adjusted 25 -> 26)" "2020-03-10:50000.00 2020-03-11:52000.00" \
  "$(awk -F'\t' '$3 == "open:BBB:2020-02-03" && ($1 == "2020-03-10" || $1 == "2020-03-11") { printf "%s%s:%s", (n++ ? " " : ""), $1, $2 }' "$TMP/oe/pack/runs/r0/x_expo.tsv")"
expect_eq "open-at-end: matching check -> no warning" "" "$(grep 'WARN' "$TMP/oe.err" || true)"
expect_eq "holiday: no 2020-04-10 row in the exposure series" 0 "$(jq '[.[]|select(.[0]=="2020-04-10")]|length' "$OD/r0_nav.json")"
expect_eq "holiday: the other 99 days are kept" 99 "$(jq length "$OD/r0_nav.json")"
expect_eq "holiday: the quarter's Invested is the mean over its trading days" yes \
  "$(jq -rn --slurpfile n "$OD/r0_nav.json" --slurpfile q "$OD/r0_quarters.json" '([$n[0][]|select(.[0]>="2020-04-01")|.[2]]|add/length) as $m | ($q[0][]|select(.p=="2020Q2")|.expo) as $e | if ($m-$e) < 0.05 and ($e-$m) < 0.05 then "yes" else "no: \($m) vs \($e)" end')"
# the detector fires when the pack misses a position: actual.sexp holds 20,000
printf '((open_positions_value 20000.00))\n' > "$TMP/oe/run/actual.sexp"
rc=0
sh "$SCRIPT" --no-container --data-dir "$TMP/oe/data" --out "$TMP/oe/miss" r0="$TMP/oe/run/" >"$TMP/miss.log" 2>"$TMP/miss.err" || rc=$?
expect_eq "open-at-end mismatch: still builds" 0 "$rc"
expect_eq "open-at-end mismatch: warns on stderr" 1 "$(grep -c 'WARN open positions on 2020-05-20: pack marks 64000, actual.sexp open_positions_value 20000' "$TMP/miss.err" || true)"
expect_eq "no actual.sexp: the check reads null, not 0" null "$(jq -r .check.actual "$S/data/r0_open.json")"
expect_eq "cap/cash-floor text removed" 0 "$(grep -c 'caps long exposure\|exposure cap and cash floor' "$S/index.html" || true)"
expect_eq "final NAV carried on the equity axis" yes "$(grep -q "title: 'final'" "$S/index.html" && echo yes || echo no)"
if command -v node >/dev/null 2>&1; then
  OFNS="$(sed -n -e '/^const FLAGS = \[/,/^\];/p' -e '/^function openHits(/,/^}/p' -e '/^function openCheckMiss(/,/^}/p' "$S/index.html")"
  oc() { node -e "$OFNS
const OPEN = $(jq -c .rows "$OD/r0_open.json"), F = id => FLAGS.find(f => f.id === id);
console.log($1)"; }
  expect_eq "openHits: the Bearish-week card counts the open AAA (BBB entered Bullish)" 1 "$(oc 'openHits(F("macrobear"), OPEN)')"
  expect_eq "openHits: the not-Bullish card counts it too" 1 "$(oc 'openHits(F("macro"), OPEN)')"
  expect_eq "openHits: an exit-time card never counts open positions" 0 "$(oc 'openHits(F("whipsaw"), OPEN)')"
  expect_eq "openCheckMiss: 12,000 vs 20,000 misses" true "$(oc 'openCheckMiss({pack: 12000, actual: 20000})')"
  expect_eq "openCheckMiss: equal values pass" false "$(oc 'openCheckMiss({pack: 12000, actual: 12000})')"
  expect_eq "openCheckMiss: within 1 % passes" false "$(oc 'openCheckMiss({pack: 12000, actual: 12100})')"
  expect_eq "openCheckMiss: no actual.sexp is not a miss" false "$(oc 'openCheckMiss({pack: 0, actual: null})')"
  expect_eq "openCheckMiss: nothing open but actual holds 5,000 misses" true "$(oc 'openCheckMiss({pack: 0, actual: 5000})')"
  expect_eq "weekend flag: a delisting exit with no bar is not the Saturday defect" false "$(oc 'F("weekend").test({ onE: 1, onX: 0, trig: "delisted" })')"
  expect_eq "weekend flag: a stop exit with no bar still is" true "$(oc 'F("weekend").test({ onE: 1, onX: 0, trig: "stop_loss" })')"
else
  echo "SKIP: review_pack open-position page cases need node"
fi
printf '%s: %d passed, %d failed\n' "review_pack_test" "$PASS" "$FAILED"
[ "$FAILED" = 0 ]
