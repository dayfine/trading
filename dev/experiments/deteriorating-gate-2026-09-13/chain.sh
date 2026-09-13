#!/bin/sh
# Deteriorating-gate read (#2755 / PR #2759) on the DEDUPED 2000 warehouse (_v10dedup). Arm a3 (flag ON) at salts 0/1/2,
# paired against the committed a0-breadth-on-null-s<salt>-v10 null cells of stop-width-by-state-2026-09-08 (same warehouse).
# Build = main after #2759 merges, pinned in worktree sweep-detgate (runtime-inert vs 969637974 apart from #2759 itself).
# Usage: sh chain.sh <lane> <arm>:<salt>...   (lanes run concurrently: separate WORK/lock; shared ART)
# Artifacts: /tmp/sweeps/detgate/<arm>-s<salt>-v10-*; pairing gate = validator_diff -check V6 vs the a0-v10 cell.
set -u
LANE=$1; shift
C=trading-1-dev; WT=/workspaces/trading-1/.claude/worktrees/sweep-detgate; ROOT=$WT/trading; FIX=$ROOT/test_data/backtest_scenarios
SPECS_HOST=/tmp/detgate-run/specs; WORK=/tmp/detgate-run/$LANE; ART=/tmp/sweeps/detgate
LOG_HOST=/tmp/detgate-run/chain-$LANE.log; LOCK=/tmp/detgate-run/chain-$LANE.lock; W2000=/tmp/snap_top3000_2000_v10dedup; CELL_TIMEOUT=28800
EXPECT_HEAD=31e4bb9c3
log() { echo "[$(date '+%m-%d %H:%M:%S')] $*" | tee -a "$LOG_HOST"; }
run() { docker exec $C bash -c "cd $ROOT && eval \$(opam env) && $1"; }
mkdir -p /tmp/detgate-run; mkdir "$LOCK" 2>/dev/null || { echo "ABORT: lock $LANE"; exit 1; }
trap 'rmdir "$LOCK" 2>/dev/null' EXIT
docker exec $C mkdir -p $WORK $ART
head=$(git -C /Users/difan/Projects/trading-1/.claude/worktrees/sweep-detgate rev-parse --short HEAD)
log "lane $LANE HEAD=$head (expect $EXPECT_HEAD)"
[ "$head" = "$EXPECT_HEAD" ] || { log "ABORT: wrong HEAD"; exit 1; }
[ -z "$(git -C /Users/difan/Projects/trading-1/.claude/worktrees/sweep-detgate status --porcelain)" ] || { log "ABORT: run tree dirty"; exit 1; }
docker exec $C test -f $W2000/manifest.sexp || { log "ABORT: no manifest in $W2000"; exit 1; }
for tok in "$@"; do name=${tok%%:*}; salt=${tok#*:}; tag="$name-s$salt-v10"; d=$WORK/$tag
  if grep -q "RESULT $tag " "$LOG_HOST" 2>/dev/null; then log "SKIP $tag"; continue; fi
  docker exec $C sh -c "mkdir -p $d && rm -rf $d/*"; docker cp "$SPECS_HOST/$name.sexp" "$C:$d/" || { log "RESULT $tag => <spec missing>"; continue; }
  log "RUN $tag on $W2000"; start=$(date +%s)
  run "TRADING_DATA_DIR=$ROOT/test_data TRADING_PATH_SEED_SALT=$salt SNAPSHOT_CACHE_MB=1024 timeout $CELL_TIMEOUT ./_build/default/trading/backtest/scenarios/scenario_runner.exe --dir $d --fixtures-root $FIX --snapshot-dir $W2000 --no-emit-all-eligible --parallel 1 --progress-every 26 > $WORK/$tag.log 2>&1; echo exit=\$? >> $WORK/$tag.log"
  out=$(docker exec $C sh -c "grep 'Output root' $WORK/$tag.log | tail -1 | sed 's/.*: //'")
  m=$(docker exec $C sh -c "grep -hoE 'total_return_pct [0-9.eE+-]+|total_trades [0-9]+|sharpe_ratio [0-9.eE+-]+|max_drawdown_pct [0-9.eE+-]+' ${out}/${name}/actual.sexp 2>/dev/null | tr '\n' ' '")
  docker exec $C sh -c "for f in actual.sexp trades.csv params.sexp summary.sexp trade_audit.sexp open_positions.csv force_liquidations.sexp; do cp ${out}/${name}/\$f $ART/${tag}-\$f 2>/dev/null; done; cp $WORK/$tag.log $ART/${tag}.log" || true
  run "./_build/default/trading/backtest/validation/bin/post_run_validator_cli.exe -run-dir ${out}/${name} -data-dir /workspaces/trading-1/data -out $ART/${tag}-validator.sexp > $WORK/$tag.validator.log 2>&1; echo exit=\$? >> $WORK/$tag.validator.log"
  q=$(docker exec $C sh -c "grep -hE 'V16 EXPECTATION|V17 EXPECTATION|V6 ' $ART/${tag}-validator.sexp.md 2>/dev/null | tr '\n' ' '")
  log "RESULT $tag => ${m:-<no result>} ${q:-<no validator>} (wall $(( $(date +%s) - start ))s)"
done
log "LANE $LANE DONE"
