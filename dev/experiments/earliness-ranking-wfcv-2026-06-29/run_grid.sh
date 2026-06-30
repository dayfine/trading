#!/usr/bin/env bash
# Earliness-primary candidate-ranking WF-CV breadth grid (Alphabetical vs
# Quality_earliness). Mirrors the #1788 RS-primary grid: top-500/1000/3000
# PIT-1998, 2000-2026, 13 folds (2y non-overlapping), fork-per-fold, snapshot mode.
set -uo pipefail
cd /workspaces/trading-1/trading
eval "$(opam env)"
EXP=/workspaces/trading-1/dev/experiments/earliness-ranking-wfcv-2026-06-29
SNAP=/workspaces/trading-1/dev/data/snapshots
FIX=/workspaces/trading-1/trading/test_data
export TRADING_DATA_DIR=/workspaces/trading-1/data
RUN=trading/backtest/walk_forward/bin/walk_forward_runner.exe

run_cell () {
  local cell="$1" par="$2"
  echo "=== [$(date +%H:%M:%S)] cell=$cell parallel=$par START ==="
  dune exec --no-build "$RUN" -- \
    --spec "$EXP/spec_${cell}.sexp" \
    --out-dir "$EXP/out_${cell}" \
    --fixtures-root "$FIX" \
    --snapshot-dir "$SNAP/wfcv-${cell}-1998" \
    --parallel "$par"
  echo "=== [$(date +%H:%M:%S)] cell=$cell DONE exit=$? ==="
}

run_cell top500 4
run_cell top1000 2
run_cell top3000 1
echo "=== ALL CELLS COMPLETE [$(date +%H:%M:%S)] ==="
