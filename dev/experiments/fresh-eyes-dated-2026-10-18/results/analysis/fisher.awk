# upper tail P(X >= x) for hypergeometric(N, K, n)
function lchoose(a, b,   i, s) { if (b < 0 || b > a) return -1e300; s = 0; for (i = 1; i <= b; i++) s += log(a - b + i) - log(i); return s }
function ptail(N, K, n, x,   k, p, t) { p = 0; for (k = x; k <= n && k <= K; k++) { t = lchoose(K, k) + lchoose(N - K, n - k) - lchoose(N, n); p += exp(t) }; return p }
BEGIN {
  printf "close look: P(X >= 13 | N 140, K 19, n 40) = %.5f; expected %.2f\n", ptail(140, 19, 40, 13), 40 * 19 / 140
  printf "contact sheet, long r0 dates: P(X <= 23 | N 2160, K 333, n 180) = %.3f; expected %.2f\n", 1 - ptail(2160, 333, 180, 24), 180 * 333 / 2160
}
