#!/bin/sh
# Regenerates results/analysis/* (the analyst's reading) from committed inputs plus the host data/ files that
# scripts/run.sh also reads. Run from the repo root, after scripts/run.sh:
#   sh dev/experiments/index-hedge-screen-2026-10-12/scripts/analysis/run.sh
# Per-day tables go to a temporary directory; only the small text outputs are written to results/analysis/.
set -eu
E=dev/experiments/index-hedge-screen-2026-10-12; R=dev/experiments/breadth-fix-rb1-2026-10-11/results
A=$E/scripts/analysis; O=$E/results/analysis; W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
mkdir -p "$O"
days() { awk -v lag="$1" -f $A/days.awk $E/results/spy-weekly-stage.csv $E/results/macro-N.csv data/S/Y/SPY/data.csv \
  $R/N-rb1-26-s"$2"-v12-equity_curve.csv; }
for s in 0 1 2; do days 0 $s > "$W/days-s$s.csv"; done
# SPY-side reads (identical for every salt; s0 table used)
for g in 1 2 3; do awk -v g=$((g + 5)) -f $A/episodes.awk "$W/days-s0.csv" > $O/episodes-G$g.csv; done
{ for g in 1 2 3; do
    awk -v col=8 -v label="G$g h=0.25 overlay log" -f $A/dist.awk $O/episodes-G$g.csv
    awk -v col=7 -v label="G$g h=1 short log" -f $A/dist.awk $O/episodes-G$g.csv
    awk -v col=5 -v label="G$g SPY move %" -f $A/dist.awk $O/episodes-G$g.csv
  done; } > $O/episode-dist.txt
for g in 1 2 3; do awk -f $A/loo.awk $O/episodes-G$g.csv > $O/loo-G$g.txt; done
{ for post in "2003-01-09 2009-06-09 2020-06-23 2023-01-12" "2003-04-09 2009-09-09 2020-09-23 2023-04-12" \
    "2003-10-09 2010-03-09 2021-03-23 2023-10-12"; do awk -v post="$post" -f $A/phase.awk "$W/days-s0.csv"; echo; done; } > $O/phase.txt
for g in 6 7 8; do awk -v g=$g -f $A/lateness.awk "$W/days-s0.csv"; done > $O/lateness.txt
awk -f $A/years.awk "$W/days-s0.csv" > $O/years.txt
awk -f $A/decomp.awk "$W/days-s0.csv" > $O/decomp.txt
awk -f $A/tails.awk "$W/days-s0.csv" > $O/tails.txt
awk -f $A/regime_check.awk $E/results/spy-weekly-stage.csv data/S/Y/SPY/data.csv > $O/regime-check.txt
# Base-dependent reads, per salt
for s in 0 1 2; do
  awk -f $A/windows.awk "$W/days-s$s.csv" > $O/windows-s$s.txt
  awk -v form=sum -f $A/forms.awk "$W/days-s$s.csv" > $O/forms-sum-s$s.txt
  awk -v form=static -f $A/forms.awk "$W/days-s$s.csv" > $O/forms-static-s$s.txt
  awk -f $A/basedd.awk $R/N-rb1-26-s$s-v12-equity_curve.csv > $O/base-dd-s$s.txt
  v0=$(sed -n 2p $R/N-rb1-26-s$s-v12-equity_curve.csv | cut -d, -f2)
  awk -v v0="$v0" -v init=1000000 -v start=2000-01-01 -v first=2000-01-03 -f $A/ledger_metrics.awk \
    data/macro/tbill_3m_dtb3.csv "$W/days-s$s.csv" > $O/ledger-metrics-s$s.txt
done
# The friendliest convention stack in overlay.awk: one extra week of lag and credited proceeds
awk -v lag=1 -v credit=1 -v borrow=0.0025 -v mode=summary -f $E/scripts/overlay.awk $E/results/spy-weekly-stage.csv \
  $E/results/macro-N.csv data/macro/tbill_3m_dtb3.csv data/S/Y/SPY/data.csv $R/N-rb1-26-s0-v12-equity_curve.csv > $O/summary-s0-lag1-credit.txt
# The same overlay on the OLD (frozen A-D) macro, O s0: the Phase B reference ran on this input
grep -oE '\(date [0-9-]+\) \(trend [A-Za-z]+\)' $R/O-rb1-26-s0-v12-macro_trend.sexp \
  | sed -E 's/\(date ([0-9-]+)\) \(trend ([A-Za-z]+)\)/\1,\2/' > "$W/macro-O.csv"
awk -v lag=0 -v credit=0 -v borrow=0.0025 -v mode=summary -f $E/scripts/overlay.awk $E/results/spy-weekly-stage.csv \
  "$W/macro-O.csv" data/macro/tbill_3m_dtb3.csv data/S/Y/SPY/data.csv $R/O-rb1-26-s0-v12-equity_curve.csv > $O/omacro-summary-s0.txt
printf 'O macro trend counts: %s\n' "$(cut -d, -f2 "$W/macro-O.csv" | sort | uniq -c | tr -s ' ' | tr '\n' ';')" >> $O/omacro-summary-s0.txt
awk -f $A/trace.awk "$W/days-s0.csv" > $O/traces-s0.txt
for g in 6 7 8; do awk -v g=$g -f $A/covers.awk "$W/days-s0.csv"; done > $O/covers.txt
