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
#     basis (price / total return / mixed; cash_yield from the overrides or
#     the default of the run's code_version) picks the SPY column
#     and labels; the fallback card keys on the audit stop kind; an AVD-shaped
#     later-split fill near a wide bar's edge is code 2, not off-bar;
#   - #3214: per-trade flag cards: a zero card is hidden and named in an all-clear line (an n/a check stays drawn),
#     cards sort by named-threshold severity then |net $|, and one-trade / salt-year bullets leave the lead list;
#   - #3141: the fill-week volume ratio (per bar vs the 4 prior weeks) drives
#     the low-volume card, not the screen week; an exit dated after the last
#     bar is not the Saturday-fill defect; the Stage-4 card needs the replay;
#   - #3140 part 3: the P&L anatomy functions (Hill alpha, per-cohort row,
#     run shape and hindsight counts);
#   - short trades (#3149): every trade statistic and flag side-aware over
#     three SHORT rows (breach on the high, signed P&L / MFE / grades, the
#     audit stop_floor_kind for the fallback card, installed-stop width,
#     margin_call as forced, macro / stage / slippage flags per side, the
#     short book's gate reopening on Bearish); salts vs arms in the manifest;
#     gap-through hard-stop fills (short at the open above, long at the open
#     below), a short entered far below its prior close, and the Stage 2
#     weeks of a short through stage_sum.sh (QC rework on #3192).
#   - #3194: the regime warm-up (spy_warmup.json, the SPY bars before the
#     window; the first window day gets a regime), the open-position read net
#     of dividends, cash interest and commissions (or UnrealizedPnl), the
#     sub-$17 margin-call churn card and the NAV-peak give-back card.
#   - #3262: the macro join reads the screen strictly before the fill (V23's rule, a Friday-fill
#     fixture); the against-macro card words placement vs fill; an exit after an issuer's last bar
#     whose next bar is over a year on (a reused ticker) is not the non-trading-day defect; the
#     header stamps the pack SHA and snapshot dir; carried from #3214: CROOT from the mount source,
#     the SPY-truncation abort, a later split under a further split (AVD), side-signed pick vs SPY
#     and both-sides wording, the replay stage cards' wording.
#   - #3262 leftovers: the stop breach on raw bars, split-corrected (a dividend payer, both sides, and a
#     2:1 split mid-hold); a short-only book's eras read against SPY inverted, with short-side wording;
#     dividends from the run when trades.csv has no dividends_received column; the plurals; a Friday
#     exit; pack_sha's -dirty; conformance stacked above the validator; the capture unscrolls tables.
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

