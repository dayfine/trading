#!/bin/sh
# shorts-phase-b-2026-10-09: copy of ../../rebaseline-v12-2026-10-08/results/chain-rb12.sh with run paths moved
# (/tmp/spb-run, artefacts in $ART: /tmp/sweeps/shorts-phase-b for lane A, /tmp/sweeps/shorts-phase-b-v1 for lane B),
# the same v12 warehouse and EXPECT_WH pin, and three additions:
#   1. the RESULT line also carries the summary's cashinteresttotal / dividendpaidshorttotal /
#      dividendmissingfilecount (the decision-8 read strips the interest; README §Stopping rule);
#   2. an optional build-identity replay (REPLAY_REF): when set (lane B), the first v0 cell is compared byte for byte
#      with the lane-A artefact of the same tag in $REPLAY_REF; if trades.csv, actual.sexp and equity_curve.csv are
#      identical, the lane-A v0 artefacts of the other salts are copied in and logged as RESULT ... reused, so the
#      loop skips them and every v1 cell still has a same-build v0 partner; if not, those v0 cells re-run here;
#   3. the run tree's HEAD is logged as the build SHA (both lanes write it to the results writeup).
# Cell guard: launch.sh sets CELL_TIMEOUT=36000, >= 1.5 x the slowest measured 26y cell on this warehouse
# (rebaseline-v12 chain-R.log: 9,581-21,249 s, the 21,249 s cell ran right after the preflight under host load)
# and >= 1.5 x the 26.5y extrapolation of the slowest Phase A short-only 5y cell (soT 3,747 s / 5.08 y -> ~19,500 s).
# Body otherwise unchanged.
set -u
LANE=$1; shift
C=trading-1-dev; REPO=/Users/difan/Projects/trading-1; WTREL=${WTREL:?set by launch.sh}
WT=/workspaces/trading-1/$WTREL; ROOT=$WT/trading; FIX=$ROOT/test_data/backtest_scenarios
SPECS_HOST=/tmp/spb-run/specs; WORK=/tmp/spb-run/$LANE; ART=${ART:?set by launch.sh}; WH=/tmp/snap_top3000_pit_v12pit
LOG_HOST=/tmp/spb-run/chain-$LANE.log; LOCK=/tmp/spb-run/chain-$LANE.lock; CELL_TIMEOUT=${CELL_TIMEOUT:-60000}
EXPECT_HEAD=${EXPECT_HEAD:?set EXPECT_HEAD to the pinned worktree short sha}
EXPECT_WH=${EXPECT_WH:?set EXPECT_WH to the v12 manifest entry count}
REPLAY_REF=${REPLAY_REF:-}
MMAP_HANDLES=${SNAPSHOT_MAX_MMAP_HANDLES:-12000}   # #2839 knob: >= n_symbols (v12 manifest 9,236) so the v2 warehouse LRU never cycles
log() { echo "[$(date '+%m-%d %H:%M:%S')] $*" | tee -a "$LOG_HOST"; }
run() { docker exec $C bash -c "cd $ROOT && eval \$(opam env) && $1"; }
mkdir -p /tmp/spb-run; mkdir "$LOCK" 2>/dev/null || { echo "ABORT: lock $LANE"; exit 1; }
trap 'rmdir "$LOCK" 2>/dev/null' EXIT
docker exec $C mkdir -p $WORK $ART
head=$(git -C $REPO/$WTREL rev-parse --short HEAD)
log "lane $LANE HEAD=$head (expect $EXPECT_HEAD) ART=$ART REPLAY_REF=${REPLAY_REF:-none}"
log "cell guard CELL_TIMEOUT=${CELL_TIMEOUT}s (26y guard); SNAPSHOT_MAX_MMAP_HANDLES=$MMAP_HANDLES"
[ "$head" = "$EXPECT_HEAD" ] || { log "ABORT: wrong HEAD"; exit 1; }
[ -z "$(git -C $REPO/$WTREL status --porcelain --untracked-files=no)" ] || { log "ABORT: run tree dirty"; exit 1; }
docker exec $C test -f $WH/manifest.sexp || { log "ABORT: no warehouse manifest at $WH"; exit 1; }
n_wh=$(docker exec $C sh -c "grep -c '(symbol ' $WH/manifest.sexp"); log "warehouse entries=$n_wh (expect $EXPECT_WH)"
[ "$n_wh" = "$EXPECT_WH" ] || { log "ABORT: warehouse entry count differs from the finished v12 build"; exit 1; }
free_gb=$(df -g / | awk 'NR==2{print $4}'); log "host free ${free_gb}G"; [ "$free_gb" -ge 20 ] || { log "ABORT: host disk < 20G"; exit 1; }
if [ "${BUILD:-0}" = 1 ]; then log "BUILD"; run "dune build trading/backtest/scenarios/scenario_runner.exe trading/backtest/validation/bin/post_run_validator_cli.exe trading/backtest/validation/bin/validator_diff.exe > /tmp/spb-run/build-$LANE.log 2>&1" || { log "ABORT: build failed"; exit 1; }; log "BUILD_DONE"; fi
# PREFLIGHT=1: run every distinct spec over a short window and abort the whole chain unless each writes actual.sexp
# -- a spec/override error (e.g. a #3218 field name that does not parse) then costs minutes, not a night.
# The window is a Bearish stretch (2022-04-01 -> 2022-06-30) so the short path is exercised, not just parsed.
if [ "${PREFLIGHT:-0}" = 1 ]; then
  for name in $(for tok in "$@"; do echo "${tok%%:*}"; done | sort -u); do pd=$WORK/preflight-$name
    docker exec $C sh -c "mkdir -p $pd && rm -rf $pd/*"
    sed 's/(period ((start_date [0-9-]*) (end_date [0-9-]*)))/(period ((start_date 2022-04-01) (end_date 2022-06-30)))/' "$SPECS_HOST/$name.sexp" > "/tmp/spb-run/preflight-$name.sexp"
    docker cp "/tmp/spb-run/preflight-$name.sexp" "$C:$pd/$name.sexp" || { log "ABORT: preflight copy $name"; exit 1; }
    log "PREFLIGHT $name"; t0=$(date +%s)
    run "TRADING_DATA_DIR=$ROOT/test_data SNAPSHOT_CACHE_MB=1024 SNAPSHOT_MAX_MMAP_HANDLES=$MMAP_HANDLES timeout 3600 ./_build/default/trading/backtest/scenarios/scenario_runner.exe --dir $pd --fixtures-root $FIX --snapshot-dir $WH --no-emit-all-eligible --parallel 1 > $pd.log 2>&1"
    pout=$(docker exec $C sh -c "grep 'Output root' $pd.log | tail -1 | sed 's/.*: //'")
    docker exec $C test -s "${pout}/${name}/actual.sexp" || { log "ABORT: preflight $name wrote no actual.sexp (see $pd.log)"; exit 1; }
    log "PREFLIGHT_OK $name ($(( $(date +%s) - t0 ))s)"
  done
