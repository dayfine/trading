#!/bin/sh
# Candidate-universe acceptance test: does a capture-derived fixture universe
# reproduce the full-universe run exactly?
#
# The builder's whole premise is that dropping a symbol which never became a
# candidate cannot change the run. That is not checkable from inside the module,
# so every emitted fixture is a hypothesis until this script confirms it.
#
# Steps: capture at the LOWEST gate (min_grade F, so the fixture is the superset
# over variants) -> build the fixture -> re-run the same spec against it ->
# byte-compare every artefact.
set -e
C=trading-1-dev
ROOT=/workspaces/trading-1/trading
DATA=$ROOT/test_data
FIX=$DATA/backtest_scenarios
WORK=/tmp/p02

SPEC_NAME=${SPEC_NAME:-nf-small-00-core}
SOURCE_UNIVERSE=${SOURCE_UNIVERSE:-universes/small.sexp}
OUT_UNIVERSE=${OUT_UNIVERSE:-universes/small-candidates-2018-2023.sexp}
WINDOW=${WINDOW:-2018-01-02..2023-12-29}

run() { docker exec $C bash -c "cd $ROOT && eval \$(opam env) && $1"; }

echo "[1/4] capture at min_grade F"
run "TRADING_DATA_DIR=$DATA ./_build/default/trading/backtest/all_eligible/bin/all_eligible_runner.exe \
  --scenario $WORK/base.sexp --min-grade F --out-dir $WORK/capture > $WORK/capture.log 2>&1"

echo "[2/4] build the fixture universe"
run "./_build/default/trading/backtest/scenarios/candidate_universe/pick.exe \
  --capture $WORK/capture/grade-F/trades.csv \
  --data-dir $DATA --from-universe $FIX/$SOURCE_UNIVERSE \
  --window $WINDOW --min-grade F -o $FIX/$OUT_UNIVERSE"

echo "[3/4] run baseline and fixture"
for d in run_base run_fix; do
  run "TRADING_DATA_DIR=$DATA ./_build/default/trading/backtest/scenarios/scenario_runner.exe \
    --dir $WORK/$d --fixtures-root $FIX --no-emit-all-eligible --parallel 1 \
    > $WORK/$d.log 2>&1; echo exit=\$? >> $WORK/$d.log"
done

echo "[4/4] byte-compare every artefact"
docker exec $C bash -c '
  b=$(grep "Output root" '"$WORK"'/run_base.log | tail -1 | cut -d" " -f3)/'"$SPEC_NAME"'
  f=$(grep "Output root" '"$WORK"'/run_fix.log  | tail -1 | cut -d" " -f3)/p02-fixture
  rc=0
  for x in actual.sexp trades.csv equity_curve.csv trade_audit.sexp macro_trend.sexp open_positions.csv; do
    if cmp -s "$b/$x" "$f/$x"; then echo "$x IDENTICAL"; else echo "$x DIFFERS"; rc=1; fi
  done
  echo "universe: $(wc -l < $b/universe.txt) -> $(wc -l < $f/universe.txt) symbols"
  exit $rc'
