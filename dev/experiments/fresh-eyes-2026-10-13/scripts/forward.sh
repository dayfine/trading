#!/bin/sh
# forward.sh: the layer (ii) forward pass over all 100 sampled symbols (plan §4), Opus driving, no shadow
# (pilot 2: the shadow disagrees on most order-placing decisions, so it cannot stand in). JOBS symbols run at once,
# each with a fresh reader per checkpoint (reader.sh). A symbol is skipped once the total driving spend passes
# MAXUSD_TOTAL. Restartable: reader.sh resumes a symbol from its state file.
# Env: OUT (run root), JOBS (default 4), MAXUSD (per symbol, default 40), MAXUSD_TOTAL (default 1200), plus
# reader.sh's env. Run from the repo root.
E=dev/experiments/fresh-eyes-2026-10-13; S=$E/scripts
OUT=${OUT:-/Users/difan/Projects/trading-1/.sweep-output/fresh-eyes/forward}
JOBS=${JOBS:-4}; MAXUSD=${MAXUSD:-40}; MAXUSD_TOTAL=${MAXUSD_TOTAL:-1200}
CARD=${CARD:-$PWD/$E/results/rulecard.md}
DATA=${DATA:-/Users/difan/Projects/trading-1/data}; WEEKLY=${WEEKLY:-$OUT/weekly}; PAGES=${PAGES:-$OUT/pages}
RWORK=${RWORK:-$HOME/.fresh-eyes-run}
export OUT MAXUSD MAXUSD_TOTAL CARD DATA WEEKLY PAGES RWORK
mkdir -p "$OUT/runs" "$OUT/logs" "$PAGES"
# Market pages are the same for every symbol: pre-rendered once (market_pages.sh); MARKET_PAGES links them in.
[ -e "$PAGES/market" ] || ln -s "${MARKET_PAGES:-/Users/difan/Projects/trading-1/.sweep-output/fresh-eyes/pilot/pages/market}" "$PAGES/market"
one_sym() {
  s=$1
  [ -f "$OUT/runs/$s/done" ] && return 0
  tot=$(cat "$OUT"/runs/*/calls.csv 2>/dev/null | awk -F, '$1 != "sym" { t += $8 } END { printf "%.2f", t + 0 }')
  awk -v t="$tot" -v m="$MAXUSD_TOTAL" 'BEGIN { exit !(t >= m) }' && { echo "forward.sh: $s skipped, total \$$tot"; return 0; }
  t0=$(date +%s)
  sh $S/reader.sh "$s" "$OUT/runs/$s" > "$OUT/logs/$s.log" 2>&1; rc=$?
  [ $rc = 0 ] && touch "$OUT/runs/$s/done"
  echo "forward.sh: $s exit $rc wall $(( $(date +%s) - t0 ))s total \$$tot"
}
if [ -n "$1" ]; then one_sym "$1"; exit; fi
awk '{ print $2 }' $E/results/sample.txt | xargs -P "$JOBS" -n 1 sh $0
