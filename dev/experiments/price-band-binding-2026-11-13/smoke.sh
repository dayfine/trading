#!/bin/sh
# price-band-binding-2026-11-13 smoke: plumbing only. sp500 is a test fixture here, never a measurement
# (.claude/rules/universe-discipline.md); nothing in results/smoke/ bears on the README's rules.
#
# Runs INSIDE the dev container from the checkout root, after `dune build trading/backtest/scenarios/scenario_runner.exe`:
#   docker exec -w /workspaces/trading-1/<tree> trading-1-dev sh dev/experiments/price-band-binding-2026-11-13/smoke.sh
# 1. specs/smoke-sp500.sexp (the record config, sp500, 2019-07..2021-06) twice in CSV mode on the committed test_data:
#    with --emit-candidates and without; trades.csv must match (the tripwire, on this window).
# 2. read/read.sh on the emitting run, EVENTS=surfaced (screen events of the names the run screened).
# Writes results/smoke/: the read's aggregate tables plus smoke.txt (tripwire, wall, peak RSS). Scratch: .sweep-output/.
set -u
ROOT=$(pwd); EXP=dev/experiments/price-band-binding-2026-11-13; S=$ROOT/.sweep-output/pbb-smoke
RUNNER=$ROOT/trading/_build/default/trading/backtest/scenarios/scenario_runner.exe
[ -x "$RUNNER" ] || { echo "build the runner first" >&2; exit 2; }
rm -rf "$S"; mkdir -p "$S"
cell() { # $1 label, $2 extra flag -> prints the scenario dir
  mkdir -p "$S/spec-$1"; cp "$ROOT/$EXP/specs/smoke-sp500.sexp" "$S/spec-$1/"; t0=$(date +%s)
  (cd "$ROOT/trading" && TRADING_DATA_DIR=$ROOT/trading/test_data TRADING_PATH_SEED_SALT=0 \
    /usr/bin/time -f 'peak_rss_kb=%M' -o "$S/$1.rss" "$RUNNER" --dir "$S/spec-$1" \
    --fixtures-root "$ROOT/trading/test_data/backtest_scenarios" --no-emit-all-eligible $2 --parallel 1 > "$S/$1.log" 2>&1)
  echo "$1 wall $(( $(date +%s) - t0 )) s, $(tail -1 "$S/$1.rss")" >> "$S/smoke.txt"
  echo "$(grep 'Output root' "$S/$1.log" | tail -1 | sed 's/.*: //')/pbb-smoke-sp500"
}
E=$(cell emit --emit-candidates); N=$(cell plain "")
a=$(md5sum "$E/trades.csv" | cut -c1-32); b=$(md5sum "$N/trades.csv" | cut -c1-32)
[ "$a" = "$b" ] && t=MATCH || t=MISMATCH
echo "tripwire on the smoke window: trades.csv md5 with --emit-candidates $a, without $b: $t ($(wc -l < "$E/trades.csv" | tr -d ' ') lines)" >> "$S/smoke.txt"
echo "candidates.sexp $(wc -c < "$E/candidates.sexp" | tr -d ' ') bytes, trade_audit.sexp $(wc -c < "$E/trade_audit.sexp" | tr -d ' ') bytes" >> "$S/smoke.txt"
t0=$(date +%s)
CANDS=$E/candidates.sexp AUDIT=$E/trade_audit.sexp TRADES=$E/trades.csv OPENPOS=$E/open_positions.csv \
  DATA=$ROOT/trading/test_data PIT=$ROOT/trading/test_data/backtest_scenarios/pit-v12/composition \
  OUT=$S/read WORK=$S/work EVENTS=surfaced SEED=0 CAP=20 sh "$ROOT/$EXP/read/read.sh" 2> "$S/read.log"
rc=$?
echo "read exit $rc, wall $(( $(date +%s) - t0 )) s" >> "$S/smoke.txt"
# Negative control: the self-check with the wrong tie seed must fail (it has power), with the right one pass.
for seed in 1 0; do
  awk -F'\t' -v SEED=$seed -v CAP=20 -v MODE=check -v FRIDAYS=/dev/null -v SWAPS=/dev/null -v SELF="$S/neg-$seed.txt" \
    -v GATES=/dev/null -v N_ENTRIES=0 -f "$ROOT/$EXP/read/lib/rank.awk" -f "$ROOT/$EXP/read/lib/bind.awk" \
    "$S/work/weeks.tsv" "$S/work/walk.tsv" "$S/work/pool.tsv"
  echo "self-check with SEED=$seed: exit $? | $(grep -h '^SC[12] (' "$S/neg-$seed.txt" | tr '\n' ' ')" >> "$S/smoke.txt"
done
mkdir -p "$ROOT/$EXP/results/smoke"; rm -f "$ROOT/$EXP/results/smoke"/*
cp "$S/smoke.txt" "$S/read"/*.tsv "$ROOT/$EXP/results/smoke/"
for f in "$S/read"/*.txt; do   # every table carries the banner: the smoke exercises the code and bears on no rule
  { echo "# SMOKE: sp500, 2019-07..2021-06, plumbing only. No verdict; sp500 is a fixture (README §Smoke)."; cat "$f"; } \
    > "$ROOT/$EXP/results/smoke/$(basename "$f")"
done
cat "$S/smoke.txt"
