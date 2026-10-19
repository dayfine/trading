# 30-week MA of weekly (Friday-or-last-day) closes up to want, raw basis; prints ma, last raw close
NR == 1 { next }
$1 <= want && $5 + 0 > 0 { split($1, a, "-"); n++; d[n] = $1; c[n] = $5 + 0 }
END { # build weekly closes: last bar of each Sat..Fri week
  m = 0; for (i = 1; i <= n; i++) { if (i == n || wk(d[i+1]) != wk(d[i])) { m++; w[m] = c[i] } }
  s = 0; k = 0; for (j = m; j >= 1 && k < 30; j--) { s += w[j]; k++ }
  printf "%.4f,%.4f\n", s / k, c[n]
}
function wk(x,   z) { z = days(x); return z + (5 - (z + 4 + 700000) % 7 + 7) % 7 }
