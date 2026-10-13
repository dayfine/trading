#!/bin/sh
# Causality check (plan §7.1): a chart for cut t drawn from data truncated at t must be byte-identical to the one
# drawn from the full data. Any difference means a future bar reached the picture (a series, a scale, a label).
# Stocks: 3 symbols x 3 cuts x (2 frames + the last-bar JSON), with the daily input truncated before weekly.sh runs.
# Market: the SPY panel includes its volume band.
# Market: SPY and the A-D line regenerated from truncated inputs; sector rows truncated (sector.awk is a trailing
# 182-day window by construction, and regenerating it per cut would re-read every symbol).
# Run from the repo root; DATA = daily store. Exit 1 on any mismatch.
set -e
E=dev/experiments/fresh-eyes-2026-10-13; S=$E/scripts; DATA=${DATA:-data}; M=$E/results/market
B=trading/test_data/breadth
T=${TMPDIR:-/tmp}/fe-causal-$$; mkdir -p $T; fail=0
SYMS=${SYMS:-"AAPL DO_old HPE"}; CUTS=${CUTS:-"2003-03-14 2008-10-10 2021-06-25"}
for s in $SYMS; do
  DATA=$DATA sh $S/weekly.sh "$s" > $T/full.csv
  for c in $CUTS; do
    DATA=$DATA sh $S/weekly.sh "$s" "$c" > $T/trunc.csv
    for fr in full 5y; do
      awk -F, -v cut=$c -v frame=$fr -v sym="$s" -v sector=x -f $S/days.awk -f $S/chartlib.awk -f $S/chart.awk $T/full.csv > $T/a.svg
      awk -F, -v cut=$c -v frame=$fr -v sym="$s" -v sector=x -f $S/days.awk -f $S/chartlib.awk -f $S/chart.awk $T/trunc.csv > $T/b.svg
      if cmp -s $T/a.svg $T/b.svg; then echo "ok    $s $c $fr"; else echo "DIFF  $s $c $fr"; fail=1; fi
    done
    # The last-bar JSON the reader also gets.
    awk -F, -v cut=$c -v sym="$s" -v sector=x -f $S/days.awk -f $S/lastbar.awk $T/full.csv > $T/a.json
    awk -F, -v cut=$c -v sym="$s" -v sector=x -f $S/days.awk -f $S/lastbar.awk $T/trunc.csv > $T/b.json
    if cmp -s $T/a.json $T/b.json; then echo "ok    $s $c json"; else echo "DIFF  $s $c json"; fail=1; fi
  done
done
for c in $CUTS; do
  d=$(printf %s "$c" | tr -d -)
  DATA=$DATA sh $S/weekly.sh SPY "$c" > $T/spy.csv
  for f in nyse_advn nyse_decln synthetic_advn synthetic_decln; do awk -F, -v d=$d '$1 + 0 <= d + 0' $B/$f.csv > $T/$f.csv; done
  awk -f $S/days.awk -f $S/ad.awk $T/nyse_advn.csv $T/nyse_decln.csv $T/synthetic_advn.csv $T/synthetic_decln.csv > $T/ad.csv 2>/dev/null
  awk -F, -v c=$c 'NR == 1 || $1 <= c' $M/sector-strength.csv > $T/sec.csv
  for fr in full 5y; do
    awk -F, -v cut=$c -v frame=$fr -f $S/days.awk -f $S/chartlib.awk -f $S/market.awk $M/spy-weekly.csv $M/ad-weekly.csv $M/sector-strength.csv > $T/a.svg
    awk -F, -v cut=$c -v frame=$fr -f $S/days.awk -f $S/chartlib.awk -f $S/market.awk $T/spy.csv $T/ad.csv $T/sec.csv > $T/b.svg
    if cmp -s $T/a.svg $T/b.svg; then echo "ok    MARKET $c $fr"; else echo "DIFF  MARKET $c $fr"; fail=1; fi
  done
done
rm -rf $T
[ $fail = 0 ] && echo "causality check: PASS" || { echo "causality check: FAIL"; exit 1; }
