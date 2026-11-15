#!/bin/sh
# gate-funnel-2026-11-15 smoke: plumbing and cost only. sp500 is a test fixture here, never a measurement
# (.claude/rules/universe-discipline.md); nothing in results/smoke/ bears on the README's rules.
#
# Runs INSIDE the dev container from the root of a checkout of the top-N view's build (#3626's branch
# feat/candidate-log-shadow-walk-emit) with this directory copied in, after
# `dune build trading/backtest/scenarios/scenario_runner.exe`:
#   docker exec -w /workspaces/trading-1/<tree> -e BUILD_SHA=<sha> trading-1-dev sh dev/experiments/gate-funnel-2026-11-15/smoke.sh [cost]
#   (BUILD_SHA is printed only: params.sexp's code_version comes from the enclosing git checkout, not the jj workspace)
# Default mode (plumbing, sp500, CSV mode on the committed test_data):
#   1. specs/smoke-sp500.sexp (the record config, sp500, 2019-07..2021-06) with --emit-candidates and without;
#      trades.csv must match (the tripwire, on this window).
#   2. read/read.sh on the emitting run (EVENTS=surfaced, STORE_END=2026-06-26 as in the cell).
#   3. Negative control: the self-check with the wrong tie seed (1) must fail SK1, the right one pass.
#   4. read/rules_check.sh (fabricated gate lines through every branch of both rules).
# `cost` mode (top-3000 cost probe, timings only): the cell's spec pb-S-k0 cut to 2000-01-01..COST_END (default
#   2000-03-31: 65 weekly cycles with the 364-day warm-up, which screens too) against the container's warehouse WH (default
#   /tmp/snap_top3000_pit_v12wk, the source of R2 v12wk-9236). Arms, in order, from COST_ARMS (default "plain emit"):
#   plain (this build, no flag), emit (this build, --emit-candidates: trace + top-N view), base (BASE_RUNNER, a build
#   without the top-N view, with --emit-candidates: the trace alone). Per arm: wall, peak RSS, user and system CPU,
#   snapshot-cache hits; the trades.csv md5 of every arm; the emit arm's candidates.sexp size and cut rows. Its returns
#   are not read. Each run appends one section to results/smoke/cost.txt.
# Writes results/smoke/: the read's aggregate tables (OUT) plus smoke.txt (default) or cost.txt (cost), every file with
# the banner. The read's PRIV tables and WORK stay in .sweep-output/. Scratch: .sweep-output/gf-smoke.
set -u
ROOT=$(pwd); EXP=dev/experiments/gate-funnel-2026-11-15; S=$ROOT/.sweep-output/gf-smoke; MODE=${1:-plumbing}
RUNNER=$ROOT/trading/_build/default/trading/backtest/scenarios/scenario_runner.exe
PL=$ROOT/dev/experiments/price-band-binding-2026-11-13/read/lib
[ -x "$RUNNER" ] || { echo "build the runner first" >&2; exit 2; }
R=$ROOT/$EXP/results/smoke; mkdir -p "$R"
BANNER_COST="# SMOKE: top-3000 cost probe, one quarter of 2000, timings and counts only. No verdict (README §Smoke)."
banner() { # $1 file -> results/smoke/<name> with the banner
  { echo "# SMOKE: $2 No verdict (README §Smoke)."; cat "$1"; } > "$R/$(basename "$1")"
}
cell() { # $1 label, $2 spec file, $3 scenario name, $4 extra runner args -> prints the scenario dir
  mkdir -p "$S/spec-$1"; cp "$2" "$S/spec-$1/"; t0=$(date +%s)
  (cd "$ROOT/trading" && TRADING_DATA_DIR=$ROOT/trading/test_data TRADING_PATH_SEED_SALT=0 SNAPSHOT_CACHE_MB=1024 \
    SNAPSHOT_MAX_MMAP_HANDLES=12000 /usr/bin/time -f 'peak_rss_kb=%M user_s=%U sys_s=%S' -o "$S/$1.rss" "$RUNNER" --dir "$S/spec-$1" \
    --fixtures-root "$ROOT/trading/test_data/backtest_scenarios" --no-emit-all-eligible $4 --parallel 1 > "$S/$1.log" 2>&1)
  echo "$1 wall $(( $(date +%s) - t0 )) s, $(tail -1 "$S/$1.rss")" >> "$S/$MODE.txt"
  echo "$(grep 'Output root' "$S/$1.log" | tail -1 | sed 's/.*: //')/$3"
}
md5() { md5sum "$1" | cut -c1-32; }

