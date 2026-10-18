#!/bin/sh
# causality_check.sh: the 2026-10-13 causality check's pattern applied to this study's one new renderer,
# thumb.awk (the contact-sheet thumbnail): a thumbnail for cut t drawn from daily data truncated at t must be
# byte-identical to the one drawn from the full data. The other pages (render.sh, composite.sh) are the 2026-10-13
# renderers unchanged; run that study's causality_check.sh for them. Exit 1 on any mismatch.
# Run from the repo root; DATA = the daily store.
set -e
S0=dev/experiments/fresh-eyes-2026-10-13/scripts; S=dev/experiments/fresh-eyes-dated-2026-10-18/scripts
DATA=${DATA:-/Users/difan/Projects/trading-1/data}
T=${TMPDIR:-/tmp}/fed-causal-$$; mkdir -p "$T"; fail=0
SYMS=${SYMS:-"AAPL DO_old HPE"}; CUTS=${CUTS:-"2002-02-22 2009-01-16 2017-07-14 2021-01-01"}
for s in $SYMS; do
  DATA=$DATA sh $S0/weekly.sh "$s" > "$T/full.csv"
  for c in $CUTS; do
    DATA=$DATA sh $S0/weekly.sh "$s" "$c" > "$T/trunc.csv"
    awk -F, -v cut="$c" -v sym=QQQQ -f $S0/days.awk -f $S0/chartlib.awk -f $S/thumb.awk "$T/full.csv" > "$T/a.svg"
    awk -F, -v cut="$c" -v sym=QQQQ -f $S0/days.awk -f $S0/chartlib.awk -f $S/thumb.awk "$T/trunc.csv" > "$T/b.svg"
    if cmp -s "$T/a.svg" "$T/b.svg"; then echo "ok    $s $c thumb"; else echo "DIFF  $s $c thumb"; fail=1; fi
  done
done
rm -rf "$T"
[ $fail = 0 ] && echo "causality check (thumb): PASS" || { echo "causality check (thumb): FAIL"; exit 1; }
