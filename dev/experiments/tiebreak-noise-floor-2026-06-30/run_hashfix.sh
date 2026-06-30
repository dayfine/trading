#!/usr/bin/env bash
set -uo pipefail
cd /workspaces/trading-1/trading; eval "$(opam env)"
EXP=/workspaces/trading-1/dev/experiments/tiebreak-noise-floor-2026-06-30
SNAP=/workspaces/trading-1/dev/data/snapshots; FIX=/workspaces/trading-1/trading/test_data
export TRADING_DATA_DIR=/workspaces/trading-1/data
RUN=trading/backtest/walk_forward/bin/walk_forward_runner.exe
run(){ local c="$1" p="$2"; echo "=== [$(date +%H:%M:%S)] $c p=$p START ==="
  dune exec --no-build "$RUN" -- --spec "$EXP/spec_${c}_hashfix.sexp" --out-dir "$EXP/out_${c}_hashfix" \
    --fixtures-root "$FIX" --snapshot-dir "$SNAP/wfcv-${c}-1998" --parallel "$p"
  echo "=== [$(date +%H:%M:%S)] $c DONE exit=$? ==="; }
run top500 4
run top1000 3
echo "=== HASHFIX COMPLETE [$(date +%H:%M:%S)] ==="
