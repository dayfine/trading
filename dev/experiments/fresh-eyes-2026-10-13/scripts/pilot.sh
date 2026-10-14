#!/bin/sh
# pilot.sh [<SYM> ...]: the forward-pass pilot (plan §4, "pilot first"), one fresh model reader per checkpoint via
# reader.sh, symbols run one after another. Default symbols: the first of each sample stratum.
# Env: OUT (run root, default .sweep-output/fresh-eyes/pilot under the main checkout), DATA, MAXTOK_TOTAL (stop the
# pilot once all symbols' calls pass this many tokens, default 15000000), plus reader.sh's env. Market pages must be
# pre-rendered into $OUT/pages/market (market_pages.sh). Run from the repo root.
E=dev/experiments/fresh-eyes-2026-10-13; S=$E/scripts
OUT=${OUT:-/Users/difan/Projects/trading-1/.sweep-output/fresh-eyes/pilot}
DATA=${DATA:-/Users/difan/Projects/trading-1/data}; WEEKLY=${WEEKLY:-$OUT/weekly}; PAGES=${PAGES:-$OUT/pages}
MAXTOK_TOTAL=${MAXTOK_TOTAL:-15000000}; export DATA WEEKLY PAGES
syms=$*; [ -n "$syms" ] || syms=$(awk '!s[$1]++ { print $2 }' $E/results/sample.txt)
total() { cat "$OUT"/runs/*/calls.csv 2>/dev/null | awk -F, '$1 != "sym" { t += $4 + $5 + $6 + $7 } END { print t + 0 }'; }
mkdir -p "$OUT/runs"
for s in $syms; do
  left=$((MAXTOK_TOTAL - $(total)))
  [ "$left" -gt 0 ] || { echo "pilot.sh: total token budget reached before $s"; break; }
  t0=$(date +%s)
  MAXTOK=$(( left + $(cat "$OUT/runs/$s/calls.csv" 2>/dev/null | awk -F, '$1 != "sym" { t += $4 + $5 + $6 + $7 } END { print t + 0 }') )) \
    sh $S/reader.sh "$s" "$OUT/runs/$s"; rc=$?
  echo "pilot.sh: $s exit $rc wall $(( $(date +%s) - t0 ))s total tokens $(total)"
  [ $rc = 0 ] || [ $rc = 5 ] || exit $rc
done
