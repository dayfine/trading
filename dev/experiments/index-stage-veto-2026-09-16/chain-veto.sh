#!/bin/sh
# Index-stage veto arm (dev/experiments/index-stage-veto-2026-09-16): v1-index-veto on the _v11pit union warehouse,
# salts 0/1/2, PINNED worktree sweep-veto (built off main once the veto flag PR merged). Pairs each cell against the
# COMMITTED null artifacts pit-universe-2026-09-14/step4/results/a0-pit-null-s<salt>-v11-* (never re-runs the null).
# Modeled on pit-universe-2026-09-14/step4/chain-pit.sh. Usage: EXPECT_HEAD=<sha> sh chain-veto.sh <lane> <spec>:<salt>...
# Artifacts: /tmp/sweeps/index-veto/ (container, bind-mounted). Specs are staged OUTSIDE any VCS tree at /tmp/veto-run/specs.
# Lane A (salt 0) ran at CELL_TIMEOUT 36000 / cap 256 on 5577d418a; salt 1 died on that guard at 92.5 % (README §Log 21:08 PT),
# so lanes B+ run on the #2839 knob build with SNAPSHOT_MAX_MMAP_HANDLES >= n_symbols and a 60,000 s guard.
set -u
LANE=$1; shift
C=trading-1-dev; REPO=/Users/difan/Projects/trading-1; WTREL=${WTREL:-.claude/worktrees/sweep-veto}   # lane A: sweep-veto @5577d418a; lanes B+: sweep-veto2 @ the #2882 merge
WT=/workspaces/trading-1/$WTREL; ROOT=$WT/trading; FIX=$ROOT/test_data/backtest_scenarios
NULL_RES=$WT/dev/experiments/pit-universe-2026-09-14/step4/results
SPECS_HOST=/tmp/veto-run/specs; WORK=/tmp/veto-run/$LANE; ART=/tmp/sweeps/index-veto; WH=/tmp/snap_top3000_pit_v11pit
LOG_HOST=/tmp/veto-run/chain-$LANE.log; LOCK=/tmp/veto-run/chain-$LANE.lock; CELL_TIMEOUT=${CELL_TIMEOUT:-60000}
EXPECT_HEAD=${EXPECT_HEAD:?set EXPECT_HEAD to the pinned worktree short sha}
MMAP_HANDLES=${SNAPSHOT_MAX_MMAP_HANDLES:-12000}   # #2839 knob: >= n_symbols (9,915) so the v2 warehouse LRU never cycles; 256 = pre-knob behaviour
log() { echo "[$(date '+%m-%d %H:%M:%S')] $*" | tee -a "$LOG_HOST"; }
run() { docker exec $C bash -c "cd $ROOT && eval \$(opam env) && $1"; }
mkdir -p /tmp/veto-run; mkdir "$LOCK" 2>/dev/null || { echo "ABORT: lock $LANE"; exit 1; }
trap 'rmdir "$LOCK" 2>/dev/null' EXIT
docker exec $C mkdir -p $WORK $ART
head=$(git -C $REPO/$WTREL rev-parse --short HEAD)
log "lane $LANE HEAD=$head (expect $EXPECT_HEAD)"; log "cell guard CELL_TIMEOUT=${CELL_TIMEOUT}s (sized from the measured arm: s0 8h33m at cap 256); SNAPSHOT_MAX_MMAP_HANDLES=$MMAP_HANDLES"
[ "$head" = "$EXPECT_HEAD" ] || { log "ABORT: wrong HEAD"; exit 1; }
[ -z "$(git -C $REPO/$WTREL status --porcelain --untracked-files=no)" ] || { log "ABORT: run tree dirty"; exit 1; }
docker exec $C test -f $WH/manifest.sexp || { log "ABORT: no warehouse manifest at $WH"; exit 1; }
n_wh=$(docker exec $C sh -c "grep -c '(symbol ' $WH/manifest.sexp"); log "warehouse entries=$n_wh (expect 9364)"
[ "$n_wh" = "9364" ] || { log "ABORT: warehouse changed since the null band"; exit 1; }
free_gb=$(df -g / | awk 'NR==2{print $4}'); log "host free ${free_gb}G"; [ "$free_gb" -ge 20 ] || { log "ABORT: host disk < 20G"; exit 1; }
for tok in "$@"; do name=${tok%%:*}; salt=${tok#*:}; tag="$name-s$salt-v11"; d=$WORK/$tag
  if grep -q "RESULT $tag " "$LOG_HOST" 2>/dev/null; then log "SKIP $tag"; continue; fi
  docker exec $C sh -c "mkdir -p $d && rm -rf $d/*"; docker cp "$SPECS_HOST/$name.sexp" "$C:$d/" || { log "RESULT $tag => <spec missing>"; continue; }
  log "RUN $tag on $WH"; start=$(date +%s)
  run "TRADING_DATA_DIR=$ROOT/test_data TRADING_PATH_SEED_SALT=$salt SNAPSHOT_CACHE_MB=1024 SNAPSHOT_MAX_MMAP_HANDLES=$MMAP_HANDLES timeout $CELL_TIMEOUT ./_build/default/trading/backtest/scenarios/scenario_runner.exe --dir $d --fixtures-root $FIX --snapshot-dir $WH --no-emit-all-eligible --parallel 1 --progress-every 26 > $WORK/$tag.log 2>&1; echo exit=\$? >> $WORK/$tag.log"
  out=$(docker exec $C sh -c "grep 'Output root' $WORK/$tag.log | tail -1 | sed 's/.*: //'")
  m=$(docker exec $C sh -c "grep -hoE 'total_return_pct [0-9.eE+-]+|total_trades [0-9]+|sharpe_ratio [0-9.eE+-]+|max_drawdown_pct [0-9.eE+-]+|calmar_ratio [0-9.eE+-]+' ${out}/${name}/actual.sexp 2>/dev/null | tr '\n' ' '")
  docker exec $C sh -c "for f in actual.sexp trades.csv params.sexp summary.sexp trade_audit.sexp open_positions.csv force_liquidations.sexp equity_curve.csv macro_trend.sexp; do cp ${out}/${name}/\$f $ART/${tag}-\$f 2>/dev/null; done; cp $WORK/$tag.log $ART/${tag}.log" || true
  run "./_build/default/trading/backtest/validation/bin/post_run_validator_cli.exe -run-dir ${out}/${name} -data-dir /workspaces/trading-1/data -out $ART/${tag}-validator.sexp > $WORK/$tag.validator.log 2>&1; echo exit=\$? >> $WORK/$tag.validator.log"
  q=$(docker exec $C sh -c "grep -hE 'V16 EXPECTATION|V17 EXPECTATION|V6 ' $ART/${tag}-validator.sexp.md 2>/dev/null | tr '\n' ' '")
  run "./_build/default/trading/backtest/validation/bin/validator_diff.exe -check V6 -report null=$NULL_RES/a0-pit-null-s$salt-v11-validator.sexp.sexp -report arm=$ART/${tag}-validator.sexp.sexp > $WORK/$tag.v6diff.log 2>&1; echo exit=\$? >> $WORK/$tag.v6diff.log"
  v6=$(docker exec $C sh -c "tail -1 $WORK/$tag.v6diff.log")
  log "RESULT $tag => ${m:-<no result>} ${q:-<no validator>} v6diff:${v6} (wall $(( $(date +%s) - start ))s)"
done
log "LANE $LANE DONE"
