#!/bin/sh
# NAV high-water episodes with >=15% drawdown, and each position's open gain at the peak.
# Host-only: peak_gains.sh DATA_DIR RUN_DIR. No container, warehouse or replay.
set -eu
DATA=$1; RUN=$2
LIB=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
[ -s "$RUN/equity_curve.csv" ] && [ -s "$RUN/trades.csv" ] || { printf 'null\n'; exit 0; }
awk -F, 'NR>1 { n++; if ($2 == "") bad=1 } END { exit (!n || bad) }' "$RUN/equity_curve.csv" || { printf 'null\n'; exit 0; }
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT INT TERM
awk -F, '
  function flush() { if (peak > 0 && 100 * (peak - low) >= 15 * peak) printf "%s\t%.10f\t%s\t%.10f\n", date, peak, trough, 100 * (peak - low) / peak }
  NR > 1 {
    last=$1
    if (!seen++ || $2+0 > peak) { flush(); date=$1; peak=$2+0; low=peak; trough=$1 }
    else if ($2+0 < low) { low=$2+0; trough=$1 }
  }
  END { flush() }' OFS='\t' "$RUN/equity_curve.csv" > "$TMP/peaks"
last=$(tail -1 "$RUN/equity_curve.csv" | cut -d, -f1)
# Both closed trips and the final open inventory can have been held at an intermediate peak.
awk -F, 'NR>1 { print $1,$2,$3,$4,$6,$8,0 }' OFS='\t' "$RUN/trades.csv" > "$TMP/positions"
if [ -s "$RUN/open_positions.csv" ]; then
  awk -F, -v last="$last" 'NR>1 { print $1,$2,$3,last,$4,$5,1 }' OFS='\t' "$RUN/open_positions.csv" >> "$TMP/positions"
fi
: > "$TMP/result"
tab=$(printf '\t')
while IFS="$tab" read -r date nav trough drawdown; do
  : > "$TMP/gains"
  while IFS="$tab" read -r sym side ed end ep qty is_open; do
    [ "$ed" \> "$date" ] && continue
    # A closed trip is no longer held on its exit day. A final open row has end=last.
    [ "$end" \< "$date" ] && continue
    if [ "$end" = "$date" ] && [ "$is_open" != 1 ]; then continue; fi
    file="$DATA/$(printf %s "$sym" | cut -c1)/$(printf %s "$sym" | rev | cut -c1)/$sym/data.csv"
    gain=null
    if [ -s "$file" ]; then
      gain=$(awk -v ed="$ed" -v end="$end" -v peak_date="$date" -v ep="$ep" -v qty="$qty" -v side="$side" -f "$LIB/peak_gain.awk" "$file")
    fi
    jq -nc --arg sym "$sym" --argjson gain "$gain" '{sym:$sym,gain:$gain}' >> "$TMP/gains"
  done < "$TMP/positions"
  if [ ! -s "$RUN/open_positions.csv" ]; then
    printf '{"sym":"final open-position inventory","gain":null}\n' >> "$TMP/gains"
  fi
  jq -nc --arg d "$date" --argjson peak "$nav" --arg trough "$trough" --argjson drawdown "$drawdown" --slurpfile positions "$TMP/gains" \
    '{d:$d,peak:$peak,trough:$trough,drawdown:$drawdown,positions:$positions}' >> "$TMP/result"
done < "$TMP/peaks"
jq -s . "$TMP/result"
