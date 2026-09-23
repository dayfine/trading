#!/bin/sh
# Build the yearly top-1000 PIT lists for grid cell 3 (README §Cell 3) from the as-run pit-v11 top-3000 lists.
# Per year Y: keep every pit-v11/composition/top-3000-Y.sexp entry whose avg_dollar_volume >= the smallest
# avg_dollar_volume in goldens-custom-universe/composition/top-1000-Y.sexp (both lists are sorted by
# avg_dollar_volume desc and the goldens top-1000 is the first 1,000 rows of the goldens top-3000, so the cut is
# "the goldens top-1000 members that are present in the _v11pit warehouse, AFTER the 09-14/09-15 alias passes" — a
# symbol intersection would miss the aliased twins: XL_old->XL, Q_old1->IQV, HLX->HOS, ...). Entries are copied
# verbatim except (weight) = 1/N; (size) = N; aggregate_period_return is carried from the goldens top-1000 list.
# Usage: sh build-top1000.sh <repo-root> <out-dir>      writes <out-dir>/top-1000-YYYY.sexp for 1999..2025
set -eu
R=$1; OUT=$2; mkdir -p "$OUT"
P=$R/trading/test_data/backtest_scenarios/pit-v11/composition
G=$R/trading/test_data/goldens-custom-universe/composition
y=1999
while [ "$y" -le 2025 ]; do
  g=$G/top-1000-$y.sexp; p=$P/top-3000-$y.sexp; o=$OUT/top-1000-$y.sexp
  min=$(grep -o '(avg_dollar_volume [0-9.e+-]*)' "$g" | awk '{sub(/\)/,"",$2); print $2}' | sort -g | head -1)
  agg=$(grep -o '(aggregate_period_return [0-9.e+-]*)' "$g" | awk '{sub(/\)/,"",$2); print $2}')
  tr '\n' ' ' < "$p" | sed 's/((symbol /\
((symbol /g' | awk -v m="$min" -v y="$y" -v agg="$agg" '
    /^\(\(symbol / { match($0, /\(avg_dollar_volume [0-9.eE+-]+\)/); v = substr($0, RSTART + 19, RLENGTH - 20)
      if (v + 0 >= m + 0) { n++; e[n] = substr($0, 1, RSTART + RLENGTH) } }
    END { w = sprintf("%.17g", 1.0 / n)
      printf "((date %d-05-31) (method_ Composition_from_individuals) (size %d)\n (entries\n  (", y, n
      for (i = 1; i <= n; i++) { s = e[i]; gsub(/  +/, " ", s); sub(/\(weight [0-9.eE+-]+\)/, "(weight " w ")", s)
        printf "%s%s", (i == 1 ? "" : "\n   "), s }
      printf "))\n (aggregate_period_return %s))\n", agg }' > "$o"
  printf '%s entries=%s min_adv=%s agg=%s\n' "$y" "$(grep -c '(symbol ' "$o")" "$min" "$agg"
  y=$((y + 1))
done
