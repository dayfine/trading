# Distribution of one column of an episodes.awk table (header skipped). -v col=<field> -v label=<text>
# Percentiles by linear interpolation between order statistics (p = 1 + (n-1) * q).
BEGIN { FS = "," }
FNR > 1 { n++; x[n] = $col + 0; s += $col; if ($col > 0) pos++ }
function pct(q,   p, i, f) { p = 1 + (n - 1) * q; i = int(p); f = p - i; return (i >= n) ? x[n] : x[i] + f * (x[i+1] - x[i]) }
END { for (i = 2; i <= n; i++) { v = x[i]; j = i - 1; while (j >= 1 && x[j] > v) { x[j+1] = x[j]; j-- } x[j+1] = v }
  printf "%-26s n %2d  positive %2d  sum %+.4f  mean %+.4f  median %+.4f  p10 %+.4f  p25 %+.4f  p75 %+.4f  p90 %+.4f  min %+.4f  max %+.4f\n", \
    label, n, pos, s, s / n, pct(0.5), pct(0.1), pct(0.25), pct(0.75), pct(0.9), x[1], x[n] }