if [ "$MODE" = cost ]; then
  WH=${WH:-/tmp/snap_top3000_pit_v12wk}; S=$S/cost; rm -rf "$S"; mkdir -p "$S"; ARMS=${COST_ARMS:-plain emit}; END=${COST_END:-2000-03-31}
  sed "s/(period ((start_date [0-9-]*) (end_date [0-9-]*)))/(period ((start_date 2000-01-01) (end_date $END)))/" \
    "$ROOT/dev/experiments/price-band-tiebreak-2026-11-13/specs/pb-S-k0.sexp" > "$S/pb-S-k0.sexp"
  echo "# cost probe: pb-S-k0 cut to 2000-01-01..$END, top-3000 PIT v12, WH=$WH, TD=committed test_data, $(date -u '+%Y-%m-%d %H:%M')Z, build ${BUILD_SHA:-unrecorded}; arms in order: $ARMS${BASE_RUNNER:+; base = $BASE_RUNNER at ${BASE_SHA:-unrecorded}}" >> "$S/cost.txt"
  # Order matters for wall time: the first run after the page cache was cleared pays for the warehouse's mmap faults.
  # CPU time does not, which is why it is recorded.
  first=""
  for a in $ARMS; do
    case "$a" in
      plain) d=$(cell plain "$S/pb-S-k0.sexp" pb-S-k0 "--snapshot-dir $WH") ;;
      emit) d=$(cell emit "$S/pb-S-k0.sexp" pb-S-k0 "--snapshot-dir $WH --emit-candidates"); E=$d ;;
      base) d=$(RUNNER=${BASE_RUNNER:?BASE_RUNNER unset}; cell base "$S/pb-S-k0.sexp" pb-S-k0 "--snapshot-dir $WH --emit-candidates") ;;
      *) echo "unknown arm $a" >&2; exit 2 ;;
    esac
    m=$(md5 "$d/trades.csv"); [ -z "$first" ] && first=$m
    echo "$a: trades.csv md5 $m ($([ "$m" = "$first" ] && echo same as the first arm || echo DIFFERS from the first arm)), snapshot cache $(grep -oE 'hits=[0-9]+ misses=[0-9]+' "$S/$a.log" | tail -1), $(grep -oE 'n_symbols=[0-9]+ ' "$S/$a.log" | tail -1)$(grep -oE 'n_symbols_absent=[0-9]+' "$S/$a.log" | tail -1)" >> "$S/cost.txt"
  done
  if [ -n "${E:-}" ]; then
    echo "emit: candidates.sexp $(wc -c < "$E/candidates.sexp" | tr -d ' ') bytes" >> "$S/cost.txt"
    tr '()' '\n\n' < "$E/candidates.sexp" | awk -v WEEKS="$S/weeks.tsv" -f "$ROOT/$EXP/read/lib/cands.awk" |
      awk -F'\t' '{ n[$3]++ } $3 == "Dropped_at_top_n" { s[$9]++ } END {
        printf "emit, Long rows in the window by outcome:"; for (k in n) printf " %s %d", k, n[k]; print ""
        printf "emit, cut rows in the window by shadow (one stop check each):"; for (k in s) printf " %s %d", k, s[k]; print "" }' >> "$S/cost.txt"
    echo "emit: screened Fridays in the window $(wc -l < "$S/weeks.tsv" | tr -d ' '), with Long rows $(awk -F'\t' '$2 > 0' "$S/weeks.tsv" | wc -l | tr -d ' ') (the warm-up's 52 Fridays are screened too, but not written)" >> "$S/cost.txt"
  fi
  { [ -s "$R/cost.txt" ] || echo "$BANNER_COST"; echo; cat "$S/cost.txt"; } >> "$R/cost.txt"
  cat "$S/cost.txt"; exit 0
