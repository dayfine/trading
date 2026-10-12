#!/bin/sh
# Regenerates every results/*.txt from committed inputs. Run from the repo root:
#   sh dev/experiments/index-hedge-screen-2026-10-12/scripts/run.sh
# Inputs: results/spy-weekly-stage.csv (stage_chart.exe SPY replay, default classifier, adjusted closes),
# results/macro-N.csv (N s0 macro_trend.sexp; identical across salts), data/macro/tbill_3m_dtb3.csv,
# data/S/Y/SPY/data.csv (host data/, total return via adjusted_close), and the N equity curves of
# dev/experiments/breadth-fix-rb1-2026-10-11/results/.
set -eu
E=dev/experiments/index-hedge-screen-2026-10-12; R=dev/experiments/breadth-fix-rb1-2026-10-11/results
run() { awk -v lag=$1 -v credit=$2 -v borrow=0.0025 -v mode=$3 -f $E/scripts/overlay.awk $E/results/spy-weekly-stage.csv \
  $E/results/macro-N.csv data/macro/tbill_3m_dtb3.csv data/S/Y/SPY/data.csv $R/N-rb1-26-s$4-v12-equity_curve.csv; }
for s in 0 1 2; do
  run 0 0 summary $s > $E/results/summary-s$s.txt        # primary: no credit, gate = last reading before the day
  run 0 1 summary $s > $E/results/summary-s$s-credit.txt # sensitivity: short proceeds earn DTB3 - 10 bp
  run 1 0 summary $s > $E/results/summary-s$s-lag1.txt   # sensitivity: one extra week of lag
  run 0 0 years $s > $E/results/years-s$s.txt
done
run 0 0 episodes 0 > $E/results/episodes.txt             # SPY-side only; identical for every salt
