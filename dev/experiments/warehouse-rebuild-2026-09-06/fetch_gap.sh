#!/bin/sh
# Vintage gap fetch (fetch-historical-data skill, Phase 2): composition names with no CSV in the store.
# Writes data/<f>/<l>/<SYM>/data.csv with the store's lowercase header; requires >200 rows; logs OK/MISS/SKIP.
set -u
cd /Users/difan/Projects/trading-1
LIST=/tmp/wh-rebuild/fetch-all.txt; LOG=/tmp/wh-rebuild/fetch_gap.log; TOKEN="$EODHD_API_KEY"
: > "$LOG"
fetch_one() {
  sym=$1
  case "$sym" in *_old) echo "SKIP $sym synthetic-twin" >> "$LOG"; return;; esac
  es=$(echo "$sym" | sed 's/\./-/g')
  dst="data/$(echo "$sym" | cut -c1)/$(echo "$sym" | rev | cut -c1)/$sym"
  r=$(curl -s -m 30 "https://eodhd.com/api/eod/${es}.US?api_token=${TOKEN}&fmt=csv&from=1990-01-01&to=2026-09-08&period=d")
  rows=$(printf '%s\n' "$r" | grep -cE '^[12][0-9]{3}-')
  if [ "$rows" -gt 200 ]; then
    mkdir -p "$dst"
    { echo "date,open,high,low,close,adjusted_close,volume"; printf '%s\n' "$r" | grep -E '^[12][0-9]{3}-'; } > "$dst/data.csv"
    echo "OK $sym $rows $(printf '%s\n' "$r" | grep -E '^[12][0-9]{3}-' | head -1 | cut -d, -f1) $(printf '%s\n' "$r" | grep -E '^[12][0-9]{3}-' | tail -1 | cut -d, -f1)" >> "$LOG"
  else
    echo "MISS $sym rows=$rows $(printf '%s' "$r" | head -c 80 | tr '\n' ' ')" >> "$LOG"
  fi
}
export -f fetch_one 2>/dev/null || true
i=0
while read s; do fetch_one "$s" & i=$((i+1)); [ $((i % 8)) -eq 0 ] && wait; done < "$LIST"; wait
echo "FETCH DONE ok=$(grep -c '^OK' $LOG) miss=$(grep -c '^MISS' $LOG) skip=$(grep -c '^SKIP' $LOG)" >> "$LOG"
