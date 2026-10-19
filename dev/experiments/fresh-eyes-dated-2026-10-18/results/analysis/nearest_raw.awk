# Nearest/Wick on RAW prices (to compare with the reader's raw-price stop); prints counter low or empty
NR == 1 { next }
$1 <= want && $5 + 0 > 0 { n++; h[n] = $3 + 0; l[n] = $4 + 0 }
END { lo = (n > lb) ? n - lb + 1 : 1; have = 0
  for (i = n; i >= lo; i--) { if (have && (h[i] - cnt) / h[i] >= mc) { printf "%.4f\n", cnt; exit } ; if (!have || l[i] < cnt) { cnt = l[i]; have = 1 } }
  print "" }
