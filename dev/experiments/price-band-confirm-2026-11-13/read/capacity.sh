#!/bin/sh
# capacity.sh -- for one cell's entries priced at or below $14: position value at the fill / the mean dollar volume
# (raw close x volume) over the 20 bars ending on the fill date, per arm, pooled over seeds; all such entries and the
# late-run ones (entry on or after LATE, where NAV is largest; #3595 §Why 6 asked for it at the late-run NAV).
# Adapted from ../../price-band-tiebreak-2026-11-13/results/read/capacity.sh (#3595). The price test uses the
# split-restatement-corrected price (positions.sh: entry_price, or entry_price / px_ratio when px_ratio is outside
# 0.80-1.25); value = entry_price x quantity, which a restatement leaves unchanged. Reads the bar store read-only and
# prints only ratios and counts, never a bar.
#
# usage: sh capacity.sh POSITIONS_TSV [DATA_DIR] [CAP] [LATE]      (defaults: data, 14, 2023-07-01)
POS=${1:?usage: sh capacity.sh POSITIONS_TSV [DATA_DIR] [CAP] [LATE]}; D=${2:-data}; CAP=${3:-14}; LATE=${4:-2023-07-01}
awk -F'\t' -v c="$CAP" 'NR > 1 { px = $8 + 0; r = $15; if (r != "NA" && (r < 0.80 || r > 1.25)) px = px / r
    if (px <= c) print $3, $1, $4, $5, $8 * $10 }' "$POS" |
while read -r arm seed sym d val; do
  l1=$(printf %s "$sym" | cut -c1); l2=$(printf %s "$sym" | rev | cut -c1 | tr '[:lower:]' '[:upper:]')
  f=$D/$l1/$l2/$sym/data.csv
  [ -f "$f" ] || { echo "$arm $seed $sym $d NA"; continue; }
  awk -F, -v d="$d" -v v="$val" -v s="$sym" -v a="$arm" -v k="$seed" 'FNR > 1 && $1 <= d { dv[++n] = $5 * $7 }
    END { m = 0; t = 0; for (i = n; i > 0 && m < 20; i--) { t += dv[i]; m++ }
          if (m == 0 || t == 0) print a, k, s, d, "NA"; else printf "%s %s %s %s %.4f\n", a, k, s, d, v / (t / m) }' "$f"
done | awk -v late="$LATE" '
  function q(arr, n, p,   i, j, t, idx) { for (i = 1; i <= n; i++) for (j = i + 1; j <= n; j++) if (arr[j] < arr[i]) { t = arr[i]; arr[i] = arr[j]; arr[j] = t }
    idx = int(p * (n - 1) + 0.5) + 1; return arr[idx] }
  $5 == "NA" { na[$1]++; next }
  { a = $1; x = $5 + 0; n[a]++; v[a, n[a]] = x; if (x >= 0.25) hi[a]++
    if (x > mx[a]) { mx[a] = x; mxs[a] = $3 " " $4 " " $2 }
    if ($4 >= late) { nl[a]++; vl[a, nl[a]] = x; if (x > mxl[a]) mxl[a] = x } }
  END { for (ai = 1; ai <= 2; ai++) { a = (ai == 1) ? "P" : "S"; if (!n[a]) continue
      for (i = 1; i <= n[a]; i++) w[i] = v[a, i]; p50 = q(w, n[a], 0.5); delete w
      for (i = 1; i <= n[a]; i++) w[i] = v[a, i]; p90 = q(w, n[a], 0.9); delete w
      printf "%s all: n %d, p50 %.3f, p90 %.3f, max %.3f (%s), >= 0.25: %d, no bars: %d\n", a, n[a], p50, p90, mx[a], mxs[a], hi[a] + 0, na[a] + 0
      if (nl[a]) { for (i = 1; i <= nl[a]; i++) w[i] = vl[a, i]; l50 = q(w, nl[a], 0.5); delete w
        for (i = 1; i <= nl[a]; i++) w[i] = vl[a, i]; l90 = q(w, nl[a], 0.9); delete w
        printf "%s from %s: n %d, p50 %.3f, p90 %.3f, max %.3f\n", a, late, nl[a], l50, l90, mxl[a] } } }'
