NR == 1 { next }
$1 <= want && $5 + 0 > 0 && $6 + 0 > 0 { n++; d[n] = $1; f = $6 / $5; h[n] = $3 * f; l[n] = $4 * f; c[n] = $6 + 0 }
END { if (!n) exit; hi = 0; lo = -1; for (i = n; i >= 1 && i > n - 252; i--) { if (h[i] > hi) hi = h[i]; if (lo < 0 || l[i] < lo) lo = l[i] }; printf "%.3f %.3f\n", c[n] / hi, c[n] / lo }
