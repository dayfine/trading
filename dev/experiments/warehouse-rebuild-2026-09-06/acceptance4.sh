#!/bin/sh
# Acceptance on the GAP-FILLED 2019 warehouse (_v9gap, rebuild4.sh): rec5y-2019-new salt 0 — V16/V17 + the level vs the survivor-tilted _v7mark cell (42.37% / 175)
#   default) on the rebuilt 2000 warehouse; then the post-run validator; PASS =
#   zero V16 fallback exits, zero V17 stale entries, STMP exits `delisted` at ~329.61.
# Step 2: salted record re-base — salts 0-2 of rec26y on the rebuilt 2000 warehouse,
#   rec5y-2000 (2000 wh) and rec5y-2019 (2019 wh) at salt 0. One arm each.
# Reuses the run_cell shape of delisting-guards-rerun-2026-09-06/chain-salts.sh.
set -u
C=trading-1-dev
WT=/workspaces/trading-1/.claude/worktrees/sweep-wh0908   # main 077b48973 (after #2709): PR-B splice action + #2696 ticket cancel
ROOT=$WT/trading
FIX=$ROOT/test_data/backtest_scenarios
SPECS_HOST=/tmp/wh-rebuild/specs
WORK=/tmp/wh-run4; ART=/tmp/sweeps/wh0908v9
LOG_HOST=/tmp/wh-rebuild/chain4.log; LOCK=/tmp/wh-rebuild/chain4.lock
W2019=/tmp/snap_top3000_2019_v9gap; W2019OLD=/tmp/snap_top3000_2019_v7mark
CELL_TIMEOUT=28800
log() { echo "[$(date '+%m-%d %H:%M:%S')] $*" | tee -a "$LOG_HOST"; }
run() { docker exec $C bash -c "cd $ROOT && eval \$(opam env) && $1"; }
mkdir -p /tmp/wh-rebuild; mkdir "$LOCK" 2>/dev/null || { echo "ABORT: lock"; exit 1; }
trap 'rmdir "$LOCK" 2>/dev/null' EXIT
docker exec $C mkdir -p $WORK $ART
run_cell() { # name snapdir salt
  name=$1; snap=$2; salt=$3; tag="$name-$(basename $snap | sed s/snap_top3000_//)-s$salt"; d=$WORK/$tag
  if grep -q "RESULT $tag " "$LOG_HOST" 2>/dev/null; then log "SKIP $tag"; return; fi
  docker exec $C sh -c "mkdir -p $d && rm -rf $d/*"; docker cp "$SPECS_HOST/$name.sexp" "$C:$d/" || { log "RESULT $tag => <spec missing>"; return; }
  log "RUN $tag on $snap"; start=$(date +%s)
  run "TRADING_DATA_DIR=$ROOT/test_data TRADING_PATH_SEED_SALT=$salt SNAPSHOT_CACHE_MB=1024 timeout $CELL_TIMEOUT ./_build/default/trading/backtest/scenarios/scenario_runner.exe --dir $d --fixtures-root $FIX --snapshot-dir $snap --no-emit-all-eligible --parallel 1 --progress-every 26 > $WORK/$tag.log 2>&1; echo exit=\$? >> $WORK/$tag.log"
  out=$(docker exec $C sh -c "grep 'Output root' $WORK/$tag.log | tail -1 | sed 's/.*: //'")
  m=$(docker exec $C sh -c "grep -hoE 'total_return_pct [0-9.eE+-]+|total_trades [0-9]+|sharpe_ratio [0-9.eE+-]+|max_drawdown_pct [0-9.eE+-]+' ${out}/${name}/actual.sexp 2>/dev/null | tr '\n' ' '")
  docker exec $C sh -c "for f in actual.sexp trades.csv params.sexp summary.sexp trade_audit.sexp open_positions.csv; do cp ${out}/${name}/\$f $ART/${tag}-\$f 2>/dev/null; done; cp $WORK/$tag.log $ART/${tag}.log" || true
  # V16/V17 post-run validator (report-only); PASS = 0 fallback exits, 0 stale entries
  run "./_build/default/trading/backtest/validation/bin/post_run_validator_cli.exe -run-dir ${out}/${name} -data-dir /workspaces/trading-1/data -out $ART/${tag}-validator.sexp > $WORK/$tag.validator.log 2>&1; echo exit=\$? >> $WORK/$tag.validator.log"
  q=$(docker exec $C sh -c "grep -oE 'QUALITY-FLAG[^\n]*' $WORK/$tag.validator.log $ART/${tag}-validator.sexp 2>/dev/null | head -2 | tr '\n' ' '")
  log "RESULT $tag => ${m:-<no result>} V16/V17: ${q:-none} (wall $(( $(date +%s) - start ))s)"
}
# Paired acceptance on the armed-splice 2000 warehouse vs its report-only control (same builder, same window)
run_cell rec5y-2019-new $W2019 0
# (salts 1-2 + the 5y cells follow only if the paired read is clean)
log "WH0908V9 CHAIN DONE"
