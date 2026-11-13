#!/bin/sh
# capacity.sh -- for one arm's entries at E <= CAP ($14 default): position value at the fill / mean dollar
# volume (raw close x volume) over the 20 bars ending on the fill date. Reads the local bar store; prints
# only ratios (no bar data). usage: sh capacity.sh PREFIX [DATA_DIR] [CAP]
p=$1; D=${2:-data}; CAP=${3:-14}
{ awk -F, -v c="$CAP" 'FNR > 1 && $6 + 0 <= c { print $1, $3, $6 * $8 }' "${p}trades.csv"
  awk -F, -v c="$CAP" 'FNR > 1 && $4 + 0 <= c { print $1, $3, $4 * $5 }' "${p}open_positions.csv"; } |
while read -r sym d val; do
  l1=$(printf %s "$sym" | cut -c1); l2=$(printf %s "$sym" | rev | cut -c1 | tr '[:lower:]' '[:upper:]')
  f=$D/$l1/$l2/$sym/data.csv
  [ -f "$f" ] || { echo "$sym $d NA"; continue; }
  awk -F, -v d="$d" -v v="$val" -v s="$sym" 'FNR > 1 && $1 <= d { dv[++n] = $5 * $7 }
    END { k = 0; t = 0; for (i = n; i > 0 && k < 20; i--) { t += dv[i]; k++ }
          if (k == 0 || t == 0) print s, d, "NA"; else printf "%s %s %.4f\n", s, d, v / (t / k) }' "$f"
done
