# floor.awk: reproduce Support_floor Window_extreme/Wick on the adjusted basis (split_safe_floors) for one symbol
# at as_of = want. Usage: awk -F, -v want=D -v lb=90 -v mc=0.08 -f floor.awk data.csv
# Prints: anchor_off,anchor_date,anchor,counter,depth,close,floor_found,close_vs_floor
NR == 1 { next }
$1 <= want && $5 + 0 > 0 && $6 + 0 > 0 { n++; f = $6 / $5; d[n] = $1; h[n] = $3 * f; l[n] = $4 * f; c[n] = $6 + 0 }
END {
  if (n == 0) { print "nodata"; exit }
  lo = (n > lb) ? n - lb + 1 : 1
  # offsets: off 0 = index n. anchor = newest strict max of high
  best = -1e18; bi = 0
  for (i = n; i >= lo; i--) if (h[i] > best) { best = h[i]; bi = i }
  aoff = n - bi
  if (aoff == 0) { printf "%d,%s,%.4f,,,%.4f,none_anchor_today,\n", aoff, d[bi], best, c[n]; exit }
  mn = 1e18; for (i = bi + 1; i <= n; i++) if (l[i] < mn) mn = l[i]
  dep = (best - mn) / best
  ff = (dep >= mc) ? "floor" : "none_shallow"
  printf "%d,%s,%.4f,%.4f,%.4f,%.4f,%s,%.4f\n", aoff, d[bi], best, mn, dep, c[n], ff, (c[n] - mn) / c[n]
}
