#!/bin/sh
# quantiles.sh — print n / p10 / p25 / median / p75 / p90 for one numeric CSV column.
#
# Usage: sh quantiles.sh <csv> <column-name> [label]
#
# Reads the header row to resolve the column by NAME (never by index — column
# order differs between trades.csv and the feat-*.csv feature tables). Blank and
# non-numeric cells are dropped and reported as the (n_total - n_used) gap, so a
# partially-populated column cannot silently masquerade as a full population.
#
# Quantile convention: nearest-rank on the sorted vector (ceil(q*n)), 1-indexed.
# Chosen for reproducibility by hand from the committed CSVs — no interpolation
# to re-derive. Differences vs an interpolating estimator are sub-0.5-rank and
# never load-bearing at the n>=380 populations this audit reports.
set -eu

csv=$1
col=$2
label=${3:-$col}

awk -v col="$col" -v label="$label" -F, '
NR == 1 {
  for (i = 1; i <= NF; i++) if ($i == col) idx = i
  if (!idx) { printf "ERROR: column %s not in %s\n", col, FILENAME; exit 1 }
  next
}
{
  total++
  v = $idx
  if (v == "" || v !~ /^-?[0-9]+\.?[0-9]*([eE]-?[0-9]+)?$/) next
  vals[++n] = v + 0
}
END {
  if (n == 0) { printf "%-28s n=0 (no numeric cells of %d rows)\n", label, total; exit }
  # insertion sort is fine at these n; keeps the script dependency-free
  for (i = 2; i <= n; i++) {
    key = vals[i]; j = i - 1
    while (j > 0 && vals[j] > key) { vals[j+1] = vals[j]; j-- }
    vals[j+1] = key
  }
  p10 = vals[int(0.10 * n) + (0.10 * n == int(0.10 * n) ? 0 : 1)]
  p25 = vals[int(0.25 * n) + (0.25 * n == int(0.25 * n) ? 0 : 1)]
  p50 = vals[int(0.50 * n) + (0.50 * n == int(0.50 * n) ? 0 : 1)]
  p75 = vals[int(0.75 * n) + (0.75 * n == int(0.75 * n) ? 0 : 1)]
  p90 = vals[int(0.90 * n) + (0.90 * n == int(0.90 * n) ? 0 : 1)]
  printf "%-28s n=%-5d p10=%-10.4g p25=%-10.4g med=%-10.4g p75=%-10.4g p90=%-10.4g (dropped %d)\n", \
    label, n, p10, p25, p50, p75, p90, total - n
}
' "$csv"
