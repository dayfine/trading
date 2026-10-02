#!/bin/sh
# trader-presets-rerun-2026-10-02: copy of ../../trader-presets-2026-09-29/results/chain-trader.sh with run paths moved
# (/tmp/trader-rerun, /tmp/sweeps/trader-presets-rerun). Cell guard: launch.sh sets CELL_TIMEOUT=10800 = 2.2x the slowest
# 5y cell of the 09-29 matrix (1h23m, chain-M.log). Everything below the header is unchanged.
set -u
LANE=$1; shift
C=trading-1-dev; REPO=/Users/difan/Projects/trading-1; WTREL=${WTREL:?set by launch.sh}
WT=/workspaces/trading-1/$WTREL; ROOT=$WT/trading; FIX=$ROOT/test_data/backtest_scenarios
SPECS_HOST=/tmp/trader-rerun/specs; WORK=/tmp/trader-rerun/$LANE; ART=/tmp/sweeps/trader-presets-rerun; WH=/tmp/snap_top3000_pit_v11pit
LOG_HOST=/tmp/trader-rerun/chain-$LANE.log; LOCK=/tmp/trader-rerun/chain-$LANE.lock; CELL_TIMEOUT=${CELL_TIMEOUT:-60000}
EXPECT_HEAD=${EXPECT_HEAD:?set EXPECT_HEAD to the pinned worktree short sha}
MMAP_HANDLES=${SNAPSHOT_MAX_MMAP_HANDLES:-12000}   # #2839 knob: >= n_symbols (9,915) so the v2 warehouse LRU never cycles; 256 = pre-knob behaviour
log() { echo "[$(date '+%m-%d %H:%M:%S')] $*" | tee -a "$LOG_HOST"; }
run() { docker exec $C bash -c "cd $ROOT && eval \$(opam env) && $1"; }
mkdir -p /tmp/trader-rerun; mkdir "$LOCK" 2>/dev/null || { echo "ABORT: lock $LANE"; exit 1; }
trap 'rmdir "$LOCK" 2>/dev/null' EXIT
docker exec $C mkdir -p $WORK $ART
head=$(git -C $REPO/$WTREL rev-parse --short HEAD)
log "lane $LANE HEAD=$head (expect $EXPECT_HEAD)"; log "cell guard CELL_TIMEOUT=${CELL_TIMEOUT}s (26y guard; 5y cells ~1h); SNAPSHOT_MAX_MMAP_HANDLES=$MMAP_HANDLES"
[ "$head" = "$EXPECT_HEAD" ] || { log "ABORT: wrong HEAD"; exit 1; }
[ -z "$(git -C $REPO/$WTREL status --porcelain --untracked-files=no)" ] || { log "ABORT: run tree dirty"; exit 1; }
docker exec $C test -f $WH/manifest.sexp || { log "ABORT: no warehouse manifest at $WH"; exit 1; }
n_wh=$(docker exec $C sh -c "grep -c '(symbol ' $WH/manifest.sexp"); log "warehouse entries=$n_wh (expect 9364)"
[ "$n_wh" = "9364" ] || { log "ABORT: warehouse changed since the null band"; exit 1; }
free_gb=$(df -g / | awk 'NR==2{print $4}'); log "host free ${free_gb}G"; [ "$free_gb" -ge 20 ] || { log "ABORT: host disk < 20G"; exit 1; }
if [ "${BUILD:-0}" = 1 ]; then log "BUILD"; run "dune build trading/backtest/scenarios/scenario_runner.exe trading/backtest/validation/bin/post_run_validator_cli.exe trading/backtest/validation/bin/validator_diff.exe > /tmp/trader-rerun/build.log 2>&1" || { log "ABORT: build failed"; exit 1; }; log "BUILD_DONE"; fi
# PREFLIGHT=1: run every distinct spec over a short window (last ~3 months) and abort the whole chain unless
# each writes actual.sexp -- a spec/override error then costs minutes, not an unattended night of 1-second cells.
if [ "${PREFLIGHT:-0}" = 1 ]; then
  for name in $(for tok in "$@"; do echo "${tok%%:*}"; done | sort -u); do pd=$WORK/preflight-$name
    docker exec $C sh -c "mkdir -p $pd && rm -rf $pd/*"
    sed 's/(period ((start_date [0-9-]*) (end_date [0-9-]*)))/(period ((start_date 2026-04-01) (end_date 2026-06-26)))/' "$SPECS_HOST/$name.sexp" > "/tmp/trader-rerun/preflight-$name.sexp"
    docker cp "/tmp/trader-rerun/preflight-$name.sexp" "$C:$pd/$name.sexp" || { log "ABORT: preflight copy $name"; exit 1; }
    log "PREFLIGHT $name"; t0=$(date +%s)
    run "TRADING_DATA_DIR=$ROOT/test_data SNAPSHOT_CACHE_MB=1024 SNAPSHOT_MAX_MMAP_HANDLES=$MMAP_HANDLES timeout 3600 ./_build/default/trading/backtest/scenarios/scenario_runner.exe --dir $pd --fixtures-root $FIX --snapshot-dir $WH --no-emit-all-eligible --parallel 1 > $pd.log 2>&1"
    pout=$(docker exec $C sh -c "grep 'Output root' $pd.log | tail -1 | sed 's/.*: //'")
    docker exec $C test -s "${pout}/${name}/actual.sexp" || { log "ABORT: preflight $name wrote no actual.sexp (see $pd.log)"; exit 1; }
    log "PREFLIGHT_OK $name ($(( $(date +%s) - t0 ))s)"
  done
