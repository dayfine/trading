# upper tail P(X >= x) for hypergeometric(N, K, n)
function lchoose(a, b,   i, s) { if (b < 0 || b > a) return -1e300; s = 0; for (i = 1; i <= b; i++) s += log(a - b + i) - log(i); return s }
function ptail(N, K, n, x,   k, p, t) { p = 0; for (k = x; k <= n && k <= K; k++) { t = lchoose(K, k) + lchoose(N - K, n - k) - lchoose(N, n); p += exp(t) }; return p }