fi

rm -rf "$S"; mkdir -p "$S"; find "$R" -type f ! -name cost.txt -exec rm -f {} +
echo "# plumbing smoke: specs/smoke-sp500.sexp, CSV mode on the committed test_data, $(date -u '+%Y-%m-%d %H:%M')Z, build ${BUILD_SHA:-unrecorded}" >> "$S/$MODE.txt"
E=$(cell emit "$ROOT/$EXP/specs/smoke-sp500.sexp" gf-smoke-sp500 --emit-candidates); N=$(cell plain "$ROOT/$EXP/specs/smoke-sp500.sexp" gf-smoke-sp500 "")
a=$(md5 "$E/trades.csv"); b=$(md5 "$N/trades.csv"); [ "$a" = "$b" ] && t=MATCH || t=MISMATCH
echo "tripwire on the smoke window: trades.csv md5 with --emit-candidates $a, without $b: $t ($(wc -l < "$E/trades.csv" | tr -d ' ') lines)" >> "$S/$MODE.txt"
echo "candidates.sexp $(wc -c < "$E/candidates.sexp" | tr -d ' ') bytes, trade_audit.sexp $(wc -c < "$E/trade_audit.sexp" | tr -d ' ') bytes" >> "$S/$MODE.txt"
t0=$(date +%s)
CANDS=$E/candidates.sexp AUDIT=$E/trade_audit.sexp TRADES=$E/trades.csv OPENPOS=$E/open_positions.csv EQUITY=$E/equity_curve.csv \
  ACTUAL=$E/actual.sexp PARAMS=$E/params.sexp DATA=$ROOT/trading/test_data PIT=$ROOT/trading/test_data/backtest_scenarios/pit-v12/composition \
  OUT=$S/read PRIV=$S/priv WORK=$S/work EVENTS=surfaced STORE_END=2026-06-26 SEED=0 CAP=20 sh "$ROOT/$EXP/read/read.sh" 2> "$S/read.log"
echo "read exit $?, wall $(( $(date +%s) - t0 )) s; private tables: $(cat "$S/work/priv.txt" | tr '\n' ' ')" >> "$S/$MODE.txt"
grep -h '^SK[1-4] \|^long_resting' "$S/read/selfcheck.txt" | cut -c1-160 >> "$S/$MODE.txt"
grep -h '^m (\|^open Fridays\|^total:\|^path-aware' "$S/read/gate_before_cap.txt" >> "$S/$MODE.txt"
grep -h '^Rule [12] (' "$S/read/rules.txt" >> "$S/$MODE.txt"
# 3. Negative control: the self-check must have power against a wrong tie seed.
for seed in 1 0; do
  awk -F'\t' -v SEED=$seed -v CAP=20 -v OPEN=/dev/null -f "$PL/rank.awk" -f "$ROOT/$EXP/read/lib/check.awk" \
    "$S/work/weeks.tsv" "$S/work/cs.tsv" "$S/work/walk.tsv" "$S/work/rows.tsv" > "$S/neg-$seed.txt"
  echo "self-check with SEED=$seed: exit $? | $(grep -h '^SK1 (' "$S/neg-$seed.txt" | sed 's/ (rank.*): / /')" >> "$S/$MODE.txt"
done
# 4. The rule ladders on fabricated inputs.
sh "$ROOT/$EXP/read/rules_check.sh" > "$S/rules_check.txt"; echo "rules_check exit $?" >> "$S/$MODE.txt"
for f in "$S/$MODE.txt" "$S/rules_check.txt" "$S/read"/*.txt "$S/read"/*.tsv; do
  banner "$f" "sp500, 2019-07..2021-06, plumbing only; sp500 is a fixture."
done
mv "$R/plumbing.txt" "$R/smoke.txt"
cat "$R/smoke.txt"
