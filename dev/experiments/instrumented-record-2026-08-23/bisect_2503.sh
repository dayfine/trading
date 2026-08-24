#!/bin/sh
# #2503 bisect driver — 6-month probes (2000-01-01..2000-06-30) at three builds.
# Early trades depend only on past data, so truncation preserves them; the
# divergence is visible by 2000-01-29, so 6mo discriminates.
# Usage: sh bisect_2503.sh  (sequential; ~20-30 min/build incl. cold compile)
set -eu
REPO=/Users/difan/Projects/trading-1
C=trading-1-dev
OUT=/tmp/sweeps/bisect-2503
LOCK=/tmp/bisect-2503.lockdir
if ! mkdir "$LOCK" 2>/dev/null; then echo "already running; abort" >&2; exit 1; fi
trap 'rmdir "$LOCK" 2>/dev/null' EXIT

for SHA in e64f8655b 4141beda5 b128b1d9e; do
  WT_REL=.claude/worktrees/bisect-$SHA
  WT="$REPO/$WT_REL"
  echo "[$(date '+%F %T')] === $SHA ==="
  [ -d "$WT" ] || git -C "$REPO" worktree add --detach "$WT_REL" "$SHA" -q
  STAGE="$WT/trading/test_data/backtest_scenarios/bisect-staging"
  mkdir -p "$STAGE"
  # truncated spec: instr-null with end_date 2000-06-30
  sed -e 's/(end_date 2026-06-26)/(end_date 2000-06-30)/' \
      -e 's/(name "instr-null")/(name "probe6mo")/' \
      "$REPO/dev/experiments/instrumented-record-2026-08-23/specs/instr-null.sexp" > "$STAGE/probe6mo.sexp"
  docker exec "$C" bash -c "cd /workspaces/trading-1/$WT_REL/trading && eval \$(opam env) && dune build trading/backtest/scenarios/scenario_runner.exe" \
    || docker exec "$C" bash -c "cd /workspaces/trading-1/$WT_REL/trading && eval \$(opam env) && dune build trading/backtest/scenarios/scenario_runner.exe" \
    || { echo "build failed at $SHA"; continue; }
  docker exec "$C" bash -c "
    mkdir -p $OUT &&
    cd /workspaces/trading-1/$WT_REL/trading && eval \$(opam env) &&
    SNAPSHOT_CACHE_MB=1024 TRADING_DATA_DIR=/workspaces/trading-1/$WT_REL/trading/test_data \
    dune exec --no-build trading/backtest/scenarios/scenario_runner.exe -- \
      --dir /workspaces/trading-1/$WT_REL/trading/test_data/backtest_scenarios/bisect-staging \
      --snapshot-dir /tmp/snap_top3000_dedup_v5thin_adj \
      --parallel 1 --no-emit-all-eligible \
      > $OUT/$SHA.log 2>&1" || echo "run failed at $SHA (see log)"
  root=$(docker exec "$C" bash -c "grep -h 'Output root' $OUT/$SHA.log | tail -1 | sed 's/.*: //'")
  docker exec "$C" bash -c "cp $root/probe6mo/trades.csv $OUT/$SHA-trades.csv 2>/dev/null" || echo "no trades.csv at $SHA"
  echo "[$(date '+%F %T')] $SHA done; trades:"
  docker exec "$C" bash -c "wc -l $OUT/$SHA-trades.csv 2>/dev/null" || true
done
echo "[$(date '+%F %T')] bisect probes complete; compare $OUT/<sha>-trades.csv"
