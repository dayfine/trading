# nearest.awk: Support_floor Nearest/Wick on the adjusted basis at as_of = want. Prints anchor_off,anchor,counter,depth,close,class,close_vs_floor
NR == 1 { next }
$1 <= want && $5 + 0 > 0 && $6 + 0 > 0 { n++; f = $6 / $5; h[n] = $3 * f; l[n] = $4 * f; c[n] = $6 + 0 }
END {
  if (n == 0) { print "nodata"; exit }
  lo = (n > lb) ? n - lb + 1 : 1
  have = 0
  for (i = n; i >= lo; i--) {
    off = n - i
    if (have && (h[i] - cnt) / h[i] >= mc) { printf "%d,%.4f,%.4f,%.4f,%.4f,floor,%.4f\n", off, h[i], cnt, (h[i]-cnt)/h[i], c[n], (c[n]-cnt)/c[n]; exit }
    if (!have || l[i] < cnt) { cnt = l[i]; have = 1 }
  }
  printf ",,,,%.4f,none,\n", c[n]
}
