#!/bin/sh
# PIT record null (dev/plans/pit-universe-migration-2026-09-14.md step 4): a0-pit-null on the _v11pit union warehouse,
# salts 0/1/2, pinned worktree sweep-pit @ 3a20f4987 (#2816 universe_schedule merged). Modeled on
# concentration-deploy-2026-09-13/chain-conc.sh. Usage: sh chain-pit.sh <lane> <spec>:<salt>...   Artifacts: /tmp/sweeps/pit-null/
set -u
LANE=$1; shift
C=trading-1-dev; WT=/workspaces/trading-1/.claude/worktrees/sweep-pit; ROOT=$WT/trading; FIX=$ROOT/test_data/backtest_scenarios
SPECS_HOST=/tmp/pit-fetch/specs; WORK=/tmp/pit-run/$LANE; ART=/tmp/sweeps/pit-null; WH=/tmp/snap_top3000_pit_v11pit
LOG_HOST=/tmp/pit-run/chain-$LANE.log; LOCK=/tmp/pit-run/chain-$LANE.lock; CELL_TIMEOUT=36000
EXPECT_HEAD=3a20f4987
log() { echo "[$(date '+%m-%d %H:%M:%S')] $*" | tee -a "$LOG_HOST"; }
run() { docker exec $C bash -c "cd $ROOT && eval \$(opam env) && $1"; }
mkdir -p /tmp/pit-run; mkdir "$LOCK" 2>/dev/null || { echo "ABORT: lock $LANE"; exit 1; }
trap 'rmdir "$LOCK" 2>/dev/null' EXIT
docker exec $C mkdir -p $WORK $ART
head=$(git -C /Users/difan/Projects/trading-1/.claude/worktrees/sweep-pit rev-parse --short HEAD)
log "lane $LANE HEAD=$head (expect $EXPECT_HEAD)"
[ "$head" = "$EXPECT_HEAD" ] || { log "ABORT: wrong HEAD"; exit 1; }
[ -z "$(git -C /Users/difan/Projects/trading-1/.claude/worktrees/sweep-pit status --porcelain --untracked-files=no)" ] || { log "ABORT: run tree dirty"; exit 1; }
docker exec $C test -f $WH/manifest.sexp || { log "ABORT: no warehouse manifest at $WH"; exit 1; }
# D6 manifest check: every schedule member must be in the warehouse or be accounted for (_old twin / known MISS).
docker exec $C sh -c "grep -o '(symbol [^)]*)' $WH/manifest.sexp | awk '{print \$2}' | tr -d ')' | LC_ALL=C sort -u" > /tmp/pit-run/manifest-syms.txt
for y in $(seq 1999 2025); do grep -o "(symbol [^)]*)" /Users/difan/Projects/trading-1/.claude/worktrees/sweep-pit/trading/test_data/backtest_scenarios/pit-v11/composition/top-3000-$y.sexp | awk "{print \$2}" | tr -d ")"; done | LC_ALL=C sort -u > /tmp/pit-run/union.txt
LC_ALL=C comm -23 /tmp/pit-run/union.txt /tmp/pit-run/manifest-syms.txt > /tmp/pit-run/union-absent.txt
n_abs=$(wc -l < /tmp/pit-run/union-absent.txt | tr -d ' '); n_old=$(grep -c '_old' /tmp/pit-run/union-absent.txt); n_real=$((n_abs - n_old))
log "D6 manifest check: union=$(wc -l < /tmp/pit-run/union.txt | tr -d ' ') manifest=$(wc -l < /tmp/pit-run/manifest-syms.txt | tr -d ' ') absent=$n_abs (_old=$n_old real=$n_real; expect real <= ~120: the 109 MISS + 3 quarantined + twin-dedup drops)"
[ "$n_real" -le 200 ] || { log "ABORT: $n_real real union names absent from the manifest — investigate before running"; exit 1; }
for tok in "$@"; do name=${tok%%:*}; salt=${tok#*:}; tag="$name-s$salt-v11"; d=$WORK/$tag
  if grep -q "RESULT $tag " "$LOG_HOST" 2>/dev/null; then log "SKIP $tag"; continue; fi
  docker exec $C sh -c "mkdir -p $d && rm -rf $d/*"; docker cp "$SPECS_HOST/$name.sexp" "$C:$d/" || { log "RESULT $tag => <spec missing>"; continue; }
  log "RUN $tag on $WH"; start=$(date +%s)
  run "TRADING_DATA_DIR=$ROOT/test_data TRADING_PATH_SEED_SALT=$salt SNAPSHOT_CACHE_MB=1024 timeout $CELL_TIMEOUT ./_build/default/trading/backtest/scenarios/scenario_runner.exe --dir $d --fixtures-root $FIX --snapshot-dir $WH --no-emit-all-eligible --parallel 1 --progress-every 26 > $WORK/$tag.log 2>&1; echo exit=\$? >> $WORK/$tag.log"
  out=$(docker exec $C sh -c "grep 'Output root' $WORK/$tag.log | tail -1 | sed 's/.*: //'")
  m=$(docker exec $C sh -c "grep -hoE 'total_return_pct [0-9.eE+-]+|total_trades [0-9]+|sharpe_ratio [0-9.eE+-]+|max_drawdown_pct [0-9.eE+-]+' ${out}/${name}/actual.sexp 2>/dev/null | tr '\n' ' '")
  docker exec $C sh -c "for f in actual.sexp trades.csv params.sexp summary.sexp trade_audit.sexp open_positions.csv force_liquidations.sexp equity_curve.csv macro_trend.sexp; do cp ${out}/${name}/\$f $ART/${tag}-\$f 2>/dev/null; done; cp $WORK/$tag.log $ART/${tag}.log" || true
  run "./_build/default/trading/backtest/validation/bin/post_run_validator_cli.exe -run-dir ${out}/${name} -data-dir /workspaces/trading-1/data -out $ART/${tag}-validator.sexp > $WORK/$tag.validator.log 2>&1; echo exit=\$? >> $WORK/$tag.validator.log"
  q=$(docker exec $C sh -c "grep -hE 'V16 EXPECTATION|V17 EXPECTATION|V6 ' $ART/${tag}-validator.sexp.md 2>/dev/null | tr '\n' ' '")
  log "RESULT $tag => ${m:-<no result>} ${q:-<no validator>} (wall $(( $(date +%s) - start ))s)"
done
log "LANE $LANE DONE"