fi
for tok in "$@"; do name=${tok%%:*}; rest=${tok#*:}; salt=${rest%%:*}; pair=""; [ "$rest" != "$salt" ] && pair=${rest#*:}; tag="$name-s$salt-v11"; d=$WORK/$tag
  if grep -q "RESULT $tag " "$LOG_HOST" 2>/dev/null; then log "SKIP $tag"; continue; fi
  docker exec $C sh -c "mkdir -p $d && rm -rf $d/*"; docker cp "$SPECS_HOST/$name.sexp" "$C:$d/" || { log "RESULT $tag => <spec missing>"; continue; }
  log "RUN $tag on $WH"; start=$(date +%s)
  run "TRADING_DATA_DIR=$ROOT/test_data TRADING_PATH_SEED_SALT=$salt SNAPSHOT_CACHE_MB=1024 SNAPSHOT_MAX_MMAP_HANDLES=$MMAP_HANDLES /usr/bin/time -f 'peak_rss_kb=%M' -o $WORK/$tag.rss timeout $CELL_TIMEOUT ./_build/default/trading/backtest/scenarios/scenario_runner.exe --dir $d --fixtures-root $FIX --snapshot-dir $WH --no-emit-all-eligible --parallel 1 --progress-every 26 > $WORK/$tag.log 2>&1; echo exit=\$? >> $WORK/$tag.log"
  out=$(docker exec $C sh -c "grep 'Output root' $WORK/$tag.log | tail -1 | sed 's/.*: //'")
  m=$(docker exec $C sh -c "grep -hoE 'total_return_pct [0-9.eE+-]+|total_trades [0-9]+|sharpe_ratio [0-9.eE+-]+|max_drawdown_pct [0-9.eE+-]+|calmar_ratio [0-9.eE+-]+' ${out}/${name}/actual.sexp 2>/dev/null | tr '\n' ' '")
  docker exec $C sh -c "for f in actual.sexp trades.csv params.sexp summary.sexp trade_audit.sexp open_positions.csv force_liquidations.sexp equity_curve.csv macro_trend.sexp; do cp ${out}/${name}/\$f $ART/${tag}-\$f 2>/dev/null; done; cp $WORK/$tag.log $ART/${tag}.log; cp $WORK/$tag.rss $ART/${tag}.rss 2>/dev/null" || true
  cache=$(docker exec $C sh -c "grep -h 'snapshot cache' $WORK/$tag.log | tail -1"); rss=$(docker exec $C sh -c "tail -1 $WORK/$tag.rss 2>/dev/null")
  run "./_build/default/trading/backtest/validation/bin/post_run_validator_cli.exe -run-dir ${out}/${name} -data-dir /workspaces/trading-1/data -share-classes $ROOT/test_data/share_classes.sexp -out $ART/${tag}-validator.sexp > $WORK/$tag.validator.log 2>&1; echo exit=\$? >> $WORK/$tag.validator.log"
  q=$(docker exec $C sh -c "grep -hE 'V16 EXPECTATION|V17 EXPECTATION|V6 ' $ART/${tag}-validator.sexp.md 2>/dev/null | tr '\n' ' '")
  v6=none; if [ -n "$pair" ]; then
    run "./_build/default/trading/backtest/validation/bin/validator_diff.exe -check V6 -report pair=$ART/$pair-s$salt-v11-validator.sexp.sexp -report arm=$ART/${tag}-validator.sexp.sexp > $WORK/$tag.v6diff.log 2>&1; echo exit=\$? >> $WORK/$tag.v6diff.log"
    v6="$pair:$(docker exec $C sh -c "tail -1 $WORK/$tag.v6diff.log")"; fi
  log "RESULT $tag => ${m:-<no result>} ${q:-<no validator>} v6diff:${v6} ${rss} ${cache} (wall $(( $(date +%s) - start ))s)"
done
log "LANE $LANE DONE"
