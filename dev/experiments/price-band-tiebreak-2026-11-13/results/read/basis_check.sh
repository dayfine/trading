#!/bin/sh
# basis_check.sh -- is the simulator's entry price on the raw basis? For every distinct closed trade or open position
# (symbol|entry_date) across the 10 cells: ratio = entry_price / the bar store's RAW close on the entry date. A ratio
# far from 1 that matches the product of the splits dated AFTER the entry (splits.csv) means the price the strategy
# saw carried a later split, so its #3587 band was assigned on a split-leaked price. Prints ratios and flags only,
# never a bar.
# usage: sh basis_check.sh POSITIONS_TSV [DATA_DIR] > basis_check.tsv
#   columns: symbol entry_date entry_price band(entry) ratio later_split_product band_if_raw verdict
POS=${1:?}; D=${2:-data}
awk -F'\t' 'NR > 1 { print $4 "\t" $5 "\t" $8 }' "$POS" | LC_ALL=C sort -u |
while IFS="$(printf '\t')" read -r sym d px; do
  l1=$(printf %s "$sym" | cut -c1); l2=$(printf %s "$sym" | rev | cut -c1 | tr '[:lower:]' '[:upper:]')
  f=$D/$l1/$l2/$sym/data.csv; s=$D/$l1/$l2/$sym/splits.csv
  [ -f "$f" ] || { printf '%s\t%s\t%s\tNA\tNA\tNA\tNA\tno-bars\n' "$sym" "$d" "$px"; continue; }
  sp=1; [ -f "$s" ] && sp=$(awk -F, -v d="$d" 'FNR > 1 && $1 > d { p *= $2 } BEGIN { p = 1 } END { printf "%.4f", p }' "$s")
  awk -F, -v d="$d" -v px="$px" -v s="$sym" -v sp="$sp" 'FNR > 1 && $1 <= d { c = $5 }
    function band(x) { return (x >= 8) + (x >= 14) + (x >= 33) }
    END { if (!c) { print s "\t" d "\t" px "\tNA\tNA\t" sp "\tNA\tno-close"; exit }
          r = px / c; v = "raw"
          if (r < 0.80 || r > 1.25) v = (sp > 1.2 && r * sp > 0.80 && r * sp < 1.25) ? "later-split-adjusted" : "other-mismatch"
          printf "%s\t%s\t%s\t%d\t%.3f\t%s\t%d\t%s\n", s, d, px, band(px + 0), r, sp, band(c), v }' "$f"
done
