#!/bin/sh
# tdfull_check.sh -- how much td-full's "committed test_data wins" overlay (README §Data step 2) moved Wtd's divisor.
# The checkout's trading/test_data holds a short data.csv (bars from 2009 or later, ending 2026-04/05) for some symbols;
# in td-full it replaces the bar store's full-history file, and True_dollar_divisor reads it. A split dated before such
# a file's first bar (or after its last) is dropped, so Wtd's F for that symbol misses it. Prints:
#   1. per committed symbol whose applied splits differ between the short file and the full history, F at 1999-01-04
#      on each (the product of the splits the short file loses), and the count;
#   2. for every Wtd and W0 entry decision (placed, and skipped alternatives) on such a symbol at a date where the two
#      F differ, the $1M gate flags (stored | true as run | true on full history), 1 = passes; a "10" -> "1x0" row is an
#      admission the full-history basis would have blocked.
# Prints derived divisors and flags only (EODHD terms).
#
# usage: sh tdfull_check.sh RESULTS_DIR DATA_DIR TEST_DATA_DIR [SPLITS_ROOT]   (arguments as read/t3.sh)
set -u
R=${1:?usage: sh tdfull_check.sh RESULTS_DIR DATA_DIR TEST_DATA_DIR [SPLITS_ROOT]}; D=${2:?}; T=${3:?}; SP=${4:-$2}
HERE=$(cd "$(dirname "$0")" && pwd); AWK_DIV=$HERE/divisor.awk
W=${TMPDIR:-/tmp}/tdf.$$; mkdir -p "$W"; trap 'rm -rf "$W"' EXIT
GATE=1000000; EARLY=1999-01-04
shard() { printf %s "$1" | awk '{ print toupper(substr($0, 1, 1)) "/" toupper(substr($0, length($0), 1)) "/" $0 }'; }

find "$T" -mindepth 4 -maxdepth 4 -name data.csv | awk -F/ '{ print $(NF - 1) }' | LC_ALL=C sort -u > "$W/committed"
echo "$EARLY" > "$W/qe"; : > "$W/diff"
while read -r s; do
  p=$(shard "$s"); spl=$SP/$p/splits.csv; [ -f "$spl" ] || continue; [ -f "$D/$p/data.csv" ] || continue
  a=$(awk -v sym="$s" -f "$AWK_DIV" "$spl" "$T/$p/data.csv" "$T/$p/data.csv" "$W/qe" | cut -f3)
  f=$(awk -v sym="$s" -f "$AWK_DIV" "$spl" "$D/$p/data.csv" "$D/$p/data.csv" "$W/qe" | cut -f3)
  [ "$a" != "$f" ] && printf '%s\t%s\t%s\n' "$s" "$a" "$f" >> "$W/diff"
done < "$W/committed"
echo "committed short data.csv files: $(wc -l < "$W/committed" | tr -d ' '); symbols whose F at $EARLY differs (short | full):"
awk -F'\t' '{ printf "  %s\t%s | %s\n", $1, $2, $3 }' "$W/diff"
echo "count: $(wc -l < "$W/diff" | tr -d ' ')"

echo "entry decisions on those symbols where F differs at the decision date (arm, symbol, date, kind, gate s|t_asrun|t_full):"
for arm in W0 Wtd; do
  awk -F'\t' 'NR == FNR { d[$1] = 1; next } ($2 in d) && ($4 == "placed" || $4 == "skipped") { print $2 "\t" $3 "\t" $4 }' \
    "$W/diff" "$R/cw-$arm-s0-entries.tsv" > "$W/dec"
  for s in $(cut -f1 "$W/dec" | LC_ALL=C sort -u); do
    p=$(shard "$s"); spl=$SP/$p/splits.csv
    awk -F'\t' -v s="$s" -v g="$GATE" '$1 == s { print $2 "\t" g }' "$W/dec" | LC_ALL=C sort -u > "$W/qg"
    awk -v sym="$s" -v mode=adv -f "$AWK_DIV" "$spl" "$T/$p/data.csv" "$D/$p/data.csv" "$W/qg" > "$W/ga"
    awk -v sym="$s" -v mode=adv -f "$AWK_DIV" "$spl" "$D/$p/data.csv" "$D/$p/data.csv" "$W/qg" > "$W/gf"
    cut -f1 "$W/qg" > "$W/qd"
    awk -v sym="$s" -f "$AWK_DIV" "$spl" "$T/$p/data.csv" "$T/$p/data.csv" "$W/qd" > "$W/fa"
    awk -v sym="$s" -f "$AWK_DIV" "$spl" "$D/$p/data.csv" "$D/$p/data.csv" "$W/qd" > "$W/ff"
    awk -F'\t' -v arm="$arm" -v s="$s" '
      FILENAME == ARGV[1] { fa[$2] = $3; next } FILENAME == ARGV[2] { ff[$2] = $3; next }
      FILENAME == ARGV[3] { gs[$2] = $4; ga[$2] = $5; next } FILENAME == ARGV[4] { gf[$2] = $5; next }
      $1 == s && fa[$2] != ff[$2] { n++; flag = gs[$2] ga[$2] gf[$2]; if (ga[$2] != gf[$2]) chg++
        printf "  %s\t%s\t%s\t%s\tF %s|%s\tgate %s%s\n", arm, s, $2, $3, fa[$2], ff[$2], flag, (ga[$2] != gf[$2] ? "\tFLIPS ON FULL HISTORY" : "") }' \
      "$W/fa" "$W/ff" "$W/ga" "$W/gf" "$W/dec"
  done
done
