#!/bin/sh
# Per-vintage membership diff of two PIT composition dirs (#3136): n in / n out, plus rank + avg_dollar_volume
# spot checks. POSIX sh + awk, read-only.
#
# Usage: sh dev/scripts/pit_v12_compare.sh <old-dir> <new-dir> [top-N] [first-year] [last-year]
#   e.g. sh dev/scripts/pit_v12_compare.sh \
#          trading/test_data/backtest_scenarios/pit-v11/composition \
#          trading/test_data/backtest_scenarios/pit-v12/composition 3000 1999 2025
# Output: a markdown table (year, n_old, n_new, kept, in, out, out_share) and the spot-check lines.
set -eu
OLD=$1; NEW=$2; N=${3:-3000}; Y0=${4:-1999}; Y1=${5:-2025}
tmp=${TMPDIR:-/tmp}/pit_cmp.$$; mkdir -p "$tmp"; trap 'rm -rf "$tmp"' EXIT

# symbols of a list, in file (= rank) order, one per line
syms() { grep -o '(symbol [^)]*)' "$1" | sed 's/(symbol //; s/)$//'; }
# "rank symbol adv" of a list
ranked() {
  awk '
    /\(\(symbol / { match($0, /\(symbol [^)]*\)/); s=substr($0, RSTART+8, RLENGTH-9); r++; sym=s; adv="" }
    /avg_dollar_volume/ { match($0, /avg_dollar_volume [0-9.e+]+/); a=substr($0, RSTART+18, RLENGTH-18); print r, sym, a }
  ' "$1"
}

echo "| year | n old | n new | kept | in (new only) | out (old only) | out share |"
echo "|---|---:|---:|---:|---:|---:|---:|"
y=$Y0
while [ "$y" -le "$Y1" ]; do
  o="$OLD/top-$N-$y.sexp"; n="$NEW/top-$N-$y.sexp"
  if [ -f "$o" ] && [ -f "$n" ]; then
    syms "$o" | LC_ALL=C sort -u > "$tmp/o"; syms "$n" | LC_ALL=C sort -u > "$tmp/n"
    no=$(wc -l < "$tmp/o" | tr -d ' '); nn=$(wc -l < "$tmp/n" | tr -d ' ')
    kept=$(LC_ALL=C comm -12 "$tmp/o" "$tmp/n" | wc -l | tr -d ' ')
    echo "$y $no $nn $kept" | awk '{printf "| %s | %d | %d | %d | %d | %d | %.1f%% |\n", $1, $2, $3, $4, $3-$4, $2-$4, ($2>0)?100*($2-$4)/$2:0}'
  fi
  y=$((y + 1))
done

echo
echo "Spot checks (rank / avg_dollar_volume; rank is within the list, 1 = largest):"
for spec in "AMZN 2018" "C 2010" "COMP_old 2010" "AAPL 2010"; do
  set -- $spec; s=$1; y=$2
  for side in old new; do
    f=$OLD; [ "$side" = new ] && f=$NEW
    f="$f/top-$N-$y.sexp"
    [ -f "$f" ] || continue
    r=$(ranked "$f" | awk -v s="$s" '$2 == s { print "rank " $1 ", adv " $3 }')
    echo "- $s $y ($side): ${r:-absent}"
  done
done
