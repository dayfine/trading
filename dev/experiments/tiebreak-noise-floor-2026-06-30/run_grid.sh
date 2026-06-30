#!/usr/bin/env bash
set -uo pipefail
cd /workspaces/trading-1/trading; eval "$(opam env)"
EXP=/workspaces/trading-1/dev/experiments/tiebreak-noise-floor-2026-06-30
SNAP=/workspaces/trading-1/dev/data/snapshots
FIX=/workspaces/trading-1/trading/test_data
export TRADING_DATA_DIR=/workspaces/trading-1/data
RUN=trading/backtest/walk_forward/bin/walk_forward_runner.exe
run_cell(){ local c="$1" p="$2"; echo "=== [$(date +%H:%M:%S)] $c p=$p START ==="
  dune exec --no-build "$RUN" -- --spec "$EXP/spec_${c}.sexp" --out-dir "$EXP/out_${c}" \
    --fixtures-root "$FIX" --snapshot-dir "$SNAP/wfcv-${c}-1998" --parallel "$p"
  echo "=== [$(date +%H:%M:%S)] $c DONE exit=$? ==="; }
run_cell top500 4
run_cell top1000 3
echo "=== ALL CELLS COMPLETE [$(date +%H:%M:%S)] ==="