# dividends_received (#3175): the trailing trades.csv column reaches the trade JSON; AAA carries one.
expect_eq "AAA dividends_received reaches the trade JSON" 450 "$(q '.[]|select(.sym=="AAA")|.div')"
expect_eq "BBB (no dividend) reads 0, not null" 0 "$(q '.[]|select(.sym=="BBB")|.div')"
expect_eq "page shows a total-return P&L column and fact" yes "$(grep -q "'TR P&L \$'" "$S/index.html" && grep -q "'Total-return P&L'" "$S/index.html" && echo yes || echo no)"

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
  FNS="$(sed -n -e '/^const REOPEN_CLOSED_WEEKS/p' -e '/^function openSignal(/,/^}/p' -e '/^function oneTradeYear(/,/^}/p' -e '/^function alsoCause(/,/^}/p' -e '/^function reopenFlag(/,/^}/p' -e '/^function reopenEpisodes(/,/^}/p' -e '/^function shortLegLine(/,/^}/p' -e '/^function tradeTR(/p' -e '/^function realisedTotalNote(/,/^}/p' "$S/index.html")"
  expect_eq "signal predicates extracted" 8 "$(printf '%s\n' "$FNS" | grep -c '^function ')"
  sig() { node -e "const usdk = v => '\$' + v;
$FNS
console.log($1)"; }
  expect_eq "openSignal: opposite-sign specimen (T1 5r s0: NAV0 1M, move +115k, realised -222k) fires" true "$(sig 'openSignal(1e6, 115e3, -222e3)')"
  expect_eq "openSignal: open 200k of a 300k move (above half) fires" true "$(sig 'openSignal(1e6, 300e3, 100e3)')"
  expect_eq "openSignal: open 120k of a 300k move (below half, same sign) is quiet" false "$(sig 'openSignal(1e6, 300e3, 180e3)')"
  expect_eq "openSignal: open 80k < 10 % of NAV0 is quiet even at opposite sign" false "$(sig 'openSignal(1e6, 50e3, -30e3)')"
  expect_eq "openSignal: negative move, open -250k of -300k fires" true "$(sig 'openSignal(1e6, -300e3, -50e3)')"
  expect_eq "tradeTR: price-only pnl plus dividends; a missing div reads as 0" "-2550 -3000" "$(sig 'tradeTR({pnl:-3000,div:450}) + " " + tradeTR({pnl:-3000})')"
  expect_eq "realisedTotalNote: dividends and interest named separately (#3175)" yes "$(sig 'realisedTotalNote(1310000, 910000)' | grep -q 'of dividends.*and .*of cash interest' && echo yes || echo no)"
  expect_eq "realisedTotalNote: price-only run adds nothing" "" "$(sig 'realisedTotalNote(0, undefined)')"
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

# At-fill cash rejections (#3138): each ticket_lifecycle (cash_rejection ((required R) (available A))) in
# trade_audit.sexp is counted, with how many were >= 90 % funded. The fixture is save_hum-shaped, the pair
# split across lines. No trade audit -> null; an audit with no rejection -> count 0 (no line).
CRRUN="$TMP/crrun"; mkdir -p "$CRRUN"; cp "$FIX"/run/* "$CRRUN"/
printf '%s\n' '((audit_records' '  (((entry ((ticket_lifecycle ((cash_rejection' '     ((required 446712.52)' '      (available 427489.55)))))))))' \
  '   ((entry ((ticket_lifecycle ((cash_rejection ((required 1000.) (available 400.)))))))))))' > "$CRRUN/trade_audit.sexp"
expect_eq "cash rejections: two counted, one >= 90 % funded" '{"count":2,"near":1}' "$(sh "$ROOT/dev/lib/review_pack/meta.sh" "$CRRUN" | jq -c .cash_rejections)"
printf '%s\n' '((audit_records ()))' > "$CRRUN/trade_audit.sexp"
expect_eq "cash rejections: audit with none -> 0" '{"count":0,"near":0}' "$(sh "$ROOT/dev/lib/review_pack/meta.sh" "$CRRUN" | jq -c .cash_rejections)"
rm "$CRRUN/trade_audit.sexp"
expect_eq "cash rejections: no trade audit -> null, never 0" null "$(sh "$ROOT/dev/lib/review_pack/meta.sh" "$CRRUN" | jq -c .cash_rejections)"
if command -v node >/dev/null 2>&1; then
  CRF="$(sed -n -e '/^function cashRejectionLine(/,/^}/p' "$S/index.html")"
  crl() { node -e "$CRF
console.log(cashRejectionLine($1))"; }
  expect_eq "cashRejectionLine: count and near" \
    '<b>Entries cancelled at the fill for cash:</b> 2 tickets filled at the engine but the book could not fund them; 1 was at least 90 % funded (<code>cash_rejection</code> in <code>trade_audit.sexp</code>).' \
    "$(crl '{count: 2, near: 1}')"
  expect_eq "cashRejectionLine: none or no audit prints nothing" "|" "$(crl '{count: 0, near: 0}')|$(crl null)"
  expect_eq "cash-rejection line wired into What stands out" yes "$(grep -q 'const cr = cashRejectionLine(D.meta\[CH()\].cash_rejections);' "$S/index.html" && echo yes || echo no)"
else
  echo "SKIP: review_pack cash-rejection line cases need node"
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
# All three enter in a Bullish macro week -> 'Filled against the macro'.
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

# SPY basis. cash_yield is default-on since #3184, so the basis reads the overrides first and, when
# cash_yield is absent, the default of the code that ran (git places code_version vs #3184's commit;
# an unplaceable SHA, like this fixture's 0123456789abcdef, assumes the current default and says so).
#   px  : (cash_yield No_yield), no dividends            -> price
#   tr  : cash_yield Series + (dividend_crediting true)  -> tr
#   mix : (cash_yield No_yield) + dividends              -> mixed
#   asm : the fixture as is (no cash_yield, unknown SHA) -> cash yield assumed on, mixed
# The fixture SPY's adjusted_close is 0.9 x close before 2020-03-01 here, so the two bases differ:
# price 301 -> 400 = +32.89 %, total return 270.9 -> 400 = +47.66 %.
mkdir -p "$TMP/tr"; cp -R "$FIX/data" "$TMP/tr/data"
SPY_CSV="$TMP/tr/data/S/Y/SPY/data.csv"
awk -F, 'BEGIN { OFS = "," } NR > 1 && $1 < "2020-03-01" { $6 = sprintf("%.2f", $5 * 0.9) } { print }' "$SPY_CSV" > "$SPY_CSV.x"; mv "$SPY_CSV.x" "$SPY_CSV"
basis_run() { # $1 name, $2 extra overrides
  mkdir -p "$TMP/tr/$1"; cp "$FIX"/run/* "$TMP/tr/$1/"
  sed "s/(overrides (((enable_short_side false))))/(overrides (((enable_short_side false))$2))/" "$FIX/run/params.sexp" > "$TMP/tr/$1/params.sexp"
}
basis_run px ' ((cash_yield No_yield))'
basis_run tr ' ((cash_yield (Series macro\/tbill_3m_dtb3.csv))) ((dividend_crediting true))'
basis_run mix ' ((cash_yield No_yield)) ((dividend_crediting true))'
rc=0
sh "$SCRIPT" --no-container --data-dir "$TMP/tr/data" --out "$TMP/tr/pack" px="$TMP/tr/px/" tr="$TMP/tr/tr/" mix="$TMP/tr/mix/" asm="$FIX/run/" >"$TMP/tr.log" 2>&1 || rc=$?
expect_eq "basis: builds, exit 0" 0 "$rc"
TD="$TMP/tr/pack/site/data"
expect_eq "basis: price-only run (No_yield, no dividends)" '{"spy":"price","cash_yield":false,"dividends":false,"cash_yield_src":"explicit"}' "$(jq -c .basis "$TD/px_meta.json")"
expect_eq "basis: total-return run (both armed)" '{"spy":"tr","cash_yield":true,"dividends":true,"cash_yield_src":"explicit"}' "$(jq -c .basis "$TD/tr_meta.json")"
expect_eq "basis: dividends only is mixed" '{"spy":"mixed","cash_yield":false,"dividends":true,"cash_yield_src":"explicit"}' "$(jq -c .basis "$TD/mix_meta.json")"
expect_eq "basis: no cash_yield and an unknown code_version assumes the current default (on)" '{"spy":"mixed","cash_yield":true,"dividends":false,"cash_yield_src":"assumed"}' "$(jq -c .basis "$TD/asm_meta.json")"
expect_eq "basis: the price-only run's year table reads SPY price (+32.89 %)" 32.89 "$(jq -r '.[0].spy' "$TD/px_years.json")"
expect_eq "basis: the total-return run's year table reads SPY TR (+47.66 %)" 47.66 "$(jq -r '.[0].spy' "$TD/tr_years.json")"
expect_eq "basis: both SPY series are published" "301 270.9" "$(jq -r '.[0][1]+0' "$TD/spy_price.json") $(jq -r '.[0][1]+0' "$TD/spy.json")"
# The version default, where this checkout holds the commits (a shallow CI clone may not): 14db1a8e
# (the total-return-26y tr0 run) predates #3184 -> No_yield; 725507d9 contains it -> on.
if git -C "$ROOT" cat-file -e 14db1a8e523171ae32c1fd3729925248def75076^{commit} 2>/dev/null && git -C "$ROOT" cat-file -e 725507d9ccf95d4c5e98758985c3115b9b3c50e4^{commit} 2>/dev/null && git -C "$ROOT" cat-file -e 99f0b3218787c8abde82400eeccecfb2fe241d2c^{commit} 2>/dev/null; then
  for v in 14db1a8e523171ae32c1fd3729925248def75076:false 725507d9ccf95d4c5e98758985c3115b9b3c50e4:true; do
    mkdir -p "$TMP/tr/ver"; cp "$FIX"/run/* "$TMP/tr/ver/"
    sed "s/(code_version 0123456789abcdef)/(code_version ${v%%:*})/" "$FIX/run/params.sexp" > "$TMP/tr/ver/params.sexp"
    expect_eq "basis: no cash_yield override at ${v%%:*} -> the default of that code (cash yield ${v#*:})" "${v#*:} default" "$(sh "$ROOT/dev/lib/review_pack/meta.sh" "$TMP/tr/ver" | jq -r '.basis|"\(.cash_yield) \(.cash_yield_src)"')"
  done
else
  echo "SKIP: review_pack version-default basis cases need the full git history"
fi
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
  expect_eq "sharpeBasis: an assumed cash yield says so" "excess over net T-bill (assumed: code_version not in this checkout)" "$(bas 'sharpeBasis({ cash_yield: true, cash_yield_src: "assumed" })')"
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
# #3177: a .panel grid stretched to its taller sibling spread the conformance table's rows over the
# validator's height (the table read blank in a capped capture); panels now pack their rows at the top.
# An empty conformance table says n/a instead of drawing a blank table.
expect_eq "panels pack rows at the top (align-content: start)" 1 "$(grep -c '^\.panel {.*align-content: start;' "$S/index.html")"
expect_eq "conformance table without a trade audit report reads n/a" 1 "$(grep -c "^const CONF_NA = '<tr><td colspan=\"4\" style=\"white-space:normal\">n/a: no trade audit report" "$S/index.html")"
expect_eq "conformance n/a is wired into the table" 1 "$(grep -c '<tbody>${cf.length ? rows : CONF_NA}</tbody>' "$S/index.html")"
# #3177 QC rework: the capture follows the MEASURED height. A stub Chrome answers --dump-dom with a
# page height and records each --screenshot with its --window-size; it writes a real PNG of that size
# when ImageMagick is present (then the parts are cut and checked too). A page with no height falls back
# to 9000 px and says so.
STUBOK="$TMP/stub-ok"
cat > "$STUBOK" <<'STUB'
#!/bin/sh
for a in "$@"; do case "$a" in
  --dump-dom) [ -n "${STUB_H:-}" ] && echo "<html data-page-h=\"$STUB_H\"><body>ok</body></html>" || echo "<html><body>ok</body></html>"; exit 0 ;;
  --screenshot=*) out=${a#--screenshot=} ;; --window-size=*) ws=${a#--window-size=} ;; esac; done
echo "$(basename "$out") $ws" >> "$STUB_LOG"
if command -v convert >/dev/null 2>&1; then convert -size "${ws%,*}x${ws#*,}" xc:white "$out"; else echo png > "$out"; fi
STUB
chmod +x "$STUBOK"
rc=0; STUB_H=5000 STUB_LOG="$TMP/stub.log" CHROME="$STUBOK" sh "$RENDER" --site "$S" --out "$TMP/render-ok" >"$TMP/render-ok.log" 2>&1 || rc=$?
expect_eq "render: full.png is captured at the measured height (5000), top.png at the first screen" "top.png 1400,1300|full.png 1400,5000" "$(paste -sd'|' - < "$TMP/stub.log")"
if command -v convert >/dev/null 2>&1 || command -v magick >/dev/null 2>&1 || command -v sips >/dev/null 2>&1; then
  expect_eq "render: a 5000 px page is cut into the --plan 5000 parts, 1500 px each" "0 4 1500 1500 1500 1500" "$rc $(ls "$TMP/render-ok"/part-*.png | wc -l | tr -d ' ') $(for p in 1 2 3 4; do identify -format '%h ' "$TMP/render-ok/part-$p.png"; done | sed 's/ $//')"
else
  echo "SKIP: review_pack render slicing needs ImageMagick or sips"
fi
rc=0; STUB_LOG="$TMP/stub-fb.log" CHROME="$STUBOK" sh "$RENDER" --site "$S" --out "$TMP/render-fb" >"$TMP/render-fb.log" 2>&1 || rc=$?
expect_eq "render: no measured height falls back to 9000 px" "full.png 1400,9000" "$(grep '^full.png' "$TMP/stub-fb.log")"
expect_eq "render: and says it could not measure the page" 1 "$(grep -c 'could not measure the page; using 9000 px' "$TMP/render-fb.log")"

# What the conformance and validator panels render (confTable / validatorList, the functions the
# page calls), and the basis object every basis call site reads (basisView).
if command -v node >/dev/null 2>&1; then
  PFNS="$(sed -n -e '/^const CONF_NA = /p' -e '/^function confTable(/,/^}/p' -e '/^function validatorList(/,/^}/p' -e '/^function spyBasis(/,/^}/p' -e '/^function spyBasisLabel(/,/^}/p' -e '/^function sharpeBasis(/,/^}/p' -e '/^function basisView(/,/^}/p' "$S/index.html")"
  pg() { node -e "$PFNS
const cf = [1, 2, 3, 6, 7, 8].map(i => ({ rule: 'R' + i, desc: 'rule ' + i, passed: '618/618', rate: '100%', fails: '0' }));
const vs = Array.from({ length: 17 }, (_, i) => ({ id: 'V' + (i + 1), sev: 'INVARIANT', status: i === 16 ? '2 violations' : 'PASS', specimens: i === 16 ? ['ZZZ specimen'] : [] }));
console.log($1)"; }
  expect_eq "confTable: six conformance rows render, R1..R8" "6 R1 R8" "$(pg '[(confTable(cf).match(/<tr><td><b>R/g) || []).length, ...["R1", "R8"].filter(r => confTable(cf).includes("<b>" + r + "</b>"))].join(" ")')"
  expect_eq "confTable: no rows reads n/a" yes "$(pg 'confTable([]).includes("n/a: no trade audit report") ? "yes" : "no"')"
  expect_eq "validatorList: V1..V17 all render, V9 and V17 included" "17 yes yes" "$(pg '[(validatorList(vs).match(/<summary>/g) || []).length, validatorList(vs).includes("<b>V9</b>") ? "yes" : "no", validatorList(vs).includes("<b>V17</b>") ? "yes" : "no"].join(" ")')"
  expect_eq "validatorList: a failing invariant opens with its specimens" yes "$(pg '/<details open[^>]*><summary><b>V17<\/b>.*ZZZ specimen/.test(validatorList(vs)) ? "yes" : "no"')"
  expect_eq "basisView: price -> SPY price series, no dashed line" '{"series":"spyPrice","total":"SPY price only","legend":"SPY price only","priceLine":false}' "$(pg 'JSON.stringify((({ series, total, legend, priceLine }) => ({ series, total, legend, priceLine }))(basisView({ spy: "price", cash_yield: false, dividends: false })))')"
  expect_eq "basisView: mixed -> TR series plus the dashed price line, legend says so" '{"series":"spyTR","legend":"SPY total return (run credits dividends only) · dashed: SPY price only","priceLine":true}' "$(pg 'JSON.stringify((({ series, legend, priceLine }) => ({ series, legend, priceLine }))(basisView({ spy: "mixed", cash_yield: false, dividends: true })))')"
  expect_eq "basisView: total return -> TR series; Sharpe label excess over net T-bill" '{"series":"spyTR","sharpe":"excess over net T-bill","priceLine":false}' "$(pg 'JSON.stringify((({ series, sharpe, priceLine }) => ({ series, sharpe, priceLine }))(basisView({ spy: "tr", cash_yield: true, dividends: true })))')"
else
  echo "SKIP: review_pack panel/basis page cases need node"
fi
# the call sites read those functions (a page that bypasses them fails here)
expect_eq "wiring: D.spy is the basisView series" 1 "$(grep -c '^  D.spy = D\[basisView(D.meta\[D.man.charts_run || 0\].basis).series\];$' "$S/index.html")"
expect_eq "wiring: KPI total return, Sharpe, legend and the dashed line read basisView" 4 "$(grep -c 'BV\.total\|BV\.sharpe\|BV\.legend\|if (BV\.priceLine)' "$S/index.html")"
expect_eq "wiring: the panels render through confTable / validatorList" 2 "$(grep -c "^  \$('#conf').innerHTML = confTable(cf);\$\|^  \$('#validator').innerHTML = validatorList(D.meta\[CH()\].validator);\$" "$S/index.html")"
# #3141. HHH: flat 100,000-share weeks, then 300,000 a day in the week the entry FILLED (2020-01-27..31)
# -> fill-week volume ratio 3.00 while its screen-week entry_volume_ratio says 1.5; III: the bars end on
# 2020-03-31 and a stop exit is dated 2020-04-01 (a delisting stamped the day after the last bar) ->
# not the Saturday-fill defect.
mkdir -p "$TMP/v41/data/H/H/HHH" "$TMP/v41/data/I/I/III" "$TMP/v41/data/S/Y" "$TMP/v41/run"; cp -R "$FIX/data/S/Y/SPY" "$TMP/v41/data/S/Y/"
awk -F, 'NR == 1 { print; next } { v = ($1 >= "2020-01-27" && $1 <= "2020-01-31") ? 300000 : 100000; printf "%s,10.00,10.50,9.50,10.00,10.00,%d,\n", $1, v }' "$FIX/data/A/A/AAA/data.csv" > "$TMP/v41/data/H/H/HHH/data.csv"
awk -F, 'NR == 1 { print; next } $1 <= "2020-03-31" { printf "%s,10.00,10.50,9.50,10.00,10.00,100000,\n", $1 }' "$FIX/data/A/A/AAA/data.csv" > "$TMP/v41/data/I/I/III/data.csv"
cp "$FIX"/run/* "$TMP/v41/run/"
{ head -1 "$FIX/run/trades.csv"
  echo "HHH,LONG,2020-01-29,2020-03-02,33,10.00,10.00,1000,0.00,0.00,,,laggard_rotation,Stage2,1.5000,0.0800,non_stop_exit,,100,HHH-wein-1,,,0"
  echo "III,LONG,2020-01-29,2020-04-01,63,10.00,9.60,1000,-400.00,-4.00,9.60,9.60,stop_loss,Stage2,2.5000,0.0400,intraday,63,100,III-wein-2,,,0"; } > "$TMP/v41/run/trades.csv"
rc=0
sh "$SCRIPT" --no-container --data-dir "$TMP/v41/data" --out "$TMP/v41/pack" r0="$TMP/v41/run/" >"$TMP/v41.log" 2>&1 || rc=$?
expect_eq "#3141: builds, exit 0" 0 "$rc"
V41="$TMP/v41/pack/site/data/r0_trades.json"
expect_eq "#3141: fill-week volume ratio = the fill week vs its 4 prior weeks (3.00), not the screen week (1.5)" "3 1.5" "$(jq -r '.[]|select(.sym=="HHH")|"\(.fvr+0) \(.vr+0)"' "$V41")"
expect_eq "#3141: flat volume reads 1.00" 1 "$(jq -r '.[]|select(.sym=="III")|.fvr+0' "$V41")"
expect_eq "#3141: an exit dated after the last bar is marked" "0 1" "$(jq -r '.[]|select(.sym=="III")|"\(.onX) \(.xpast)"' "$V41")"
if command -v node >/dev/null 2>&1; then
  V41F="$(sed -n -e '/^\/\/ Side-aware trade helpers/,/^const ownStage/p' -e '/^const FLAGS = \[/,/^\];/p' "$S/index.html")"
  v41() { node -e "$V41F
const T = $(jq -c . "$V41"), F = id => FLAGS.find(f => f.id === id);
console.log($1)"; }
  expect_eq "#3141: the Saturday-fill card leaves out an exit past the last bar (III)" false "$(v41 'F("weekend").test(T.find(t => t.sym === "III"))')"
  expect_eq "#3141: the low-volume card reads the fill week (HHH 3.00: quiet; III 1.00: flagged)" "false true" "$(v41 '["HHH", "III"].map(s => F("lowvol").test(T.find(t => t.sym === s))).join(" ")')"
  expect_eq "#3141: the Stage-4 card needs the stage replay (n/a, not 0, without it)" holdW "$(v41 'F("stage4").needs')"
  expect_eq "#3141: the low-volume card needs the fill-week ratio" fvr "$(v41 'F("lowvol").needs')"
else
  echo "SKIP: review_pack #3141 page cases need node"
fi
# #3199 QC follow-up: the overview fallback finding and the Diagnostics fallback share read n/a, never a
# clean 0, when no trade carries the audit's stop_floor_kind; the page renders them through these functions.
if command -v node >/dev/null 2>&1; then
  FFNS="$(sed -n -e '/^const fmt = /p' -e '/^const share = /p' -e '/^\/\/ Side-aware trade helpers/,/^const ownStage/p' "$S/index.html")"
  ffb() { node -e "$FFNS
const withKind = [{ sfk: 'Buffer_fallback' }, { sfk: 'Support_floor' }, { sfk: 'Support_floor' }, { sfk: 'Support_floor' }], noKind = [{ sid: 0.04 }, { sid: 0.08 }];
console.log($1)"; }
  expect_eq "fallbackFinding: with stop kinds, counts the Buffer_fallback trades" "<b>1 of 4 trades (25%) used the 4% fallback stop</b> rather than a stop under the base or MA." "$(ffb 'fallbackFinding(withKind)')"
  expect_eq "fallbackFinding: without stop kinds reads n/a, not 0 (even with a 4 % sid)" yes "$(ffb 'fallbackFinding(noKind).startsWith("<b>Fallback stops: n/a</b>") ? "yes" : "no"')"
  expect_eq "fallbackShare: a cohort's share with stop kinds, null (n/a) without" "25 null" "$(ffb '[fallbackShare(withKind, withKind), fallbackShare(noKind, noKind)].join(" ").replace(/ $/, " null")')"
  expect_eq "fallbackShare: the cohort's share, not the whole run's (1 of 1 in the cohort = 100, run 25)" 100 "$(ffb 'fallbackShare(withKind, [withKind[0]])')"
else
  echo "SKIP: review_pack fallback guard cases need node"
fi
expect_eq "wiring: the overview finding and the Diagnostics column read fallbackFinding / fallbackShare" 2 "$(grep -c '^    fallbackFinding(t),$\|${tdn(fallbackShare(t, a))}' "$S/index.html")"
# #3203 QC rework 1: the fill-week ratio's window, null rules and threshold, and the xpast boundary.
#   JJJ: bars start 2020-01-21, so the fill week (2020-01-27) has 1 prior week -> fvr null (needs 2);
#        the low-volume card leaves a null ratio out, and the JSON carries null, not 0;
#   KKK: no volume before the fill week -> fvr null (no division by a zero average), the trade still graded;
#   LLL: 500,000 a day in the oldest of the 4 prior weeks (2 bars), 100,000 in the 3 after, 300,000 in
#        the fill week -> 300,000 / (2,500,000 / 17 bars) = 2.04; a 3-week window would read 3.00;
#   MMM: 220,000 a day in the fill week vs 100,000 -> 2.20, not flagged (the card is < 2);
#   NNN: bars end 2020-03-31 and the exit is dated 2020-03-31 -> on the last bar, xpast 0.
V42="$TMP/v42"; mkdir -p "$V42/run"; cp "$FIX"/run/* "$V42/run/"
for s in JJJ KKK LLL MMM NNN; do mkdir -p "$V42/data/$(printf %s "$s" | cut -c1)/$(printf %s "$s" | rev | cut -c1)/$s"; done
mkdir -p "$V42/data/S/Y"; cp -R "$FIX/data/S/Y/SPY" "$V42/data/S/Y/"
bars() { # $1 symbol, $2 awk program printing the volume v for date $1 (empty = no bar)
  awk -F, "NR == 1 { print; next } { $2; if (v != \"\") printf \"%s,10.00,10.50,9.50,10.00,10.00,%d,\\n\", \$1, v }" "$FIX/data/A/A/AAA/data.csv" > "$V42/data/$(printf %s "$1" | cut -c1)/$(printf %s "$1" | rev | cut -c1)/$1/data.csv"
}
bars JJJ 'v = ($1 >= "2020-01-21") ? 100000 : ""'
bars KKK 'v = ($1 >= "2020-01-27") ? 100000 : 0'
bars LLL 'v = ($1 < "2020-01-06") ? 500000 : ($1 >= "2020-01-27" && $1 <= "2020-01-31") ? 300000 : 100000'
bars MMM 'v = ($1 >= "2020-01-27" && $1 <= "2020-01-31") ? 220000 : 100000'
bars NNN 'v = ($1 <= "2020-03-31") ? 100000 : ""'
{ head -1 "$FIX/run/trades.csv"
  for s in JJJ KKK LLL MMM; do echo "$s,LONG,2020-01-29,2020-03-02,33,10.00,10.00,1000,0.00,0.00,,,laggard_rotation,Stage2,2.5000,0.0800,non_stop_exit,,100,$s-wein-1,,,0"; done
  echo "NNN,LONG,2020-01-29,2020-03-31,62,10.00,9.60,1000,-400.00,-4.00,9.60,9.60,stop_loss,Stage2,2.5000,0.0400,intraday,62,100,NNN-wein-1,,,0"; } > "$V42/run/trades.csv"
rc=0
sh "$SCRIPT" --no-container --data-dir "$V42/data" --out "$V42/pack" r0="$V42/run/" >"$V42/log" 2>&1 || rc=$?
expect_eq "#3203 rework: builds, exit 0" 0 "$rc"
V42T="$V42/pack/site/data/r0_trades.json"
v42() { jq -r ".[]|select(.sym==\"$1\")|$2" "$V42T"; }
expect_eq "fvr: one prior week -> null in the JSON (not 0)" null "$(v42 JJJ '.fvr')"
expect_eq "fvr: no prior volume -> null, and the trade is still extracted (graded)" "null true" "$(v42 KKK '"\(.fvr) \(.g != null)"')"
expect_eq "fvr: the window is the 4 prior weeks, per bar (2.04; 3 weeks would read 3.00)" 2.04 "$(v42 LLL '.fvr+0')"
expect_eq "fvr: 2.20 in the fill week" 2.2 "$(v42 MMM '.fvr+0')"
expect_eq "xpast: an exit on the last bar is not past it" "1 0" "$(v42 NNN '"\(.onX) \(.xpast)"')"
if command -v node >/dev/null 2>&1; then
  V42F="$(sed -n -e '/^\/\/ Side-aware trade helpers/,/^const ownStage/p' -e '/^const FLAGS = \[/,/^\];/p' "$S/index.html")"
  v42n() { node -e "$V42F
const T = $(jq -c . "$V42T"), F = id => FLAGS.find(f => f.id === id);
console.log($1)"; }
  expect_eq "low-volume card: a null fill-week ratio is left out; 2.20 is not under 2; 2.04 is not either" "false false false" "$(v42n '["JJJ", "MMM", "LLL"].map(s => F("lowvol").test(T.find(t => t.sym === s))).join(" ")')"
  expect_eq "low-volume card: the threshold is strictly under 2 (2.00 passes, 1.99 is flagged)" "false true" "$(v42n '[2, 1.99].map(v => F("lowvol").test({ side: "LONG", fvr: v })).join(" ")')"
else
  echo "SKIP: review_pack #3203 rework page cases need node"
fi
# #3140 part 3, P&L anatomy: pure functions extracted from the page and pinned with node.
if command -v node >/dev/null 2>&1; then
  AFNS="$(sed -n -e '/^function hillAlpha(/,/^}/p' -e '/^function anatomyRow(/,/^}/p' -e '/^function anatomyShape(/,/^}/p' "$S/index.html")"
  an() { node -e "$AFNS
const tr = (pct, pnl, extra) => Object.assign({ ed: '2020-01-02', qty: 100, ep: 100, pct, pnl }, extra || {});
console.log($1)"; }
  expect_eq "hillAlpha: k=2 over 8, 4, 2 = 2 / (ln(8/2) + ln(4/2))" "0.962" "$(an 'hillAlpha([8, 4, 2], 2).toFixed(3)')"
  expect_eq "hillAlpha: too few values -> null" null "$(an 'hillAlpha([8, 4], 2)')"
  expect_eq "hillAlpha: k < 2 -> null even with enough values" null "$(an 'hillAlpha([8, 4], 1)')"
  expect_eq "anatomyRow: 2 wins (+20, +10 %), 2 losses (-5, -5 %) at a 100k NAV, 10k each" \
    '{"n":4,"weight":10,"p":50,"aw":15,"al":5,"payoff":3,"exp":5,"navpct":2}' \
    "$(an 'JSON.stringify(anatomyRow([tr(20, 2000), tr(10, 1000), tr(-5, -500), tr(-5, -500)], () => 100000))')"
  # decoys, each failing exactly one conjunct: a winning stop exit and a losing rotation exit that kept
  # falling (not good stops), a stop exit that ran (not a regret), a rotation exit that ran 14.99 % (under 15)
  expect_eq "anatomyShape: top-1 share, hindsight counts (each decoy misses one condition)" '{"topShare":200,"whipsaw":1,"goodStop":1,"regret":1}' \
    "$(an 'JSON.stringify((({ topShare, whipsaw, goodStop, regret }) => ({ topShare, whipsaw, goodStop, regret }))(anatomyShape([tr(20, 2000, { trig: "laggard_rotation", pmax: 15 }), tr(-5, -500, { trig: "stop_loss", g: "D", p13: 10 }), tr(-5, -500, { trig: "stop_loss", g: "B", p13: -8 }),
      tr(5, 500, { trig: "stop_loss", g: "B", p13: -8 }), tr(-5, -500, { trig: "laggard_rotation", g: "B", p13: -8 }), tr(-5, -500, { trig: "stop_loss", g: "B", pmax: 20 }), tr(5, 500, { trig: "laggard_rotation", g: "B", pmax: 14.99 })], 1)))')"
  expect_eq "anatomyShape: Hill alpha over k = min(20, n / 4) (12 wins of 1k..12k -> k 3, 3 / (ln 12/9 + ln 11/9 + ln 10/9) = 5.05); no losses -> null" "5.05 null" \
    "$(an '((s) => [s.alphaW.toFixed(2), String(s.alphaL)].join(" "))(anatomyShape(Array.from({ length: 12 }, (_, i) => tr(1, 1000 * (i + 1)))))')"
else
  echo "SKIP: review_pack anatomy cases need node"
fi
expect_eq "wiring: the P&L anatomy card is rendered on load" 1 "$(grep -c 'renderDiag(); renderAnatomy(); renderSalts();' "$S/index.html")"
# #3194 short-book follow-ups.
# 1. Regime warm-up: spy_warmup.json carries the REGIME_WARMUP_ROWS SPY bars before the window, so the
#    window's first day has a regime. W adds 2019's weekdays (261, rising) in front of the fixture's SPY.
W="$TMP/w3194"; mkdir -p "$W"; cp -R "$FIX/data" "$W/data"
{ head -1 "$FIX/data/S/Y/SPY/data.csv"
  awk 'BEGIN { split("31 28 31 30 31 30 31 31 30 31 30 31", ml, " "); wd = 2; p = 200 # 2019-01-01 was a Tuesday
    for (m = 1; m <= 12; m++) for (d = 1; d <= ml[m]; d++) { if (wd >= 1 && wd <= 5) { p += 0.25; printf "2019-%02d-%02d,%.2f,%.2f,%.2f,%.2f,%.2f,1000000,\n", m, d, p, p + 1, p - 1, p, p - 10 } wd = (wd + 1) % 7 } }'
  tail -n +2 "$FIX/data/S/Y/SPY/data.csv"; } > "$W/spy.csv"
mv "$W/spy.csv" "$W/data/S/Y/SPY/data.csv"
rc=0
sh "$SCRIPT" --no-container --data-dir "$W/data" --out "$W/pack" r0="$FIX/run/" >"$W/log" 2>&1 || rc=$?
expect_eq "#3194 warm-up: builds, exit 0" 0 "$rc"
WD="$W/pack/site/data"
expect_eq "#3194 warm-up: 180 pre-window bars, ending the day before the window" "180 2019-12-31" "$(jq -r '"\(length) \(.[-1][0])"' "$WD/spy_warmup.json")"
expect_eq "#3194 warm-up: [date, adjusted_close, close] per bar" "2019-12-31 255.25 265.25" "$(jq -r '.[-1] | [.[0], (.[1:] | map(. + 0 | tostring)[])] | join(" ")' "$WD/spy_warmup.json")"
expect_eq "#3194 warm-up: spy.json stays clipped to the window" 100 "$(jq length "$WD/spy.json")"
expect_eq "#3194 warm-up: no SPY history before the window -> empty warm-up" 0 "$(jq length "$S/data/spy_warmup.json")"
if command -v node >/dev/null 2>&1; then
  RFNS="$(sed -n -e '/^function spyBasis(/,/^}/p' -e '/^function withWarmup(/,/^}/p' -e '/^function spyRegimeByDay(/,/^}/p' -e '/^function isoWeek(/p' "$S/index.html")"
  rg() { node -e "const D = {};
$RFNS
const warm = $(jq -c . "$WD/spy_warmup.json"), spy = $(jq -c . "$WD/spy.json");
console.log($1)"; }
  expect_eq "#3194 regime: the window's first day reads UP with the warm-up, '' without it" "UP|" "$(rg '[spyRegimeByDay(withWarmup(warm, spy, { spy: "tr" })).get(spy[0][0]), spyRegimeByDay(spy).get(spy[0][0])].join("|")')"
  expect_eq "#3194 regime: withWarmup reads close on a price basis, adjusted_close otherwise" "265.25 255.25" "$(rg '[withWarmup(warm, spy, { spy: "price" })[179][1], withWarmup(warm, spy, { spy: "tr" })[179][1]].join(" ")')"
  expect_eq "#3194 regime: withWarmup keeps the window and drops warm-up rows dated inside it" "100 2020-01-02" "$(rg '((s) => [s.length, s[0][0]].join(" "))(withWarmup([["2020-01-02", 1, 1]], spy, null))')"
  expect_eq "#3194 regime: the default series is D.spyRegime (the page sets it)" "UP" "$(rg '(D.spyRegime = withWarmup(warm, spy, null), spyRegimeByDay().get(spy[0][0]))')"
else
  echo "SKIP: review_pack #3194 regime cases need node"
fi
expect_eq "#3194 wiring: the page loads spy_warmup.json and sets D.spyRegime" 2 "$(grep -c "load('spy_warmup.json')\|D.spyRegime = withWarmup(" "$S/index.html")"
# 2-4. Cost netting, margin churn, NAV-peak give-back: pure functions pinned with node.
if command -v node >/dev/null 2>&1; then
  CFNS="$(sed -n -e '/^const fmt = /p' -e '/^const pct = /p' -e '/^const usdk = /p' -e '/^const COMMISSION_PER_SHARE/p' -e '/^const MARGIN_CHURN_PRICE/p' -e '/^const GIVEBACK_OPEN_PCT/p' \
    -e '/^function openSignal(/,/^}/p' -e '/^function openPnl(/,/^}/p' -e '/^function marginChurn(/,/^}/p' -e '/^function v16Count(/,/^}/p' -e '/^function marginChurnLine(/,/^}/p' \
    -e '/^function navPeakGiveback(/,/^}/p' -e '/^function givebackLine(/,/^}/p' "$S/index.html")"
  cs() { node -e "$CFNS
const tr = (sym, ep, trig, pnl, extra) => Object.assign({ sym, ep, trig, pnl, side: 'SHORT', qty: 100, ed: '2020-01-02', xd: '2020-02-03' }, extra || {});
console.log($1)"; }
  # openPnl: UnrealizedPnl wins; else move - real - (div in - div paid short + interest - commission).
  # 2 closed trades of 100 and 50 shares (fees 1, 1 each fill = 4) + 1 open of 1,000 shares (fee 10) = 14.
  expect_eq "#3194 openPnl: the run's UnrealizedPnl when the summary has it" "unrealised 42000" "$(cs '((o) => o.src + " " + o.open)(openPnl({ unrealizedpnl: 42000 }, 300e3, 100e3, [], []))')"
  expect_eq "#3194 openPnl: netted = move - real - (div 5k - short div 1k + interest 30k - commission 14)" "netted 166014 33986" \
    "$(cs '((o) => [o.src, o.open, o.costs].join(" "))(openPnl({ dividendincometotal: 5000, dividendpaidshorttotal: 1000, cashinteresttotal: 30000 }, 300e3, 100e3, [{ qty: 100 }, { qty: 50 }], [{ qty: 1000 }]))')"
  expect_eq "#3194 openPnl: without DividendIncomeTotal the trade rows' Div \$ (less 2 x \$1 commission) is netted" "199552" "$(cs 'openPnl({}, 300e3, 100e3, [{ qty: 100, div: 450 }], []).open')"
  # specimen: a 1M book, NAV +300k, realised 180k: raw remainder 120k (under half, quiet); 100k of cash
  # interest made it look bigger before, and a 280k remainder of which 150k is interest is not open P&L
  expect_eq "#3194 openSignal: 280k raw remainder fires, the same after 150k of interest is netted is quiet" "true false" \
    "$(cs '[openSignal(1e6, 300e3, 20e3), openSignal(1e6, 300e3, 20e3, openPnl({ cashinteresttotal: 150e3 }, 300e3, 20e3, [], []).open)].join(" ")')"
  # marginChurn: 6 short margin calls, 5 entered under 17 on 3 symbols (AAA twice, BBB twice); decoys: a
  # long margin call, a short stopped out under 17, a short margin call at exactly 17 (not under)
  MC='[tr("AAA", 5, "margin_call", -100), tr("AAA", 6, "margin_call", -100), tr("BBB", 16.99, "margin_call", -100), tr("BBB", 12, "margin_call", -100), tr("CCC", 3, "margin_call", -100),
    tr("DDD", 17, "margin_call", -100), tr("EEE", 5, "margin_call", -100, { side: "LONG" }), tr("FFF", 5, "stop_loss", -100)]'
  expect_eq "#3194 marginChurn: 5 of 6 short margin calls under \$17, 3 symbols, 2 repeated, fires" '{"calls":6,"low":5,"syms":3,"repeat":2,"pnl":-500,"fires":true}' "$(cs "JSON.stringify(marginChurn($MC))")"
  expect_eq "#3194 marginChurn: 4 low-priced calls (under 5) is quiet" false "$(cs "marginChurn($MC.slice(1)).fires")"
  expect_eq "#3194 marginChurn: 5 low of 11 calls (under half) is quiet" false "$(cs "marginChurn([...$MC, ...Array.from({ length: 5 }, (_, i) => tr('H' + i, 40, 'margin_call', -100))]).fires")"
  expect_eq "#3194 v16Count: 'N violations' -> N, PASS -> 0, absent -> null" "68 0 null" "$(cs '[v16Count([{ id: "V16", status: "68 violations" }]), v16Count([{ id: "V16", status: "PASS" }]), v16Count([])].map(String).join(" ")')"
  expect_eq "#3194 marginChurnLine: names the counts, V16 and each run's low count" yes \
    "$(cs "marginChurnLine(marginChurn($MC), 68, [['soT', 68], ['soT2', 50]])" | grep -q '5 of 6 margin calls.*on 3 symbols (2 called more than once).*V16 counts 68.*By run: soT 68, soT2 50' && echo yes || echo no)"
  expect_eq "#3194 marginChurnLine: quiet when it does not fire" "" "$(cs "marginChurnLine(marginChurn($MC.slice(1)), 68, [])")"
  # navPeakGiveback: start 1M, peak 1.4M on day 2 with 100k realised by then -> 300k open at the peak;
  # ends at 1.2M -> 200k given back (>= half of 300k): fires. Held at the peak: B (closed later, +50k) and
  # one open row entered before it.
  GB="const nav = [['2020-01-02', 1e6], ['2020-02-03', 1.1e6], ['2020-03-02', 1.4e6], ['2020-04-01', 1.3e6], ['2020-05-01', ENDV]];
const T = [{ ed: '2020-01-02', xd: '2020-02-03', pnl: 100e3 }, { ed: '2020-01-10', xd: '2020-04-01', pnl: 50e3 }], O = [{ ed: '2020-02-10' }, { ed: '2020-04-10' }];"
  gbk() { node -e "$CFNS
$(printf '%s' "$GB" | sed "s/ENDV/$1/")
console.log($2)"; }
  expect_eq "#3194 navPeakGiveback: 300k open at the 1.4M peak, 200k given back, 2 held, fires" '{"d":"2020-03-02","peak":1400000,"end":1200000,"openAtPeak":300000,"giveback":200000,"held":2,"heldPnl":50000,"fires":true}' "$(gbk 1.2e6 'JSON.stringify(navPeakGiveback(nav, T, O))')"
  expect_eq "#3194 navPeakGiveback: 140k given back of 300k (under half) is quiet" false "$(gbk 1.26e6 'navPeakGiveback(nav, T, O).fires')"
  expect_eq "#3194 navPeakGiveback: exactly half given back fires" true "$(gbk 1.25e6 'navPeakGiveback(nav, T, O).fires')"
  expect_eq "#3194 navPeakGiveback: peak on the last day -> null" null "$(gbk 1.5e6 'navPeakGiveback(nav, T, O)')"
  expect_eq "#3194 navPeakGiveback: open gain under 10 % of start NAV is quiet" false "$(gbk 1e6 'navPeakGiveback(nav, [{ ed: "2020-01-02", xd: "2020-02-03", pnl: 320e3 }], []).fires')"
  expect_eq "#3194 givebackLine: names the peak, the open gain and the give-back; quiet when it does not fire" "yes " \
    "$(gbk 1.2e6 '[givebackLine(navPeakGiveback(nav, T, O)).includes("peaked at $1.40M on 2020-03-02 with about $300k unrealised in the 2 positions") ? "yes" : "no", givebackLine(null)].join(" ")')"
else
  echo "SKIP: review_pack #3194 detector cases need node"
fi
expect_eq "#3194 wiring: What stands out uses openPnl, the give-back and the margin-churn lines" 3 \
  "$(grep -c 'const op = openPnl(D.meta\[CH()\].metrics\|const gb = givebackLine(navPeakGiveback(\|const mc = marginChurnLine(marginChurn(tr)' "$S/index.html")"
# #3214 flag cards and year bullets: pure functions extracted from the page and pinned with node.
if command -v node >/dev/null 2>&1; then
  FCF="$(sed -n -e '/^const fmt = /p' -e '/^const pct = /p' -e '/^const usdk = /p' -e '/^const sgn = /p' -e '/^const FLAG_WATCH_SHARE_PCT/p' -e '/^const FLAG_SEV_RANK/p' -e '/^const FLAG_CAT/p' -e '/^function openHits(/,/^}/p' -e '/^function flagSeverity(/,/^}/p' -e '/^function flagPlan(/,/^}/p' -e '/^function flagCardHtml(/,/^}/p' -e '/^function flagClearLine(/,/^}/p' -e '/^function flagRuleNote(/,/^}/p' -e '/^function oneTradeYear(/,/^}/p' -e '/^function yearRestsBullet(/,/^}/p' "$S/index.html")"
  expect_eq "flag cards: all page functions extracted" 8 "$(printf '%s\n' "$FCF" | grep -c '^function ')"
  fc() { node -e "$FCF
// n trades carrying flag id, each with the given pnl; total = 520 closed trades, start NAV 1M
const mk = (id, n, pnl) => Array.from({ length: n }, () => ({ flags: [id], pnl }));
const mkAll = parts => parts.flat().concat(Array.from({ length: 520 - parts.flat().length }, () => ({ flags: [], pnl: 0 })));
const FL = (id, extra) => Object.assign({ id, cat: 'exec', label: 'L-' + id, why: 'w' }, extra);
console.log($1)"; }
  # zero card hidden and named; a check with no input stays as an n/a card, never in the all-clear list
  expect_eq "flag cards: a zero card is not drawn, is named in the all-clear line; the n/a card stays (#3214)" \
    '{"drawn":["hit","miss"],"clear":["L-none"],"sev":["watch","na"],"line":true}' \
    "$(fc 'JSON.stringify((p => ({ drawn: p.cards.map(c => c.f.id), clear: p.clear, sev: p.cards.map(c => c.sev), line: /All clear.*1 check found no trades and is not drawn: L-none\./.test(flagClearLine(p.clear)) }))(
      flagPlan([FL("none"), FL("hit", { zero: true }), FL("miss", { needs: "mE" })], mkAll([mk("hit", 2, -100)]), [], 1e6)))')"
  expect_eq "flag cards: nothing hidden -> no all-clear line" "" "$(fc 'flagClearLine([])')"
  # rb1 s0 shape (520 trades, 1M start NAV): whipsaw 130 -> $-5.63M and quickstop 33 -> $-1.96M alert, the
  # Bearish-week buys 38 -> +$494k watch (config implies ~0), a 1 % card with a small loss info; the n/a card sits between
  expect_eq "flag cards: sorted alert (by |net|), watch, n/a, info" \
    '[["whipsaw","alert"],["quickstop","alert"],["macrobear","watch"],["miss","na"],["small","info"]]' \
    "$(fc 'JSON.stringify(flagPlan([FL("small"), FL("macrobear", { zero: true }), FL("miss", { needs: "mE" }), FL("quickstop"), FL("whipsaw")],
      mkAll([mk("macrobear", 38, 494e3 / 38), mk("quickstop", 33, -1.96e6 / 33), mk("whipsaw", 130, -5.63e6 / 130), mk("small", 5, -2000)]), [], 1e6).cards.map(c => [c.f.id, c.sev]))')"
  expect_eq "flag severity: thresholds are at-or-over (10 % share alert, 3 % watch, 50 % loss alert, 10 % loss watch) and a gain never raises it" \
    "alert watch info alert watch info" \
    "$(fc '[[52, 0], [16, 0], [15, 0], [3, -5e5], [3, -1e5], [3, 9e5]].map(([n, net]) => flagSeverity(FL("x"), { total: 520, closed: n, net }, 1e6)[0]).join(" ")')"
  expect_eq "flag severity: a zero-implied card hit only by an open position is still watch" "watch" \
    "$(fc 'flagPlan([FL("m", { zero: true, open: true, test: () => true })], mkAll([]), [{}], 1e6).cards[0].sev')"
  expect_eq "flag cards: the card text carries its severity and why; the page note names the thresholds" "yes yes" \
    "$(fc '[/sev-alert.*>alert<.*alert: 25% of trades, at or over 10%/.test(flagCardHtml(flagPlan([FL("w")], mkAll([mk("w", 130, -100)]), [], 1e6).cards[0])), /alert<\/b> at 10% of trades or a 50% loss.*watch<\/b> at 3% or a 10% loss/.test(flagRuleNote())].map(b => b ? "yes" : "no").join(" ")')"
  # one-trade / salt-year bullets: still built, but by yearRestsBullet, not the lead list
  expect_eq "yearRestsBullet: top trade carries a 20 pp gap -> one-trade bullet; a quiet year -> empty; salts 20 pp apart -> salt bullet" \
    "yes|-|yes" \
    "$(fc '[ /2013 rests on one trade.*ABC realised/.test(yearRestsBullet({ p: "2013", ret: 30, spy: 10, nav0: 1000 }, { sym: "ABC", pnl: 150 }, [30], "salt")) ? "yes" : "no",
      yearRestsBullet({ p: "2014", ret: 5, spy: 4, nav0: 1000 }, { sym: "ABC", pnl: 10 }, [5, 6], "salt") || "-",
      /2015 rests on the salt.*Salts made/.test(yearRestsBullet({ p: "2015", ret: 5, spy: 4, nav0: 1000 }, { sym: "ABC", pnl: 10 }, [5, 25], "salt")) ? "yes" : "no"].join("|")')"
else
  echo "SKIP: review_pack #3214 flag-card cases need node"
fi
# wiring (#3214): the lead list gets era bullets only; one-trade / salt years go to the collapsed, initially hidden note
expect_eq "wiring: renderSignals sends yearRestsBullet to rests, never to the lead list" "1 0" "$(sed -n '/^function renderSignals(/,/^}/p' "$S/index.html" | grep -c 'rests.push(b)') $(sed -n '/^function renderSignals(/,/^}/p' "$S/index.html" | grep -c 'out.push(.*yearRestsBullet')"
expect_eq "wiring: renderSignals returns lead + rests; the findings list takes lead only" "1 1" "$(grep -c 'return { lead: out, rests };' "$S/index.html") $(grep -c '\[\.\.\.sig\.lead, \.\.\.f\]' "$S/index.html")"
expect_eq "wiring: the rests note is a hidden <details>; the cards are drawn from flagPlan and the all-clear line is wired" "1 1 1" \
  "$(grep -c '<details id="rests" hidden>' "$S/index.html") $(grep -c "flagPlan(FLAGS, t, open" "$S/index.html") $(grep -c "'#flagclear').innerHTML = flagClearLine" "$S/index.html")"
# #3262 item 1: the macro join reads the screen strictly BEFORE the fill, V23's rule
# (validator_audit_checks.ml _last_screen_before). Screens dated Fridays, all Bullish but 2020-01-17:
#   F1 fills Fri 2020-01-17: that day's Bearish screen runs at the close, after the fill -> Bullish (01-10);
#   F2 fills Fri 2020-01-24: the 01-24 screen (Bullish) is after it -> Bearish (01-17), V23 counts it;
#   F3 fills Tue 2020-01-21 -> Bearish (01-17); an open position filled Fri 2020-01-17 -> Bullish.
FR="$TMP/fri"; mkdir -p "$FR"; cp -R "$FIX/run" "$FR/run"
awk 'BEGIN { split("03 10 17 24 31", jd, " "); printf "("
  for (i = 1; i <= 5; i++) printf "%s((date 2020-01-%s) (trend %s) (breadth_state Bullish_breadth))\n", (i > 1 ? " " : ""), jd[i], (jd[i] == "17" ? "Bearish" : "Bullish")
  print " ((date 2020-02-07) (trend Bullish) (breadth_state Bullish_breadth)))" }' > "$FR/run/macro_trend.sexp"
{ head -1 "$FIX/run/trades.csv"
  for r in "F1 2020-01-17" "F2 2020-01-24" "F3 2020-01-21"; do set -- $r
    echo "AAA,LONG,$2,2020-02-05,10,100.00,100.00,10,0.00,0.00,,,laggard_rotation,Stage2,2.5000,0.0400,non_stop_exit,,100,AAA-$1,,,0"; done; } > "$FR/run/trades.csv"
printf 'symbol,side,entry_date,entry_price,quantity\nBBB,LONG,2020-01-17,25.00,100\n' > "$FR/run/open_positions.csv"
rc=0
sh "$SCRIPT" --no-container --data-dir "$FIX/data" --out "$FR/pack" r0="$FR/run/" >"$FR/log" 2>&1 || rc=$?
expect_eq "#3262 Friday fill: builds, exit 0" 0 "$rc"
expect_eq "#3262 Friday fill: macro at entry is the screen strictly before the fill (F1 F2 F3)" "Bullish Bearish Bearish" \
  "$(jq -r '[.[] | .mE] | join(" ")' "$FR/pack/site/data/r0_trades.json")"
expect_eq "#3262 Friday fill: the exit week too (exit Wed 2020-02-05 reads the 01-31 screen)" Bullish "$(jq -r '.[0].mX' "$FR/pack/site/data/r0_trades.json")"
expect_eq "#3262 Friday fill: an open position filled on a screen day reads the screen before it" Bullish "$(jq -r '.rows[0].mE' "$FR/pack/site/data/r0_open.json")"
if command -v node >/dev/null 2>&1; then
  FRF="$(sed -n -e '/^\/\/ Side-aware trade helpers/,/^const ownStage/p' -e '/^const FLAGS = \[/,/^\];/p' "$S/index.html")"
  frn() { node -e "$FRF
const T = $(jq -c . "$FR/pack/site/data/r0_trades.json"), F = id => FLAGS.find(f => f.id === id);
console.log($1)"; }
  expect_eq "#3262: the against-macro card counts F2 and F3 (V23's longs), not the Friday F1" "AAA-F2 AAA-F3" "$(frn 'T.filter(t => F("macrobear").test(t)).map(t => t.id).join(" ")')"
  expect_eq "#3262 item 2: the against-macro card says the gate blocks placement, not the fill" "yes yes yes" \
    "$(frn '[/^Filled against/.test(F("macrobear").label), /placement, not its fill/.test(F("macrobear").why), /entry_ticket_macro_suspend Off/.test(F("macrobear").why)].map(b => b ? "yes" : "no").join(" ")')"
else
  echo "SKIP: review_pack #3262 macro card cases need node"
fi
# #3262 item 3: a reused ticker. RRR's bars stop 2020-02-28 and resume 2021-06-01 (another listing, > 1 year
# later); a stale_force_exit dated Tue 2020-03-03 is past the issuer's last bar (xpast 1), so the
# non-trading-day card leaves it out. SSS's bars resume 2021-02-26 (within a year of 2020-02-28): a gap in one
# listing, so the same exit stays off a bar (xpast 0) and the card counts it. TTT resumes 2021-03-01, a year
# and a day later: past.
RT="$TMP/reused"; mkdir -p "$RT/run" "$RT/data/S/Y"; cp "$FIX"/run/* "$RT/run/"; cp -R "$FIX/data/S/Y/SPY" "$RT/data/S/Y/"
for r in "RRR 2021-06-01" "SSS 2021-02-26" "TTT 2021-03-01"; do set -- $r
  dd="$RT/data/$(printf %s "$1" | cut -c1)/$(printf %s "$1" | rev | cut -c1)/$1"; mkdir -p "$dd"
  { awk -F, 'NR == 1 { print; next } $1 <= "2020-02-28" { printf "%s,10.00,10.50,9.50,10.00,10.00,100000,\n", $1 }' "$FIX/data/A/A/AAA/data.csv"
    printf '%s,20.00,20.50,19.50,20.00,20.00,100000,\n' "$2"; } > "$dd/data.csv"; done
{ head -1 "$FIX/run/trades.csv"
  for s in RRR SSS TTT; do echo "$s,LONG,2020-01-29,2020-03-03,34,10.00,10.00,1000,0.00,0.00,,,stale_force_exit,Stage2,2.5000,0.0800,non_stop_exit,,100,$s-wein-1,,,0"; done; } > "$RT/run/trades.csv"
rc=0
sh "$SCRIPT" --no-container --data-dir "$RT/data" --out "$RT/pack" r0="$RT/run/" >"$RT/log" 2>&1 || rc=$?
expect_eq "#3262 reused ticker: builds, exit 0" 0 "$rc"
expect_eq "#3262 reused ticker: next bar > 1 year after the last -> past it; within a year -> not (RRR SSS TTT)" "0:1 0:0 0:1" \
  "$(jq -r '[.[] | "\(.onX):\(.xpast)"] | join(" ")' "$RT/pack/site/data/r0_trades.json")"
if command -v node >/dev/null 2>&1; then
  RTF="$(sed -n -e '/^\/\/ Side-aware trade helpers/,/^const ownStage/p' -e '/^const FLAGS = \[/,/^\];/p' "$S/index.html")"
  expect_eq "#3262 reused ticker: the non-trading-day card counts only SSS" SSS "$(node -e "$RTF
const T = $(jq -c . "$RT/pack/site/data/r0_trades.json");
console.log(T.filter(t => FLAGS.find(f => f.id === 'weekend').test(t)).map(t => t.sym).join(' '))")"
else
  echo "SKIP: review_pack #3262 reused-ticker card case needs node"
fi
# #3262 item 4: the header stamps the pack code's commit and the snapshot dir (none under --no-container)
expect_eq "#3262 header: manifest pack_sha is the repo HEAD (or -dirty), snapshot_dir empty with --no-container" "yes " \
  "$(jq -r --arg h "$(git -C "$ROOT" rev-parse --short=9 HEAD 2>/dev/null || echo unknown)" '"\(if (.pack_sha | startswith($h)) then "yes" else .pack_sha end) \(.snapshot_dir)"' "$S/data/manifest.json")"
if command -v node >/dev/null 2>&1; then
  PSF="$(sed -n '/^const packStamp = /p' "$S/index.html")"
  expect_eq "#3262 header: packStamp names both, and says when no snapshot was read" \
    "pack abc123def · snapshot /tmp/snap_x|pack unknown · snapshot none (--no-container)" \
    "$(node -e "$PSF
console.log([packStamp({ pack_sha: 'abc123def', snapshot_dir: '/tmp/snap_x' }), packStamp({ pack_sha: '', snapshot_dir: '' })].join('|'))")"
else
  echo "SKIP: review_pack #3262 header case needs node"
fi
expect_eq "#3262 header: the page writes packStamp into the header" 1 "$(grep -c "^  \$('#packstamp').textContent = packStamp(D.man);\$" "$S/index.html")"
# #3262 (from #3214) AVD 2:1 under a further later split: FFF's shape, but the factor before 2020-03-02 is
# 1/3 (the 2:1 plus a 3:2 after it), so fac / s = 0.67 sat under the 0.8 band -> still code 2. HHH: a
# fill at 90 on a factor-1 36-48 bar: halved (45) it sits inside, but no reverse split is behind the factor -> code 0.
mkdir -p "$TMP/avd2/data/F/F/FFF" "$TMP/avd2/data/H/H/HHH" "$TMP/avd2/data/S/Y" "$TMP/avd2/run"; cp -R "$FIX/data/S/Y/SPY" "$TMP/avd2/data/S/Y/"; cp "$FIX"/run/* "$TMP/avd2/run/"
awk -F, 'NR == 1 { print; next } { if ($1 < "2020-03-02") printf "%s,40.00,48.00,36.00,40.00,%.4f,100000,\n", $1, 40 / 3; else printf "%s,20.00,24.00,18.00,20.00,13.3333,100000,\n", $1 }' "$FIX/data/A/A/AAA/data.csv" > "$TMP/avd2/data/F/F/FFF/data.csv"
awk -F, 'NR == 1 { print; next } { printf "%s,40.00,48.00,36.00,40.00,40.00,100000,\n", $1 }' "$FIX/data/A/A/AAA/data.csv" > "$TMP/avd2/data/H/H/HHH/data.csv"
{ head -1 "$FIX/run/trades.csv"
  echo "FFF,LONG,2020-01-29,2020-04-01,63,23.50,20.00,1000,-3500.00,-14.89,,,laggard_rotation,Stage2,2.5000,0.0800,non_stop_exit,,100,FFF-wein-1,,,0"
  echo "HHH,LONG,2020-01-29,2020-04-01,63,90.00,40.00,1000,0.00,0.00,,,laggard_rotation,Stage2,2.5000,0.0800,non_stop_exit,,100,HHH-wein-2,,,0"; } > "$TMP/avd2/run/trades.csv"
rc=0
sh "$SCRIPT" --no-container --data-dir "$TMP/avd2/data" --out "$TMP/avd2/pack" r0="$TMP/avd2/run/" >"$TMP/avd2.log" 2>&1 || rc=$?
expect_eq "#3262 AVD under a further split: builds, exit 0" 0 "$rc"
expect_eq "#3262 AVD under a further split: a 2:1 fill under a 1/3 factor is code 2; 2x a factor-1 bar stays 0" "2 0" \
  "$(jq -r '[.[] | .inE] | join(" ")' "$TMP/avd2/pack/site/data/r0_trades.json")"
# #3262 (from #3214) SPY truncation: SPY bars that start after the run's first equity date abort the build
# with a message naming both dates, instead of charting the run from SPY's first bar.
mkdir -p "$TMP/spyshort/data/S/Y/SPY"; cp -R "$FIX/data/A" "$TMP/spyshort/data/"
awk -F, 'NR == 1 || $1 >= "2020-02-03"' "$FIX/data/S/Y/SPY/data.csv" > "$TMP/spyshort/data/S/Y/SPY/data.csv"
rc=0
sh "$SCRIPT" --no-container --data-dir "$TMP/spyshort/data" --out "$TMP/spyshort/pack" r0="$FIX/run/" >"$TMP/spyshort.log" 2>&1 || rc=$?
expect_eq "#3262 SPY truncation: SPY starting after the run aborts (exit 2) and names SPY's first bar" "2 1" \
  "$rc $(grep -c "SPY bars at .* start 2020-02-03, after run r0's first equity date" "$TMP/spyshort.log")"
# #3262 (from #3214) CROOT: the container path of a worktree under the bind-mounted checkout is the mount
# plus its path below the mount source, not the mount root; a repo outside the mount source fails.
. "$ROOT/dev/lib/review_pack/croot.sh"
expect_eq "#3262 croot_for: the mount root, a worktree under it, and a path outside it" "/w|/w/.claude/worktrees/x|fail" \
  "$(croot_for /h/repo /h/repo /w)|$(croot_for /h/repo /h/repo/.claude/worktrees/x /w)|$(croot_for /h/repo /h/repo2 /w || echo fail)"
expect_eq "#3262 CROOT wiring: docker_steps sets CROOT from the mount source; the stage replay gets the data dir; an empty audit warns" "1 1 1" \
  "$(grep -c '^  CROOT=$(croot_for "$src" "$REPO" "$MOUNT")' "$SCRIPT") $(grep -c 'stages.sh" "$CROOT" .* "$cdata"$' "$SCRIPT") $(grep -c 'WARNING: $l: trade_audit_report.md is missing or empty' "$SCRIPT")"
expect_eq "#3262 CROOT: no fixed container root is left in the script" 0 "$(grep -c '^CROOT=/workspaces' "$SCRIPT")"
# #3262 (from #3214) short-side reading: the pick-vs-SPY excess is side-signed (a short beats SPY by f40 + s40)
if command -v node >/dev/null 2>&1; then
  PXF="$(sed -n '/^\/\/ Side-aware trade helpers/,/^const ownStage/p' "$S/index.html")"
  expect_eq "#3262 pickExcess: long f40 - s40, short f40 + s40, null without either" "-3|8|null|null" \
    "$(node -e "$PXF
console.log([{ side: 'LONG', f40: 2, s40: 5 }, { side: 'SHORT', f40: 3, s40: 5 }, { side: 'SHORT', f40: null, s40: 5 }, { side: 'LONG', f40: 1 }].map(pickExcess).map(String).join('|'))")"
else
  echo "SKIP: review_pack #3262 pickExcess case needs node"
fi
expect_eq "#3262 short wording: the picks table reads pickExcess; the reopen table names inverted SPY on a short book" "1 1 1" \
  "$(grep -c 'ex = median(a.map(pickExcess)' "$S/index.html") $(grep -c "shortBook ? 'SPY 26 wk, inverted'" "$S/index.html") $(grep -c "shortBook ? 'ahead of inverted SPY'" "$S/index.html")"
expect_eq "#3262 short wording: hard stop, breach lag, grade rubric and agenda name both sides; no long-only phrasing left" "1 1 1 1 0" \
  "$(grep -c 'for a short, the high reaches entry × (1 + X)' "$S/index.html") $(grep -c 'its low for a long, its high for a short' "$S/index.html") $(grep -c 'rose for a long, fell for a short' "$S/index.html") $(grep -c 'a Stage 4 breakdown for a short' "$S/index.html") $(grep -c 'X% below entry\|whose low reached\|then the stock rose ≥ 15%' "$S/index.html")"
expect_eq "#3262 stage cards: both replay cards say the replay classifier is a second opinion vs the audited reading" 2 \
  "$(sed -n '/^const FLAGS = \[/,/^\];/p' "$S/index.html" | grep -c 'replay classifier (stage_chart: the default stage config on adjusted weekly closes).*R1/R3')"
# #3262 (from #3214 item 8) the stop breach reads RAW bars against the raw stop, moved only by a split: the
# adjusted basis drifts across the line on every dividend. Each name's factor steps on Mon 2020-02-10
# (bars to 02-07 carry it, from 02-10 it is 1); all enter Wed 2020-01-29 and exit Fri 2020-02-21 on stop_loss.
#   DVS short 100, stop 105, factor 0.97 (a 3 % dividend; a 5 % one snaps to 20/19, the simulator's #3104 misfire): raw highs 101 then 103, 106 on the exit bar -> lag 0.
#       The adjusted reading (stop 101.85 on the entry basis, highs 103 from the ex-date) breached on 02-10, lag 9.
#   DVL long 100, stop 95, factor 0.97: raw lows 99 then 94.5 from 02-10 -> breached on 02-10, lag 9.
#       The adjusted reading (stop 92.15) never saw it: lag -1.
#   SPL long 100, stop 90, factor 0.5 (a 2:1 split on 02-10): raw lows 99, then 46 (stop 45 after the split),
#       44 on the exit bar -> lag 0. Without the split correction the 46 lows read as a breach on 02-10.
BR="$TMP/breach"; mkdir -p "$BR/run" "$BR/data/S/Y"; cp "$FIX"/run/* "$BR/run/"; cp -R "$FIX/data/S/Y/SPY" "$BR/data/S/Y/"
brbars() { # $1 symbol, $2 factor before 02-10, then pre / post / exit-bar "open high low close" (raw)
  dd="$BR/data/$(printf %s "$1" | cut -c1)/$(printf %s "$1" | rev | cut -c1)/$1"; mkdir -p "$dd"
  awk -F, -v fac="$2" -v pre="$3" -v post="$4" -v xb="$5" 'NR == 1 { print; next }
    { b = ($1 < "2020-02-10") ? pre : ($1 == "2020-02-21") ? xb : post; split(b, p, " ")
      printf "%s,%.2f,%.2f,%.2f,%.2f,%.4f,100000,\n", $1, p[1], p[2], p[3], p[4], p[4] * ($1 < "2020-02-10" ? fac : 1) }' \
    "$FIX/data/A/A/AAA/data.csv" > "$dd/data.csv"
}
brbars DVS 0.97 "100 101 99 100" "100 103 98 100" "104 106 103 105"
brbars DVL 0.97 "100 101 99 100" "96 97 94.5 96" "96 97 94 95"
brbars SPL 0.5 "100 101 99 100" "48 50 46 48" "46 47 44 45"
# 6:5 and an 11:10 stock dividend: under the 1.25 jump the first rework used, so their post-split lows read as
# a breach on 02-10 (lag 9); the simulator's rule (over 5 %, snaps to N/M) moves the line -> lag 0 (QC rework 1)
brbars SSX 0.833333 "100 101 99 100" "80 82 76 80" "78 79 74 75"
brbars SEL 0.909091 "100 101 99 100" "88 90 82.5 88" "85 86 81 82"
# a 7 % special dividend (x = 1.0753, no N/M within 1e-3: 14/13 is 1.6e-3 away) is not a split for the simulator,
# so its stop and the line stay put: DV7's raw lows of 94.5 breach the 95 stop on 02-10 (lag 9; QC rework 2)
brbars DV7 0.93 "100 101 99 100" "96 97 94.5 96" "96 97 94 95"
{ head -1 "$FIX/run/trades.csv"
  echo "DVS,SHORT,2020-01-29,2020-02-21,23,100.00,105.00,1000,-5000.00,-5.00,105.00,105.00,stop_loss,Stage4,1.5000,0.0500,intraday,23,100,DVS-wein-1,,105.00,0"
  echo "DVL,LONG,2020-01-29,2020-02-21,23,100.00,95.00,1000,-5000.00,-5.00,95.00,95.00,stop_loss,Stage2,1.5000,0.0500,intraday,23,100,DVL-wein-1,,95.00,0"
  echo "SPL,LONG,2020-01-29,2020-02-21,23,100.00,45.00,1000,-10000.00,-10.00,90.00,45.00,stop_loss,Stage2,1.5000,0.1000,intraday,23,100,SPL-wein-1,,90.00,0"
  echo "SSX,LONG,2020-01-29,2020-02-21,23,100.00,75.00,1000,-5000.00,-5.00,90.00,75.00,stop_loss,Stage2,1.5000,0.1000,intraday,23,100,SSX-wein-1,,90.00,0"
  echo "SEL,LONG,2020-01-29,2020-02-21,23,100.00,82.00,1000,-1000.00,-1.00,90.00,81.82,stop_loss,Stage2,1.5000,0.1000,intraday,23,100,SEL-wein-1,,90.00,0"
  echo "DV7,LONG,2020-01-29,2020-02-21,23,100.00,95.00,1000,-5000.00,-5.00,95.00,95.00,stop_loss,Stage2,1.5000,0.0500,intraday,23,100,DV7-wein-1,,95.00,0"; } > "$BR/run/trades.csv"
rc=0
sh "$SCRIPT" --no-container --data-dir "$BR/data" --out "$BR/pack" r0="$BR/run/" >"$BR/log" 2>&1 || rc=$?
expect_eq "#3262 raw breach: builds, exit 0" 0 "$rc"
expect_eq "#3262 raw breach: a dividend does not move the line (DVS 0, DVL 9); a 2:1, a 6:5 and an 11:10 split do (SPL SSX SEL 0); a 7 % special dividend that snaps to no N/M does not (DV7 9)" "DVS:0 DVL:9 SPL:0 SSX:0 SEL:0 DV7:9" \
  "$(jq -r '[.[] | "\(.sym):\(.blag)"] | join(" ")' "$BR/pack/site/data/r0_trades.json")"
# #3262 (from #3214 item 5) a short-only book reads the eras against SPY inverted: the year-end ratio
# compounds -SPY, the daily benchmark earns minus SPY's daily move, and the regime wording names what a short
# book does in each regime (cash in a rising market protects it; cash through a decline misses it).
if command -v node >/dev/null 2>&1; then
  ERF="$(sed -n -e '/^const fmt = /p' -e '/^const pct = /p' -e '/^const REGIME_CASH_PCT/p' -e '/^function regimeText(/,/^}/p' -e '/^function eraPoints(/,/^}/p' -e '/^function benchSeries(/,/^}/p' "$S/index.html")"
  er() { node -e "$ERF
console.log($1)"; }
  expect_eq "#3262 eras: all three era functions extracted" 3 "$(printf '%s\n' "$ERF" | grep -c '^function ')"
  expect_eq "#3262 eraPoints: a long book compounds the year table's SPY (+10 % vs +10 % = 1; then +21 % vs +21 % = 1)" "1.000 1.000" \
    "$(er '[eraPoints([{ p: "2001", ret: 10, spy: 10 }])[1][1], eraPoints([{ p: "2001", ret: 10, spy: 10 }, { p: "2002", ret: 21, spy: 21 }])[2][1]].map(v => v.toFixed(3)).join(" ")')"
  # QC rework 1: a short book's year-end points read the daily-inverted series the chart reads. Three years of
  # SPY alternating +-1.2 % a day with a flat NAV: the ratio column's end equals the chart's last point
  # (NAV / benchSeries, both from 1), and differs from inverting each year's SPY return (the volatility drag).
  expect_eq "#3262 eraPoints: a short book's ratio ends at the chart's last point, not at the per-year inversion" "same differs" \
    "$(er '(() => { const spy = []; let v = 100; for (let i = 0; i < 756; i++) { v *= i % 2 ? 0.988 : 1.012; spy.push([`${2001 + Math.floor(i / 252)}-01-01`, v]); }
      const yr = y => spy.filter(r => r[0].startsWith(y)), b = benchSeries(spy, -1);
      const ys = ["2001", "2002", "2003"].map((y, k) => ({ p: y, ret: 0, spy: 100 * (yr(y).slice(-1)[0][1] / (k ? yr(String(2000 + k)).slice(-1)[0][1] : spy[0][1]) - 1) }));
      const end = eraPoints(ys, b).slice(-1)[0][1], chart = 1 / (b.slice(-1)[0][1] / b[0][1]);
      let m = 1; ys.forEach(y => { m *= 1 - y.spy / 100; });
      return [Math.abs(end - chart) < 1e-9 ? "same" : "chart " + chart + " vs " + end, Math.abs(end - 1 / m) > 0.01 ? "differs" : "equal"].join(" "); })()')"
  expect_eq "#3262 benchSeries: SPY unchanged for a long book; inverted day by day for a short book (100, 110, 99 -> 100, 90, 99: -10 %, then +10 %)" "same|100.00,90.00,99.00" \
    "$(er '(s => [benchSeries(s) === s ? "same" : "copy", benchSeries(s, -1).map(r => r[1].toFixed(2)).join(",")].join("|"))([["a", 100], ["b", 110], ["c", 99]])')"
  expect_eq "#3262 regimeText: a long book's cash in a rising market is a miss; a short book's is protection" \
    "in cash while the market rose|held up while the market rose|shorts lost more than the market rose" \
    "$(er '[regimeText("UP", 2, 20, 10), regimeText("UP", -2, -20, 10, -1), regimeText("UP", -30, -20, 80, -1)].map(s => s.split(" (")[0]).join("|")')"
  expect_eq "#3262 regimeText: a short book in a decline led, sat in cash, or lagged; the text names inverted SPY and % short" \
    "shorts led the decline|in cash through the decline|shorts lagged the decline|yes" \
    "$(er '[regimeText("DOWN", 25, 20, 80, -1), regimeText("DOWN", 2, 20, 10, -1), regimeText("DOWN", 8, 20, 80, -1)].map(s => s.split(" (")[0]).concat(/DOWN days: \+25\.0% vs inverted SPY \+20\.0% at 80% short/.test(regimeText("DOWN", 25, 20, 80, -1)) ? "yes" : "no").join("|")')"
  expect_eq "#3262 regimeText: the long wording is unchanged (UP lagged at 62 %, DOWN rebounds, MIXED)" \
    "holdings lagged while the market rose (UP days: +1.0% vs SPY +9.0% at 62% invested) — not an exposure effect|in cash through rebounds|behind in transition weeks" \
    "$(er '[regimeText("UP", 1, 9, 62), regimeText("DOWN", 1, 9, 20).split(" (")[0], regimeText("MIXED", 1, 9, 20).split(" (")[0]].join("|")')"
else
  echo "SKIP: review_pack #3262 era cases need node"
fi
expect_eq "#3262 eras wiring: renderSignals reads eraPoints / benchSeries / regimeText with the book's dir; the heading names the benchmark" "1 1 2 1" \
  "$(sed -n '/^function renderSignals(/,/^}/p' "$S/index.html" | grep -c 'const pts = eraPoints(ys, shortBook ? bench : null);') $(sed -n '/^function renderSignals(/,/^}/p' "$S/index.html" | grep -c 'bench = benchSeries(spy, dir)') $(sed -n '/^function renderSignals(/,/^}/p' "$S/index.html" | grep -o 'regimeText(r.key2\{0,1\}, x2\{0,1\}.s, x2\{0,1\}.m, x2\{0,1\}.expo, dir)' | wc -l | tr -d ' ') $(grep -c "\$('#eras-h').textContent = \`Eras vs \${BL}\`" "$S/index.html")"
expect_eq "#3262 raw breach: the late-stop card says it reads raw bars, split-corrected" 1 "$(grep -c 'Read on raw bars against the raw stop, moved only by a split since the entry' "$S/index.html")"
# #3262 QC follow-ups on #3281 and the #3214 first comment: plurals, dividends without the column, a Friday
# exit, the -dirty stamp, the stacked conformance panel and the unscrolled capture.
if command -v node >/dev/null 2>&1; then
  PLF="$(sed -n -e '/^const fmt = /p' -e '/^const usdk = /p' -e '/^const MARGIN_CHURN_PRICE/p' -e '/^function marginChurnLine(/,/^}/p' -e '/^function noBarFillLine(/,/^}/p' -e '/^function realisedDivs(/,/^}/p' -e '/^function realisedTotalNote(/,/^}/p' "$S/index.html")"
  pl() { node -e "$PLF
console.log($1)"; }
  expect_eq "#3262 plurals: no-bar fills 1 / 2 and V16 fallback exits 1 / 68 agree with their counts" \
    "1 trade has|2 trades have|1 fallback exit in all|68 fallback exits in all" \
    "$(pl '[noBarFillLine(1, "PASS"), noBarFillLine(2, "PASS")].map(s => s.match(/\d+ trades? ha(s|ve)/)[0]).concat([1, 68].map(v => marginChurnLine({ fires: true, low: 5, calls: 6, syms: 2, repeat: 1, pnl: -1e3 }, v, []).match(/\d+ fallback exits? in all/)[0])).join("|")')"
  expect_eq "#3262 realisedDivs: the trade rows when trades.csv has the column (a 0 is still the column); the run's DividendIncomeTotal when every row is null" \
    '[{"v":450,"src":"rows"},{"v":0,"src":"rows"},{"v":1230000,"src":"run"},{"v":0,"src":"run"}]' \
    "$(pl 'JSON.stringify([realisedDivs([{ div: 450 }, { div: 0 }], { dividendincometotal: 9 }), realisedDivs([{ div: 0 }], { dividendincometotal: 9 }), realisedDivs([{ div: null }, {}], { dividendincometotal: 1230000 }), realisedDivs([{ div: null }], {})])')"
  expect_eq "#3262 realisedTotalNote: a run total says where it came from" yes \
    "$(pl '/\$1\.23M of dividends \(the run.s DividendIncomeTotal: this trades.csv has no dividends_received column\)/.test(realisedTotalNote(1230000, 914000, "run")) ? "yes" : "no"')"
else
  echo "SKIP: review_pack #3262 plural / dividend cases need node"
fi
expect_eq "#3262 wiring: the overview reads noBarFillLine and realisedDivs" "1 1" \
  "$(grep -c '^    noBarFillLine(wk.length, ' "$S/index.html") $(grep -c 'realisedTotalNote(dv.v, inv.metrics.cashinteresttotal, dv.src))(realisedDivs(t, inv.metrics))' "$S/index.html")"
# Friday EXIT: the exit week is the screen strictly before the exit too. G1 exits Fri 2020-01-24, the day of a
# Bullish screen that runs after the close -> Bearish (01-17); with <= it would read Bullish.
FX="$TMP/friexit"; mkdir -p "$FX"; cp -R "$FR/run" "$FX/run"; rm -f "$FX/run/open_positions.csv"
{ head -1 "$FIX/run/trades.csv"
  echo "AAA,LONG,2020-01-08,2020-01-24,12,100.00,100.00,10,0.00,0.00,,,laggard_rotation,Stage2,2.5000,0.0400,non_stop_exit,,100,AAA-G1,,,0"; } > "$FX/run/trades.csv"
rc=0
sh "$SCRIPT" --no-container --data-dir "$FIX/data" --out "$FX/pack" r0="$FX/run/" >"$FX/log" 2>&1 || rc=$?
expect_eq "#3262 Friday exit: builds; the exit reads the screen before it (Bearish 01-17), entry the 01-03 screen" "0 Bullish Bearish" \
  "$rc $(jq -r '.[0] | "\(.mE) \(.mX)"' "$FX/pack/site/data/r0_trades.json")"
# pack_sha: HEAD, HEAD-dirty when the pack code is edited, HEAD again when only another path is, unknown outside git
. "$ROOT/dev/lib/review_pack/pack_sha.sh"
GR="$TMP/gitrepo"; mkdir -p "$GR/dev/lib/review_pack" "$GR/other"
( cd "$GR" && git init -q && echo a > dev/lib/review_pack/x && echo a > other/y && git add . &&
  git -c user.name=t -c user.email=t@t commit -qm init ) >/dev/null 2>&1
h=$(git -C "$GR" rev-parse --short=9 HEAD 2>/dev/null || echo none)
c1=$(pack_sha "$GR"); echo b > "$GR/other/y"; c2=$(pack_sha "$GR"); echo b > "$GR/dev/lib/review_pack/x"; c3=$(pack_sha "$GR")
expect_eq "#3262 pack_sha: clean, another path edited, the pack code edited, not a git checkout" "$h|$h|$h-dirty|unknown" "$c1|$c2|$c3|$(pack_sha "$TMP/nogit-$$")"
expect_eq "#3262 pack_sha: review_pack.sh sources it and stamps the repo's" "1 1" \
  "$(grep -c '^\. "$LIB/pack_sha.sh"$' "$SCRIPT") $(grep -c -- '--arg pack_sha "$(pack_sha "$REPO")"' "$SCRIPT")"
# conformance above the validator, full width: side by side, a long validator list left the table's column blank
expect_eq "#3262 conformance panel: stacked above the validator, not in a grid2 beside it" "1 1 0" \
  "$(grep -c '^  <div class="panel" id="conf-panel">$' "$S/index.html") $(grep -c '^  <div class="panel" id="validator-panel">$' "$S/index.html") $(sed -n '/<section class="view" id="v-surprises"/,/<\/section>/p' "$S/index.html" | grep -c 'class="grid2"')"
# the capture unscrolls every table box but the per-trade one (inline.html from the stub render above)
expect_eq "#3262 render: the capture unscrolls every table box but the per-trade one" 1 \
  "$(grep -c '^<style>.tablebox:not(:has(#t-table)) { max-height: none !important; }</style>$' "$TMP/render-ok/inline.html")"
# #3140: an unowned bar-store symbol, exact volume/return boundaries, splice guard,
# audit evidence vs absent evidence, ownership and the rendered card.
MW="$TMP/missed"; mkdir -p "$MW/data/W/N/WIN" "$MW/run"
cp "$FIX/missed_winner.csv" "$MW/data/W/N/WIN/data.csv"
printf 'date,equity\n2019-01-04,100000\n2019-10-11,100000\n' > "$MW/run/equity_curve.csv"
cat > "$MW/run/trade_audit.sexp" <<'AUDIT'
((audit_records ()) (cascade_summaries
 (((date 2019-08-02) (decisions (((symbol WIN) (side Long) (outcome Placed))
 ((symbol SKIP) (side Long) (outcome (Skipped Insufficient_cash)))
 ((symbol SHORT) (side Short) (outcome Placed)))))
 ((date 2019-08-09) (decisions ())) ((date 2019-08-16)))))
AUDIT
sh "$ROOT/dev/lib/review_pack/missed_winners.sh" "$MW/data" "$MW/run" > "$MW/result.json"
expect_eq "#3140 scan: unowned WIN found, boundary 2x volume, 150% forward weekly close" '1 WIN 2019-08-02 150 2 2019-10-11' \
  "$(jq -r '"\(.symbols) \(.episodes[0].sym) \(.episodes[0].d) \(.episodes[0].forward+0) \(.episodes[0].vr+0) \(.episodes[0].peak)"' "$MW/result.json")"
expect_eq "#3140 audit: long tickets/skips, zero-ticket week, old week lacks decisions" 'D|2019-08-02|WIN|Placed;D|2019-08-02|SKIP|Skipped Insufficient_cash;W|2019-08-02|1|1;W|2019-08-09|0|1;W|2019-08-16|0|0' \
  "$(jq -r '.audit|map(join("|"))|join(";")' "$MW/result.json")"
# Compact and pretty audit layouts must agree.
tr '\n' ' ' < "$MW/run/trade_audit.sexp" > "$MW/compact.sexp"
expect_eq "#3140 audit: whitespace does not change evidence" "$(awk -f "$ROOT/dev/lib/review_pack/missed_audit.awk" "$MW/run/trade_audit.sexp")" \
  "$(awk -f "$ROOT/dev/lib/review_pack/missed_audit.awk" "$MW/compact.sexp")"
for mode in lowvol illiquid splice cutoff exact breakout belowma fallingma warmup jumpup jumpdown; do
  awk -F, -v OFS=, -v mode="$mode" 'NR>1 {
    if(mode=="lowvol" && $1=="2019-08-02") $7=199999
    if(mode=="illiquid") $7=$7/100
    if(mode=="splice" && $1=="2019-08-09") $5=$6=400
    if(mode=="exact" && $5>160) $2=$3=$4=$5=$6=160
    # Signal is row 32 (week 30). Isolate each qualifier while all others pass.
    i=NR-2
    if(mode=="breakout" && i==29) $3=80
    if(mode=="belowma") {
      c=(i==0?80:i==1?110:i==2?106:i==3?103:i<30?99.99:100+(i-30)*12)
      $2=$3=$4=$5=$6=c
    }
    if(mode=="fallingma") {
      c=(i==0?600:i==1?400:i==2?250:i==3?150:i<30?90:100+(i-30)*12)
      $2=$3=$4=$5=$6=c
    }
    # A jump exactly 20 weeks before the signal: future path stays continuous.
    if(mode=="warmup" && i<10) for(j=2;j<=6;j++) $j=$j/2
    if(mode=="jumpup" && i==31) $2=$3=$4=$5=$6=120
    if(mode=="jumpdown" && i>=31) $2=$3=$4=$5=$6=40*1.2^(i-31)
  } { print }' "$FIX/missed_winner.csv" > "$MW/$mode.csv"
  last=2019-12-31; [ "$mode" != cutoff ] || last=2019-09-06
  n=$(awk -v sym=WIN -v first=2019-01-01 -v last="$last" -f "$ROOT/dev/lib/review_pack/missed_winners.awk" "$MW/$mode.csv" | wc -l | tr -d ' ')
  want=0; [ "$mode" != exact ] || want=1
  expect_eq "#3140 scan: $mode boundary" "$want" "$n"
done
rm "$MW/run/trade_audit.sexp"
sh "$ROOT/dev/lib/review_pack/missed_winners.sh" "$MW/data" "$MW/run" > "$MW/noaudit.json"
expect_eq "#3140 no audit: no inferred zero-ticket weeks" 0 "$(jq '.audit|length' "$MW/noaudit.json")"
expect_eq "#3140 pack pipeline publishes missed inputs and renders section" 'true 1' \
  "$(jq -r 'has("episodes") and has("symbols") and has("audit")' "$S/data/r0_missed.json") $(grep -c 'id="missed-years"' "$S/index.html")"
if command -v node >/dev/null 2>&1; then
  { grep '^function isoWeek(' "$S/index.html"
    sed -n '/^function missedWinners(/,/^}/p' "$S/index.html"
    sed -n '/^function renderMissedWinners(/,/^}/p' "$S/index.html"
    grep '^const tbl =' "$S/index.html"
    cat <<'JS'
const assert = require('assert');
const e = (sym, forward=150) => ({sym,d:'2019-08-02',peak:'2019-10-11',forward});
const data = {symbols:12, episodes:['RODE','PART','CUT','TICKET','SKIP','BEAR','ZERO','TOP','UNKNOWN'].map(s=>e(s)), audit:[['W','2019-08-02','1','1'],['D','2019-08-02','TICKET','Placed'],['D','2019-08-02','SKIP','Skipped Insufficient_cash']]};
const trades = [['RODE',80],['PART',10],['CUT',-5]].map(([sym,pct])=>({sym,side:'LONG',ed:'2019-08-05',xd:'2019-10-10',pct}));
const nav = [['2019-08-02',100000,20]];
let r=missedWinners(data,trades,{rows:[]},[],nav);
assert.deepStrictEqual(r.episodes.slice(0,5).map(e=>e.reason),['rode','partial','cut','ticket placed','logged skip: Insufficient_cash']);
assert.strictEqual(r.episodes[7].reason,'not in recorded top-N');
assert.strictEqual(r.buckets[0].owned,3);
assert.strictEqual(r.years[0].top.length,5);
assert.strictEqual(missedWinners({episodes:[e('BEAR')],audit:[]},[],{},[['2019-08-02','Bearish']],nav).episodes[0].reason,'macro Bearish');
const zero={episodes:[e('ZERO')], audit:Array.from({length:10},(_,i)=>['W',new Date(Date.UTC(2019,7,2+7*i)).toISOString().slice(0,10),'0','1'])};
r=missedWinners(zero,[],{},[],nav);
assert.strictEqual(r.years[0].zero,10); assert.strictEqual(r.episodes[0].reason,'zero-ticket week (<25% invested)');
assert.strictEqual(missedWinners(zero,[],{},[],[['2019-08-02',100000,60]]).years[0].zero,0, '60% invested is not below 50%');
assert.strictEqual(missedWinners(zero,[],{},[],[['2019-08-02',100000,50]]).years[0].zero,0, 'exactly 50% is excluded');
assert.strictEqual(missedWinners(zero,[],{},[],[['2019-08-02',100000,49.99]]).years[0].zero,10, 'just below 50% is counted');
const thursday={episodes:[{...e('TICKET'),d:'2019-08-01'},{...e('SKIP'),d:'2019-08-01'}],audit:data.audit};
assert.deepStrictEqual(missedWinners(thursday,[],{},[['2019-07-26','Bearish']],nav).episodes.map(e=>e.reason),['ticket placed','logged skip: Insufficient_cash'], 'Thursday bars join Friday decisions');
const holiday={episodes:[{...e('HOLIDAY'),d:'2020-04-09'}],audit:[['W','2020-04-10','0','1']]};
assert.strictEqual(missedWinners(holiday,[],{},[['2020-04-03','Bearish'],['2020-04-10','Bullish']],[['2020-04-09',100000,20]]).episodes[0].reason,'zero-ticket week (<25% invested)', 'same-week macro beats the prior week on a holiday');
const boundary={episodes:[{...e('NEWYEAR'),d:'2019-12-31'}],audit:[['D','2020-01-03','NEWYEAR','Placed']]};
assert.strictEqual(missedWinners(boundary,[],{},[],[]).episodes[0].reason,'ticket placed', 'week crosses calendar year');
boundary.episodes[0].d='2020-01-06';
assert.strictEqual(missedWinners(boundary,[],{},[],[]).episodes[0].reason,'unknown (screen evidence absent)', 'adjacent week is not joined');

assert.strictEqual(missedWinners({episodes:[e('UNKNOWN')],audit:[]},[],{},[],nav).episodes[0].reason,'unknown (screen evidence absent)');
assert.strictEqual(missedWinners({episodes:[e('SHORT')],audit:[]},[{sym:'SHORT',side:'SHORT',ed:'2019-08-02',xd:'2019-10-11',pct:100}],{},[],nav).episodes[0].owned,false);
assert.strictEqual(missedWinners({episodes:[],audit:[]},[],{},[],nav).buckets[0].n,0);
const elements={}; const $=id=>elements[id]||(elements[id]={}); const CH=()=>0, fmt=(x,n)=>x.toFixed(n);
const D={missed:[zero], trades:[[]], open:[{}], macro:[], nav:[nav]};
renderMissedWinners(); assert(elements['#missed-years'].innerHTML.includes('<tr><td>2019</td>')); assert(elements['#missed-years'].innerHTML.includes('⚑')); assert(elements['#missed-buckets'].innerHTML.includes('100–200%'));
D.missed=[null]; renderMissedWinners(); assert(elements['#missed-note'].textContent.includes('unavailable'));
console.log('OK');
JS
  } > "$MW/ui.js"
  expect_eq "#3140 browser: reasons, ownership, buckets, year summary and rendered card" OK "$(node "$MW/ui.js")"
fi

printf '%s: %d passed, %d failed\n' "review_pack_test" "$PASS" "$FAILED"
[ "$FAILED" = 0 ]
