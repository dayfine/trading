# csum.awk -- k0 conversions under the book floor vs the run's own entries, both on the same 26-week proxy hold.
# usage: awk -F'\t' -f csum.awk conv.tsv     (kind "null" = the run's actual entries; "skip" = converted skips)
{ c[$4 " " $5]++ }
$5 == "F" { k = $4; n[k]++; s[k] += $6; if ($6 >= 5) b5[k]++; if ($6 >= 2) b2[k]++; if ($6 < 0) lo[k]++; v[k, n[k]] = $6 }
END { print "== event outcomes (kind status: count)  F filled, N no fill, D 15 % gate drop, U no breakout in 26 weeks"
  for (x in c) print x ": " c[x] | "sort"; close("sort")
  print "\n== filled trades, NAV-% on the 26-week proxy: null = the run's own entries, skip = converted skips"
  split("null skip", KS, " ")
  for (q = 1; q <= 2; q++) { k = KS[q]; m = n[k]; for (i = 2; i <= m; i++) { x = v[k, i]; j = i - 1; while (j > 0 && v[k, j] > x) { v[k, j + 1] = v[k, j]; j-- }; v[k, j + 1] = x }
    printf "%-5s n=%4d sum %+7.1f mean %+.3f median %+.3f p90 %+.2f p99 %+.2f max %+.2f | >= +2 NAV-%%: %.1f per 100 | >= +5: %.1f per 100 | losers %.0f%%\n", k, m, s[k], s[k] / m, v[k, int((m + 1) / 2)], v[k, int(.9 * m)], v[k, int(.99 * m)], v[k, m], 100 * b2[k] / m, 100 * b5[k] / m, 100 * lo[k] / m } }
