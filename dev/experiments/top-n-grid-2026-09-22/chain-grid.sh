#!/bin/sh
# Top-N confirmation grid, sub-window cells (dev/experiments/top-n-grid-2026-09-22): a0-pit-null-sub (the null) and
# t1-topn-{30,40,60}-sub on the 2019-01-01..2025-12-31 sub-window of the _v11pit PIT schedule, salts 0/1/2. Unlike
# chain-funnel.sh there is NO committed null for this window: the null cells run in this lane and every arm cell pairs
# (validator_diff -check V6) against the null cell of the same salt from $ART — so the null cells must be listed FIRST.
# Usage: EXPECT_HEAD=<sha> sh chain-grid.sh <lane> <spec>:<salt>...   e.g.  a0-pit-null-sub:0 t1-topn-40-sub:0
# Artifacts: /tmp/sweeps/top-n-grid/ (container, bind-mounted). Specs staged OUTSIDE any VCS tree at /tmp/grid-run/specs.
# CELL_TIMEOUT 14,400 s: no 7y cell has been measured on this build class; sized from the MEASURED 26y arm cells of the
# same knob (4h48m / 4h16m / 3h59m at cap 12,000, top-of-funnel README §Log = ~11 min per simulated year -> ~80 min for
# 7 y) with a 3x margin. Re-size from the first cell's wall (>= 1.5x, perf-review-weekly.md rule 3) before the rest run.
set -u
LANE=$1; shift
C=trading-1-dev; REPO=/Users/difan/Projects/trading-1; WTREL=${WTREL:-.claude/worktrees/sweep-grid}
WT=/workspaces/trading-1/$WTREL; ROOT=$WT/trading; FIX=$ROOT/test_data/backtest_scenarios
SPECS_HOST=/tmp/grid-run/specs; WORK=/tmp/grid-run/$LANE; ART=/tmp/sweeps/top-n-grid; WH=/tmp/snap_top3000_pit_v11pit
LOG_HOST=/tmp/grid-run/chain-$LANE.log; LOCK=/tmp/grid-run/chain-$LANE.lock; CELL_TIMEOUT=${CELL_TIMEOUT:-14400}
EXPECT_HEAD=${EXPECT_HEAD:?set EXPECT_HEAD to the pinned worktree short sha}
MMAP_HANDLES=${SNAPSHOT_MAX_MMAP_HANDLES:-12000}   # #2882 knob: >= n_symbols (9,364) so the v2 warehouse LRU never cycles
log() { echo "[$(date '+%m-%d %H:%M:%S')] $*" | tee -a "$LOG_HOST"; }
run() { docker exec $C bash -c "cd $ROOT && eval \$(opam env) && $1"; }
mkdir -p /tmp/grid-run; mkdir "$LOCK" 2>/dev/null || { echo "ABORT: lock $LANE"; exit 1; }
trap 'rmdir "$LOCK" 2>/dev/null' EXIT
docker exec $C mkdir -p $WORK $ART
head=$(git -C $REPO/$WTREL rev-parse --short HEAD)
log "lane $LANE HEAD=$head (expect $EXPECT_HEAD)"; log "cell guard CELL_TIMEOUT=${CELL_TIMEOUT}s (3x the ~80 min projected from the measured 26y arm cells); SNAPSHOT_MAX_MMAP_HANDLES=$MMAP_HANDLES"
[ "$head" = "$EXPECT_HEAD" ] || { log "ABORT: wrong HEAD"; exit 1; }
[ -z "$(git -C $REPO/$WTREL status --porcelain --untracked-files=no)" ] || { log "ABORT: run tree dirty"; exit 1; }
docker exec $C test -f $WH/manifest.sexp || { log "ABORT: no warehouse manifest at $WH"; exit 1; }
n_wh=$(docker exec $C sh -c "grep -c '(symbol ' $WH/manifest.sexp"); log "warehouse entries=$n_wh (expect 9364)"
[ "$n_wh" = "9364" ] || { log "ABORT: warehouse changed since the null band"; exit 1; }
free_gb=$(df -g / | awk 'NR==2{print $4}'); log "host free ${free_gb}G"; [ "$free_gb" -ge 20 ] || { log "ABORT: host disk < 20G"; exit 1; }
# Binary tripwire (qc-results advisory on #2917, feedback_dune_no_build_stale_exe): a git HEAD check cannot see a stale
# _build. Build the three exes in the pinned tree (a no-op when up to date) and log the runner md5 so the results PR can
# show every cell ran the same binary.
run "dune build ./trading/backtest/scenarios/scenario_runner.exe ./trading/backtest/validation/bin/post_run_validator_cli.exe ./trading/backtest/validation/bin/validator_diff.exe" || { log "ABORT: dune build failed in $WTREL"; exit 1; }
log "runner md5=$(docker exec $C md5sum $ROOT/_build/default/trading/backtest/scenarios/scenario_runner.exe | cut -c1-32)"
for tok in "$@"; do name=${tok%%:*}; salt=${tok#*:}
  tag="$name-s$salt"; d=$WORK/$tag
  if grep -q "RESULT $tag " "$LOG_HOST" 2>/dev/null; then log "SKIP $tag"; continue; fi
  docker exec $C sh -c "mkdir -p $d && rm -rf $d/*"; docker cp "$SPECS_HOST/$name.sexp" "$C:$d/" || { log "RESULT $tag => <spec missing>"; continue; }
  log "RUN $tag on $WH"; start=$(date +%s)
  run "TRADING_DATA_DIR=$ROOT/test_data TRADING_PATH_SEED_SALT=$salt SNAPSHOT_CACHE_MB=1024 SNAPSHOT_MAX_MMAP_HANDLES=$MMAP_HANDLES /usr/bin/time -f 'peak_rss_kb=%M' -o $WORK/$tag.rss timeout $CELL_TIMEOUT ./_build/default/trading/backtest/scenarios/scenario_runner.exe --dir $d --fixtures-root $FIX --snapshot-dir $WH --no-emit-all-eligible --parallel 1 --progress-every 26 > $WORK/$tag.log 2>&1; echo exit=\$? >> $WORK/$tag.log"
  out=$(docker exec $C sh -c "grep 'Output root' $WORK/$tag.log | tail -1 | sed 's/.*: //'")
  m=$(docker exec $C sh -c "grep -hoE 'total_return_pct [0-9.eE+-]+|total_trades [0-9]+|sharpe_ratio [0-9.eE+-]+|max_drawdown_pct [0-9.eE+-]+|calmar_ratio [0-9.eE+-]+' ${out}/${name}/actual.sexp 2>/dev/null | tr '\n' ' '")
  docker exec $C sh -c "for f in actual.sexp trades.csv params.sexp summary.sexp trade_audit.sexp open_positions.csv force_liquidations.sexp equity_curve.csv macro_trend.sexp; do cp ${out}/${name}/\$f $ART/${tag}-\$f 2>/dev/null; done; cp $WORK/$tag.log $ART/${tag}.log; cp $WORK/$tag.rss $ART/${tag}.rss 2>/dev/null" || true
  cache=$(docker exec $C sh -c "grep -h 'snapshot cache' $WORK/$tag.log | tail -1"); rss=$(docker exec $C sh -c "tail -1 $WORK/$tag.rss 2>/dev/null")
  run "./_build/default/trading/backtest/validation/bin/post_run_validator_cli.exe -run-dir ${out}/${name} -data-dir /workspaces/trading-1/data -out $ART/${tag}-validator.sexp > $WORK/$tag.validator.log 2>&1; echo exit=\$? >> $WORK/$tag.validator.log"
  q=$(docker exec $C sh -c "grep -hE 'V16 EXPECTATION|V17 EXPECTATION|V6 ' $ART/${tag}-validator.sexp.md 2>/dev/null | tr '\n' ' '")
  v6="n/a(null cell)"
  case "$name" in t1-*)
    if docker exec $C test -f $ART/a0-pit-null-sub-s$salt-validator.sexp.sexp; then
      run "./_build/default/trading/backtest/validation/bin/validator_diff.exe -check V6 -report null=$ART/a0-pit-null-sub-s$salt-validator.sexp.sexp -report arm=$ART/${tag}-validator.sexp.sexp > $WORK/$tag.v6diff.log 2>&1; echo exit=\$? >> $WORK/$tag.v6diff.log"
      v6=$(docker exec $C sh -c "tail -1 $WORK/$tag.v6diff.log")
      docker exec $C cp $WORK/$tag.v6diff.log $ART/${tag}.v6diff.log 2>/dev/null || true
    else v6="<null s$salt not run yet>"; fi;;
  esac
  log "RESULT $tag => ${m:-<no result>} ${q:-<no validator>} v6diff:${v6} ${rss} ${cache} (wall $(( $(date +%s) - start ))s)"
done
log "LANE $LANE DONE"
