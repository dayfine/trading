#!/bin/sh
# list_bands.sh -- the #3587 price band of every name in every recorded post-cut list (entries.tsv: placed rows plus
# every skipped alternative) of both arms of one cell, all seeds present. Band = number of edges [8;14;33] <= price,
# with price = the RAW close on the decision date (last bar on or before it), a proxy for the ticket price
# suggested_entry, which entries.tsv does not carry (it agreed with the fill band on 96-97 % of #3595's trades).
# Reads the bar store read-only and prints ONLY the band (0..3, or NA), never a price or a bar.
# Adapted from ../../price-band-tiebreak-2026-11-13/results/read/list_bands.sh: the cell tag is a parameter.
#
# usage: sh list_bands.sh RESULTS_DIR TAG [DATA_DIR] > list_bands-TAG.tsv     (columns: symbol date band)
#   TAG = pbc1 | pbc2 (this experiment), or pb with RESULTS_DIR = the #3595 results (a reproduction check)
R=${1:?usage: sh list_bands.sh RESULTS_DIR TAG [DATA_DIR]}; T=${2:?TAG}; D=${3:-data}
cat "$R"/k?/"$T"-?-k?-s0-entries.tsv | awk -F'\t' '$1 != "position_id" { print $2 "\t" $3 }' | LC_ALL=C sort -u |
awk -F'\t' '{ if ($1 != s) { if (s != "") print s "\t" ds; s = $1; ds = $2 } else ds = ds "," $2 } END { if (s != "") print s "\t" ds }' |
while IFS="$(printf '\t')" read -r sym dates; do
  l1=$(printf %s "$sym" | cut -c1); l2=$(printf %s "$sym" | rev | cut -c1 | tr '[:lower:]' '[:upper:]')
  f=$D/$l1/$l2/$sym/data.csv
  if [ ! -f "$f" ]; then printf '%s\n' "$dates" | tr ',' '\n' | awk -v s="$sym" '{ print s "\t" $1 "\tNA" }'; continue; fi
  awk -F, -v s="$sym" -v ds="$dates" '
    BEGIN { n = split(ds, want, ","); i = 1 }        # want[] is sorted ascending (sort -u above)
    FNR == 1 { next }
    { while (i <= n && $1 > want[i]) { emit(i); i++ } if (i > n) exit; last = $5 + 0; have = 1
      if ($1 == want[i]) { emit(i); i++ } }
    function emit(j) { if (have) print s "\t" want[j] "\t" ((last >= 8) + (last >= 14) + (last >= 33)); else print s "\t" want[j] "\tNA" }
    END { while (i <= n) { emit(i); i++ } }' "$f"
done