fi
for tok in "$@"; do name=${tok%%:*}; rest=${tok#*:}; salt=${rest%%:*}; pair=""; [ "$rest" != "$salt" ] && pair=${rest#*:}; tag="$name-s$salt-v12"; d=$WORK/$tag
  if grep -q "RESULT $tag " "$LOG_HOST" 2>/dev/null; then log "SKIP $tag"; continue; fi
  docker exec $C sh -c "mkdir -p $d && rm -rf $d/*"; docker cp "$SPECS_HOST/$name.sexp" "$C:$d/" || { log "RESULT $tag => <spec missing>"; continue; }
  log "RUN $tag on $WH"; start=$(date +%s)
  run "TRADING_DATA_DIR=$ROOT/test_data TRADING_PATH_SEED_SALT=$salt SNAPSHOT_CACHE_MB=1024 SNAPSHOT_MAX_MMAP_HANDLES=$MMAP_HANDLES /usr/bin/time -f 'peak_rss_kb=%M' -o $WORK/$tag.rss timeout $CELL_TIMEOUT ./_build/default/trading/backtest/scenarios/scenario_runner.exe --dir $d --fixtures-root $FIX --snapshot-dir $WH --no-emit-all-eligible --parallel 1 --progress-every 26 > $WORK/$tag.log 2>&1; echo exit=\$? >> $WORK/$tag.log"
  out=$(docker exec $C sh -c "grep 'Output root' $WORK/$tag.log | tail -1 | sed 's/.*: //'")
  m=$(docker exec $C sh -c "grep -hoE 'total_return_pct [0-9.eE+-]+|total_trades [0-9]+|sharpe_ratio [0-9.eE+-]+|max_drawdown_pct [0-9.eE+-]+|calmar_ratio [0-9.eE+-]+' ${out}/${name}/actual.sexp 2>/dev/null | tr '\n' ' '")
  docker exec $C sh -c "for f in actual.sexp trades.csv splits.csv params.sexp summary.sexp trade_audit.sexp open_positions.csv force_liquidations.sexp equity_curve.csv macro_trend.sexp; do cp ${out}/${name}/\$f $ART/${tag}-\$f 2>/dev/null; done; cp $WORK/$tag.log $ART/${tag}.log; cp $WORK/$tag.rss $ART/${tag}.rss 2>/dev/null" || true
  cr=$(docker exec $C sh -c "grep -hoE '(cashinteresttotal|dividendpaidshorttotal|dividendincometotal|dividendmissingfilecount) [0-9.eE+-]+' $ART/${tag}-summary.sexp 2>/dev/null | tr '\n' ' '")
  cache=$(docker exec $C sh -c "grep -h 'snapshot cache' $WORK/$tag.log | tail -1"); rss=$(docker exec $C sh -c "tail -1 $WORK/$tag.rss 2>/dev/null")
  run "./_build/default/trading/backtest/validation/bin/post_run_validator_cli.exe -run-dir ${out}/${name} -data-dir /workspaces/trading-1/data -share-classes $ROOT/test_data/share_classes.sexp -out $ART/${tag}-validator.sexp > $WORK/$tag.validator.log 2>&1; echo exit=\$? >> $WORK/$tag.validator.log"
  q=$(docker exec $C sh -c "grep -hE 'V16 EXPECTATION|V17 EXPECTATION|V6 ' $ART/${tag}-validator.sexp.md 2>/dev/null | tr '\n' ' '")
  v6=none; if [ -n "$pair" ]; then
    run "./_build/default/trading/backtest/validation/bin/validator_diff.exe -check V6 -report pair=$ART/$pair-s$salt-v12-validator.sexp.sexp -report arm=$ART/${tag}-validator.sexp.sexp > $WORK/$tag.v6diff.log 2>&1; echo exit=\$? >> $WORK/$tag.v6diff.log"
    v6="$pair:$(docker exec $C sh -c "tail -1 $WORK/$tag.v6diff.log")"; fi
  log "RESULT $tag => ${m:-<no result>} ${cr:-<no credits>} ${q:-<no validator>} v6diff:${v6} ${rss} ${cache} (wall $(( $(date +%s) - start ))s)"
  # Build-identity replay (lane B only): one v0 cell on this build vs the lane-A artefact of the same tag.
  if [ -n "$REPLAY_REF" ] && [ "$name" = v0-26 ] && ! grep -q "REPLAY " "$LOG_HOST" 2>/dev/null; then
    same=1; for f in trades.csv actual.sexp equity_curve.csv; do
      a=$(docker exec $C sh -c "md5sum < $ART/${tag}-$f 2>/dev/null"); b=$(docker exec $C sh -c "md5sum < $REPLAY_REF/${tag}-$f 2>/dev/null")
      [ -n "$a" ] && [ "$a" = "$b" ] || same=0; done
    if [ "$same" = 1 ]; then log "REPLAY $tag identical to $REPLAY_REF (trades.csv, actual.sexp, equity_curve.csv): lane-A v0 cells stand as same-build partners"
      for t2 in "$@"; do n2=${t2%%:*}; r2=${t2#*:}; s2=${r2%%:*}; g2="$n2-s$s2-v12"
        [ "$n2" = v0-26 ] && [ "$g2" != "$tag" ] || continue
        if docker exec $C test -s "$REPLAY_REF/${g2}-actual.sexp"; then
          docker exec $C sh -c "cp $REPLAY_REF/${g2}-* $ART/"; log "RESULT $g2 => reused from $REPLAY_REF (replay of $tag identical)"
        else log "REPLAY: $REPLAY_REF has no $g2; it runs here"; fi
      done
    else log "REPLAY $tag DIFFERS from $REPLAY_REF: the build moved v0; every v0 salt re-runs on this build and the lane-A v0 cells are not the v1 partners"; fi
  fi
done
log "LANE $LANE DONE"
