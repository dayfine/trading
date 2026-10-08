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
#     is not counted as the Saturday-fill defect; a SHORT open at the end is
#     signed negative in that check and a name with no bar on the last day is
#     carried at its last close (#3144);
#   - every emitted JSON file parses (the SPY fixture carries a "321."-style
#     value the store really writes), manifest + year/quarter tables present;
#   - the page's signal predicates (openSignal, oneTradeYear, alsoCause) are
#     extracted with sed and evaluated with node over named cases (#3084);
#     skipped with a notice when node is not installed.
#   - short leg (#3111): a run whose params enable shorts gets meta.short_leg
#     (tickets, fills, short P&L, Bearish weeks, weeks with short_top_n_admitted
#     > 0) over a fixture shaped like shorts-liveness s0-shB; audit counts are
#     null without trade_audit.sexp; shorts off -> null; shortLegLine pinned.
#   - #3177: the render's slice plan covers any measured page height and a
#     page that failed to load stops the render (stub Chrome); the return
#     basis (price / total return / mixed) from params picks the SPY column
#     and labels; the fallback card keys on the audit stop kind; an AVD-shaped
#     later-split fill near a wide bar's edge is code 2, not off-bar;
#   - short trades (#3149): every trade statistic and flag side-aware over
#     three SHORT rows (breach on the high, signed P&L / MFE / grades, the
#     audit stop_floor_kind for the fallback card, installed-stop width,
#     margin_call as forced, macro / stage / slippage flags per side, the
#     short book's gate reopening on Bearish); salts vs arms in the manifest;
#     gap-through hard-stop fills (short at the open above, long at the open
#     below), a short entered far below its prior close, and the Stage 2
#     weeks of a short through stage_sum.sh (QC rework on #3192).
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
# #3144: a SHORT still open at the end is marked negative in the last-day check (the simulator's
# open_positions_value is NAV minus equity cash), and a position with no bar on the last equity date
# is carried at its last known close. Copy of the open-at-end case plus CCC 100 sh SHORT (last close
# 80 -> -8,000), with BBB's last bar (2020-05-20) dropped and its 2020-05-19 close set to 25
# (2,000 x 25 = 50,000): 12,000 + 50,000 - 8,000 = 54,000.
cp -R "$TMP/oe" "$TMP/oe2"; rm -rf "$TMP/oe2/pack" "$TMP/oe2/miss"
printf 'CCC,SHORT,2020-04-01,80.00,100\n' >> "$TMP/oe2/run/open_positions.csv"
printf '((total_return_pct 1.0) (open_positions_value 54000.00))\n' > "$TMP/oe2/run/actual.sexp"
BBB_CSV="$TMP/oe2/data/B/B/BBB/data.csv"
grep -v '^2020-05-20,' "$BBB_CSV" | sed 's/^2020-05-19,26.00,26.50,25.50,26.00,26.00,/2020-05-19,25.00,25.50,24.50,25.00,25.00,/' > "$BBB_CSV.x"; mv "$BBB_CSV.x" "$BBB_CSV"
rc=0
sh "$SCRIPT" --no-container --data-dir "$TMP/oe2/data" --out "$TMP/oe2/pack" r0="$TMP/oe2/run/" >"$TMP/oe2.log" 2>"$TMP/oe2.err" || rc=$?
expect_eq "open short + no last bar: builds, exit 0" 0 "$rc"
expect_eq "open short + no last bar: pack 54,000 = actual (short signed, BBB carried at 25)" "54000 54000" "$(jq -r '.check|"\(.pack+0) \(.actual+0)"' "$TMP/oe2/pack/site/data/r0_open.json")"
expect_eq "open short + no last bar: no warning" "" "$(grep 'WARN' "$TMP/oe2.err" || true)"
expect_eq "open short: the open row carries its side" SHORT "$(jq -r '.rows[]|select(.sym=="CCC")|.side' "$TMP/oe2/pack/site/data/r0_open.json")"
expect_eq "no last bar: BBB's carried row on 2020-05-20 = 2,000 x 25" "50000.00" "$(awk -F'\t' '$3 == "open:BBB:2020-02-03" && $1 == "2020-05-20" { print $2 }' "$TMP/oe2/pack/runs/r0/x_expo.tsv")"
expect_eq "open short: exposure stays gross, the last day reads 12,000 + 50,000 + 8,000 = 70,000 of a 101,000 NAV over 3 positions" "69.3 3" "$(jq -r '.[-1]|"\(.[2]) \(.[3])"' "$TMP/oe2/pack/site/data/r0_nav.json")"
expect_eq "no actual.sexp: the check reads null, not 0" null "$(jq -r .check.actual "$S/data/r0_open.json")"
expect_eq "cap/cash-floor text removed" 0 "$(grep -c 'caps long exposure\|exposure cap and cash floor' "$S/index.html" || true)"
expect_eq "final NAV carried on the equity axis" yes "$(grep -q "title: 'final'" "$S/index.html" && echo yes || echo no)"
if command -v node >/dev/null 2>&1; then
  OFNS="$(sed -n -e '/^\/\/ Side-aware trade helpers/,/^const ownStage/p' -e '/^const FLAGS = \[/,/^\];/p' -e '/^function openHits(/,/^}/p' -e '/^function openCheckMiss(/,/^}/p' "$S/index.html")"
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
# Short trades read side-aware (#3149). A run of three SHORT rows over the long fixtures' bars:
#   AAA short 100 -> covered 110 (stop_loss): the HIGH first reaches the 105 entry_stop on the exit bar
#       (lag 0; the long reading had the low under 105 on day 1); filled 4.8 % above the stop (gapstop);
#       MFE +3 % (the 97 close); the stock then holds 110-120, against the short -> B; 8-week pick -20 %;
#       the trade audit says Buffer_fallback -> the fallback card counts it (sid 0.50 is not 4 %);
#   DDD short 40 -> 38 (margin_call): +5 %, installed stop 48 = 20 % above the fill -> widestop
#       (its sid 0.04 would have read as the long 4 % fallback); the stock then runs to 60 -> A;
#   EEE short 10 -> covered 10.20 (stop_loss, -2 %), then the stock falls 97 % -> F (a short whipsaw);
#       its 10.50 stop is never reached by a high -> lag -1.
# All three enter in a Bullish macro week -> 'Entered against the macro'.
SW="$TMP/short"; mkdir -p "$SW/run"; cp "$FIX"/run/* "$SW/run/"
cat > "$SW/run/trades.csv" <<'CSV'
symbol,side,entry_date,exit_date,days_held,entry_price,exit_price,quantity,pnl_dollars,pnl_percent,entry_stop,exit_stop,exit_trigger,entry_stage,entry_volume_ratio,stop_initial_distance_pct,stop_trigger_kind,days_to_first_stop_trigger,screener_score_at_entry,position_id,stop_fill_distance_pct,max_stop,n_stop_raises
AAA,SHORT,2020-01-29,2020-02-07,9,100.00,110.00,1000,-10000.00,-10.00,105.00,105.00,stop_loss,Stage4,1.5000,0.5000,gap_down,9,100,AAA-wein-s1,0.0476,105.00,0
DDD,SHORT,2020-01-15,2020-01-22,7,40.00,38.00,500,1000.00,5.00,48.00,48.00,margin_call,Stage4,1.2000,0.0400,non_stop_exit,,100,DDD-wein-s2,,,0
EEE,SHORT,2020-01-29,2020-02-07,9,10.00,10.20,1000,-200.00,-2.00,10.50,10.50,stop_loss,Stage4,2.5000,0.0400,intraday,9,100,EEE-wein-s3,,10.50,0
CSV
cat > "$SW/run/trade_audit.sexp" <<'SEXP'
((audit_records
  (((entry
     ((symbol AAA) (entry_date 2020-01-29) (position_id AAA-wein-s1)
      (side Short) (suggested_entry 101) (installed_stop 105)
      (stop_floor_kind Buffer_fallback) (split_safe_basis Flag_off))))
   ((entry
     ((symbol EEE) (entry_date 2020-01-29) (position_id EEE-wein-s3)
      (side Short) (suggested_entry 10) (installed_stop 10.5)
      (stop_floor_kind Support_floor) (split_safe_basis Flag_off)))))))
SEXP
rc=0
sh "$SCRIPT" --no-container --data-dir "$FIX/data" --out "$SW/pack" null-s0="$SW/run/" null-s1="$SW/run/" >"$SW/log" 2>"$SW/err" || rc=$?
expect_eq "short: builds, exit 0" 0 "$rc"
ST="$SW/pack/site/data/null-s0_trades.json"
sq() { jq -r "$1" "$ST"; }
expect_eq "short AAA: P&L % side-signed, grade B (the stock held above the cover)" "-10 B" "$(sq '.[]|select(.sym=="AAA")|"\(.pct) \(.g)"')"
expect_eq "short AAA: breach = high reaches the stop above, on the exit bar (lag 0)" 0 "$(sq '.[]|select(.sym=="AAA")|.blag')"
expect_eq "short AAA: MFE / MAE / 8-week pick side-signed" "3 -10 -20" "$(sq '.[]|select(.sym=="AAA")|"\(.mfe+0) \(.mae+0) \(.f40+0)"')"
expect_eq "short AAA: no hard stop above the entry trades before the exit" "-10,-10,-10,-10,-10,-10" "$(sq '.[]|select(.sym=="AAA")|.cf|map(.+0|tostring)|join(",")')"
expect_eq "short AAA: stop_floor_kind joined from the trade audit" Buffer_fallback "$(sq '.[]|select(.sym=="AAA")|.sfk')"
expect_eq "short DDD: +5 %, installed stop 20 % above the fill, grade A" "5 0.2 A" "$(sq '.[]|select(.sym=="DDD")|"\(.pct) \(.isd+0) \(.g)"')"
expect_eq "short EEE: covered, then the stock fell 97 % -> F; stop never reached -> lag -1" "F 97 -1" "$(sq '.[]|select(.sym=="EEE")|"\(.g) \(.pmax+0) \(.blag)"')"
expect_eq "short EEE: an exit far below entry is not X for a short" F "$(sq '.[]|select(.sym=="EEE")|.g')"
expect_eq "short: the macro week reaches the trades without the container (mE joined)" Bullish "$(sq '.[0].mE')"
expect_eq "run kind: null-s0 / null-s1 read as salts" salt "$(jq -r .run_kind "$SW/pack/site/data/manifest.json")"
expect_eq "run kind: r0 / r1 read as arms" arm "$(jq -r .run_kind "$S/data/manifest.json")"
rc=0
sh "$SCRIPT" --no-container --data-dir "$FIX/data" --out "$SW/arms" null-s0="$SW/run/" map-s0="$SW/run/" >"$SW/arms.log" 2>&1 || rc=$?
expect_eq "run kind: null-s0 / map-s0 read as arms" arm "$(jq -r .run_kind "$SW/arms/site/data/manifest.json")"
rc=0
sh "$SCRIPT" --no-container --data-dir "$FIX/data" --out "$SW/forced" --run-kind salt a="$SW/run/" b="$SW/run/" >"$SW/forced.log" 2>&1 || rc=$?
expect_eq "run kind: --run-kind salt overrides auto" salt "$(jq -r .run_kind "$SW/forced/site/data/manifest.json")"
if command -v node >/dev/null 2>&1; then
  SFNS="$(sed -n -e '/^\/\/ Side-aware trade helpers/,/^const ownStage/p' -e '/^const FLAGS = \[/,/^\];/p' -e '/^const REOPEN_CLOSED_WEEKS/p' -e '/^function reopenFlag(/,/^}/p' -e '/^function reopenEpisodes(/,/^}/p' "$SW/pack/site/index.html")"
  fl() { node -e "$SFNS
const T = $(jq -c . "$ST");
const ids = s => FLAGS.filter(f => f.test(T.find(t => t.sym === s))).map(f => f.id).join(' ');
console.log($1)"; }
  expect_eq "short AAA flags: gapstop, against the macro, fallback (from the audit)" "gapstop macro macrobear fallback" "$(fl 'ids("AAA")')"
  expect_eq "short DDD flags: margin call is forced; 20 % stop is wide; no long-only volume or 4 % flags" "forced macro macrobear widestop" "$(fl 'ids("DDD")')"
  expect_eq "short EEE flags: whipsaw (the stock fell after the cover)" "macro macrobear whipsaw" "$(fl 'ids("EEE")')"
  expect_eq "macro flag: a short in a Bearish week is with the macro" "false false" "$(fl '["macro", "macrobear"].map(i => FLAGS.find(x => x.id === i).test({ side: "SHORT", mE: "Bearish" })).join(" ")')"
  expect_eq "macro flag: a long in a Bearish week is against it" "true true" "$(fl '["macro", "macrobear"].map(i => FLAGS.find(x => x.id === i).test({ side: "LONG", mE: "Bearish" })).join(" ")')"
  expect_eq "stage flags: a short held 2 Stage 2 weeks, entered on a Stage 4 replay" "true false" "$(fl '["stage4", "notS2"].map(i => FLAGS.find(x => x.id === i).test({ side: "SHORT", s2w: 2, s4w: 9, rsE: "Stage4" })).join(" ")')"
  expect_eq "slipcap: a short filled 2 % under its trigger paid the allowance" "true false" "$(fl '[-2, 2].map(v => FLAGS.find(x => x.id === "slipcap").test({ side: "SHORT", fvt: v })).join(" ")')"
  # reopenEpisodes, dir -1: 8 non-Bearish weeks then a Bearish week reopen a short book's gate; SPY is inverted
  rep() { node -e "$SFNS
const day = n => new Date(Date.UTC(2020, 0, 3) + n * 864e5).toISOString().slice(0, 10);
const m = []; for (let i = 0; i < 8; i++) m.push([day(7 * i), 'Bullish', 'x']); m.push([day(56), 'Bearish', 'x']);
const flat = [], fall = []; for (let i = 0; i <= 400; i++) { flat.push([day(i), 1000, 0, 0]); fall.push([day(i), 1400 - i, 0, 0]); }
console.log($1)"; }
  expect_eq "reopenEpisodes dir -1: the gate reopens on Bearish" '["2020-02-28",8]' "$(rep 'JSON.stringify(reopenEpisodes(m, flat, fall, [], -1).map(e => [e.d, e.closed])[0])')"
  expect_eq "reopenEpisodes dir -1: a falling SPY reads as a rise for the short book -> sat out" "sat out" "$(rep 'reopenEpisodes(m, flat, fall, [], -1)[0].flag')"
  expect_eq "reopenEpisodes dir 1: the same macro has no Bullish reopen" 0 "$(rep 'reopenEpisodes(m, flat, fall, []).length')"
else
  echo "SKIP: review_pack short-side page cases need node"
fi
# Rework (QC CP4 on #3192): gap-through hard-stop fills, the entry-vs-prior-close sign and the Stage 2
# weeks of a short, each pinned. A second short run "g":
#   AAA short 100 -> 110 (2020-02-10): the 2020-02-07 bar OPENS at 110, above the 3/5/6/8/10 % levels
#       (103..110), so each fills at the open (-10 %), not at its level; 15 % (115) is never reached;
#   EEE short at 0.30 on 2020-02-13 after a 10.00 close: entered 97 % below the prior close -> gap +97,
#       chase fires (unsigned it would read -97 and stay quiet);
#   DDD long 40 -> 39 (2020-01-24): the 2020-01-22 bar opens 38 under the 3 % level (38.80) -> -5 %, not
#       -3 %; 6 % (37.60) is inside the bar -> -6 %; 8 % (36.80) is never reached -> the actual -2.5 %.
# A stage replay sidecar for the AAA short (Stage 4 into the entry, two Stage 2 weeks in the hold) is put
# where the container step writes it and the pack rebuilt: stage_sum.sh's Stage 2 count reaches s2w.
GW="$TMP/gap"; mkdir -p "$GW/run"; cp "$FIX"/run/* "$GW/run/"
{ head -1 "$FIX/run/trades.csv"
  echo "AAA,SHORT,2020-01-29,2020-02-10,12,100.00,110.00,1000,-10000.00,-10.00,120.00,120.00,laggard_rotation,Stage4,1.5000,0.2000,non_stop_exit,,100,AAA-wein-g1,,,0"
  echo "EEE,SHORT,2020-02-13,2020-02-20,7,0.30,0.30,1000,0.00,0.00,0.40,0.40,laggard_rotation,Stage4,1.5000,0.3300,non_stop_exit,,100,EEE-wein-g2,,,0"
  echo "DDD,LONG,2020-01-15,2020-01-24,9,40.00,39.00,500,-500.00,-2.50,30.00,30.00,laggard_rotation,Stage2,2.5000,0.2500,non_stop_exit,,100,DDD-wein-g3,,,0"; } > "$GW/run/trades.csv"
rc=0
sh "$SCRIPT" --no-container --data-dir "$FIX/data" --out "$GW/pack" g="$GW/run/" >"$GW/log" 2>&1 || rc=$?
expect_eq "gap run: builds, exit 0" 0 "$rc"
mkdir -p "$GW/pack/runs/g/stage"
printf 'week,date,close,ma,stage,weeks_in_stage,late\n1,2020-01-24,100,101,Stage4,3,0\n2,2020-01-31,100,100,Stage2,1,0\n3,2020-02-07,110,100,Stage2,2,0\n' > "$GW/pack/runs/g/stage/AAA-wein-g1.png.csv"
rc=0
sh "$SCRIPT" --no-container --data-dir "$FIX/data" --out "$GW/pack" g="$GW/run/" >"$GW/log2" 2>&1 || rc=$?
expect_eq "gap run: rebuilds over the stage sidecar, exit 0" 0 "$rc"
GT="$GW/pack/site/data/g_trades.json"
expect_eq "short gap-through: each hard stop the 2020-02-07 open jumps fills at that open" "-10,-10,-10,-10,-10,-10" "$(jq -r '.[]|select(.id=="AAA-wein-g1")|.cf|map(.+0|tostring)|join(",")' "$GT")"
expect_eq "long gap-through: 3 % fills at the 38 open (-5), 6 % at its level, 8 % never reached" "-5,-5,-6,-2.5,-2.5,-2.5" "$(jq -r '.[]|select(.id=="DDD-wein-g3")|.cf|map(.+0|tostring)|join(",")' "$GT")"
expect_eq "short entry vs prior close: 97 % below reads +97 (the trade's favour)" 97 "$(jq -r '.[]|select(.id=="EEE-wein-g2")|.gap+0' "$GT")"
expect_eq "short Stage 2 weeks: stage_sum.sh -> s2w 2, replay entry stage Stage4" "2 0 Stage4" "$(jq -r '.[]|select(.id=="AAA-wein-g1")|"\(.s2w) \(.s4w) \(.rsE)"' "$GT")"
if command -v node >/dev/null 2>&1; then
  gfl() { node -e "$SFNS
const T = $(jq -c . "$GT");
const ids = id => FLAGS.filter(f => f.test(T.find(t => t.id === id))).map(f => f.id).join(' ');
console.log($1)"; }
  expect_eq "short EEE gap: chase fires" yes "$(gfl 'ids("EEE-wein-g2").split(" ").includes("chase") ? "yes" : "no"')"
  expect_eq "short AAA replay: held 2 Stage 2 weeks -> stage4 fires; entered on Stage 4 -> notS2 quiet" "true false" "$(gfl '["stage4", "notS2"].map(i => ids("AAA-wein-g1").split(" ").includes(i)).join(" ")')"
fi
# #3177. Render: the slice plan covers a page of any measured height (every pixel row lands in some
# part; the last part is the bottom 1500 px), and a page that failed to load its data stops the render
# instead of slicing an error banner. A stub Chrome stands in for the browser.
RENDER="${ROOT}/dev/scripts/review_pack_render.sh"
expect_eq "render plan: 20,000 px page -> 14 parts, the last ending one row above the bottom" "14 18499 1500" "$(sh "$RENDER" --plan 20000 | tail -1)"
expect_eq "render plan: parts start at 1 and step 1500" "1 1 1500|2 1500 1500" "$(sh "$RENDER" --plan 20000 | head -2 | paste -sd'|' -)"
expect_eq "render plan: a page under two slices is one whole part" "1 0 1400" "$(sh "$RENDER" --plan 1400)"
expect_eq "render plan: covers every row (max y + height >= height - 1)" yes "$(sh "$RENDER" --plan 9051 | awk '{ e = $2 + $3; if (e > m) m = e } END { print (m >= 9050 ? "yes" : "no: " m) }')"
STUB="$TMP/stub-chrome"
printf '#!/bin/sh\nfor a in "$@"; do case "$a" in --dump-dom) echo "<html data-page-h=\\"5000\\"><div class=\\"empty\\">Could not load the data files (LightweightCharts is not defined).</div></html>"; exit 0 ;; esac; done\nexit 0\n' > "$STUB"; chmod +x "$STUB"
rc=0; CHROME="$STUB" sh "$RENDER" --site "$S" --out "$TMP/render" >"$TMP/render.log" 2>&1 || rc=$?
expect_eq "render: a page that failed to load stops with exit 1" 1 "$rc"
expect_eq "render: and names the page's own error" 1 "$(grep -c 'the page failed to load: Could not load the data files (LightweightCharts is not defined)' "$TMP/render.log" || true)"

# SPY basis: the fixture run arms neither cash_yield nor dividend_crediting -> price only; a copy that
# arms both -> total return. The fixture SPY's adjusted_close is 0.9 x close before 2020-03-01 here, so
# the two bases differ: price 301 -> 400 = +32.89 %, total return 270.9 -> 400 = +47.66 %.
mkdir -p "$TMP/tr"; cp -R "$FIX/data" "$TMP/tr/data"; cp -R "$FIX/run" "$TMP/tr/run"
SPY_CSV="$TMP/tr/data/S/Y/SPY/data.csv"
awk -F, 'BEGIN { OFS = "," } NR > 1 && $1 < "2020-03-01" { $6 = sprintf("%.2f", $5 * 0.9) } { print }' "$SPY_CSV" > "$SPY_CSV.x"; mv "$SPY_CSV.x" "$SPY_CSV"
sed 's/(overrides (((enable_short_side false))))/(overrides (((enable_short_side false)) ((cash_yield (Series macro\/tbill_3m_dtb3.csv))) ((dividend_crediting true))))/' "$FIX/run/params.sexp" > "$TMP/tr/run/params.sexp"
mkdir -p "$TMP/tr/mix"; cp "$FIX"/run/* "$TMP/tr/mix/"
sed 's/(overrides (((enable_short_side false))))/(overrides (((enable_short_side false)) ((dividend_crediting true))))/' "$FIX/run/params.sexp" > "$TMP/tr/mix/params.sexp"
rc=0
sh "$SCRIPT" --no-container --data-dir "$TMP/tr/data" --out "$TMP/tr/pack" px="$FIX/run/" tr="$TMP/tr/run/" mix="$TMP/tr/mix/" >"$TMP/tr.log" 2>&1 || rc=$?
expect_eq "basis: builds, exit 0" 0 "$rc"
TD="$TMP/tr/pack/site/data"
expect_eq "basis: price-only run (both flags off, the default)" '{"spy":"price","cash_yield":false,"dividends":false}' "$(jq -c .basis "$TD/px_meta.json")"
expect_eq "basis: total-return run (both armed)" '{"spy":"tr","cash_yield":true,"dividends":true}' "$(jq -c .basis "$TD/tr_meta.json")"
expect_eq "basis: dividends only is mixed" '{"spy":"mixed","cash_yield":false,"dividends":true}' "$(jq -c .basis "$TD/mix_meta.json")"
expect_eq "basis: the price-only run's year table reads SPY price (+32.89 %)" 32.89 "$(jq -r '.[0].spy' "$TD/px_years.json")"
expect_eq "basis: the total-return run's year table reads SPY TR (+47.66 %)" 47.66 "$(jq -r '.[0].spy' "$TD/tr_years.json")"
expect_eq "basis: both SPY series are published" "301 270.9" "$(jq -r '.[0][1]+0' "$TD/spy_price.json") $(jq -r '.[0][1]+0' "$TD/spy.json")"
if command -v node >/dev/null 2>&1; then
  BFNS="$(sed -n -e '/^function spyBasis(/,/^}/p' -e '/^function spyBasisLabel(/,/^}/p' -e '/^function sharpeBasis(/,/^}/p' "$S/index.html")"
  bas() { node -e "$BFNS
console.log($1)"; }
  expect_eq "spyBasisLabel: price" "SPY price only" "$(bas 'spyBasisLabel({ spy: "price", cash_yield: false, dividends: false })')"
  expect_eq "spyBasisLabel: total return" "SPY total return" "$(bas 'spyBasisLabel({ spy: "tr", cash_yield: true, dividends: true })')"
  expect_eq "spyBasisLabel: mixed names what the run credits" "SPY total return (run credits dividends only)" "$(bas 'spyBasisLabel({ spy: "mixed", cash_yield: false, dividends: true })')"
  expect_eq "spyBasis: an older meta without basis reads total return" tr "$(bas 'spyBasis(undefined)')"
  expect_eq "sharpeBasis: cash yield armed = excess over net T-bill" "excess over net T-bill" "$(bas 'sharpeBasis({ cash_yield: true })')"
  expect_eq "sharpeBasis: no cash yield = raw" "raw, no cash yield" "$(bas 'sharpeBasis({ cash_yield: false })')"
  FB="$(sed -n -e '/^\/\/ Side-aware trade helpers/,/^const ownStage/p' -e '/^const FLAGS = \[/,/^\];/p' "$S/index.html")"
  fbk() { node -e "$FB
const F = FLAGS.find(f => f.id === 'fallback');
console.log($1)"; }
  expect_eq "fallback: keyed on the audit's stop kind, not a 4 % distance (GBX: Support_floor at exactly 4 %)" "false true false" "$(fbk '[{ sid: 0.04, sfk: "Support_floor" }, { sid: 0.07, sfk: "Buffer_fallback" }, { sid: 0.04 }].map(F.test).join(" ")')"
  expect_eq "fallback: needs the audit (n/a without it)" sfk "$(fbk 'F.needs')"
else
  echo "SKIP: review_pack basis page cases need node"
fi
# AVD shape (2005-03-21, a 2:1 split on 2005-04-18): an entry filled on the post-split basis near the
# edge of a wide pre-split bar. FFF: raw bars 36-48 (mid 42) adjusted at 0.5 until a 2:1 split on
# 2020-03-02; filled at 23.50 = 47 / 2 (vs the mid: 0.56, outside the 2 % midpoint test) -> code 2.
# GGG: the same bars without the split (factor 1) -> genuinely off the bar, code 0.
mkdir -p "$TMP/avd/data/F/F/FFF" "$TMP/avd/data/G/G/GGG" "$TMP/avd/data/S/Y"; cp -R "$FIX/data/S/Y/SPY" "$TMP/avd/data/S/Y/"
awk -F, -v fac=0.5 'NR == 1 { print; next } { if ($1 < "2020-03-02") printf "%s,40.00,48.00,36.00,40.00,%.2f,100000,\n", $1, 40 * fac; else printf "%s,20.00,24.00,18.00,20.00,20.00,100000,\n", $1 }' "$FIX/data/A/A/AAA/data.csv" > "$TMP/avd/data/F/F/FFF/data.csv"
awk -F, 'NR == 1 { print; next } { printf "%s,40.00,48.00,36.00,40.00,40.00,100000,\n", $1 }' "$FIX/data/A/A/AAA/data.csv" > "$TMP/avd/data/G/G/GGG/data.csv"
mkdir -p "$TMP/avd/run"; cp "$FIX"/run/* "$TMP/avd/run/"
{ head -1 "$FIX/run/trades.csv"
  echo "FFF,LONG,2020-01-29,2020-04-01,63,23.50,20.00,1000,-3500.00,-14.89,,,laggard_rotation,Stage2,2.5000,0.0800,non_stop_exit,,100,FFF-wein-1,,,0"
  echo "GGG,LONG,2020-01-29,2020-04-01,63,23.50,40.00,1000,16500.00,70.21,,,laggard_rotation,Stage2,2.5000,0.0800,non_stop_exit,,100,GGG-wein-2,,,0"; } > "$TMP/avd/run/trades.csv"
rc=0
sh "$SCRIPT" --no-container --data-dir "$TMP/avd/data" --out "$TMP/avd/pack" r0="$TMP/avd/run/" >"$TMP/avd.log" 2>&1 || rc=$?
expect_eq "AVD shape: builds, exit 0" 0 "$rc"
expect_eq "AVD shape: a later split's fill near a wide bar's edge is code 2, not off-bar" 2 "$(jq -r '.[]|select(.sym=="FFF")|.inE' "$TMP/avd/pack/site/data/r0_trades.json")"
expect_eq "AVD shape: without a split behind the factor it stays off-bar (code 0)" 0 "$(jq -r '.[]|select(.sym=="GGG")|.inE' "$TMP/avd/pack/site/data/r0_trades.json")"
printf '%s: %d passed, %d failed\n' "review_pack_test" "$PASS" "$FAILED"
[ "$FAILED" = 0 ]
