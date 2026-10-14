#!/bin/sh
# pilot.sh [<SYM> ...]: the forward-pass pilot (plan §4, "pilot first"), one fresh model reader per checkpoint via
# reader.sh, symbols run one after another. Default symbols: the first of each sample stratum.
# Env: OUT (run root, default .sweep-output/fresh-eyes/pilot2 under the main checkout), DATA, MAXUSD_TOTAL (stop once
# the driving calls of all symbols pass this many dollars, default 40), SHADOW_MODEL and SHADOW_MAXUSD_TOTAL (the
# shadow reader's separate cap, default 15), plus reader.sh's env. Market pages must be pre-rendered into
# $PAGES/market (market_pages.sh). Run from the repo root.
E=dev/experiments/fresh-eyes-2026-10-13; S=$E/scripts
OUT=${OUT:-/Users/difan/Projects/trading-1/.sweep-output/fresh-eyes/pilot2}
DATA=${DATA:-/Users/difan/Projects/trading-1/data}; WEEKLY=${WEEKLY:-$OUT/weekly}; PAGES=${PAGES:-$OUT/pages}
MAXUSD_TOTAL=${MAXUSD_TOTAL:-40}; SHADOW_MAXUSD_TOTAL=${SHADOW_MAXUSD_TOTAL:-15}; export DATA WEEKLY PAGES SHADOW_MODEL
syms=$*; [ -n "$syms" ] || syms=$(awk '!s[$1]++ { print $2 }' $E/results/sample.txt)
usd() { cat "$OUT"/runs/*/"$1" 2>/dev/null | awk -F, '$1 != "sym" { t += $8 } END { printf "%.4f\n", t + 0 }'; }
one() { [ -f "$1" ] && awk -F, 'NR > 1 { t += $8 } END { printf "%.4f\n", t + 0 }' "$1" || echo 0; }
left() { awk -v a="$1" -v b="$2" -v c="$3" 'BEGIN { printf "%.4f\n", a - b + c }'; }
mkdir -p "$OUT/runs"
for s in $syms; do
  rem=$(left "$MAXUSD_TOTAL" "$(usd calls.csv)" 0)
  awk -v r="$rem" 'BEGIN { exit !(r <= 0) }' && { echo "pilot.sh: total budget reached before $s"; break; }
  t0=$(date +%s)
  MAXUSD=$(left "$MAXUSD_TOTAL" "$(usd calls.csv)" "$(one "$OUT/runs/$s/calls.csv")") \
  SHADOW_MAXUSD=$(left "$SHADOW_MAXUSD_TOTAL" "$(usd shadow.csv)" "$(one "$OUT/runs/$s/shadow.csv")") \
    sh $S/reader.sh "$s" "$OUT/runs/$s"; rc=$?
  echo "pilot.sh: $s exit $rc wall $(( $(date +%s) - t0 ))s driving \$$(usd calls.csv) shadow \$$(usd shadow.csv)"
  [ $rc = 0 ] || [ $rc = 5 ] || exit $rc
done
