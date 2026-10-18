function pct(arr, n, p,   idx, lo, frac) { idx = 1 + (n - 1) * p; lo = int(idx); frac = idx - lo; if (lo >= n) return arr[n]; return arr[lo] + frac * (arr[lo + 1] - arr[lo]) }
function sortn(a, n,   i, j, t) { for (i = 2; i <= n; i++) { t = a[i]; j = i - 1; while (j >= 1 && a[j] > t) { a[j + 1] = a[j]; j-- }; a[j + 1] = t } }
{ x[++n] = $1 + 0; s += $1 }
END { sortn(x, n); printf "n=%d mean=%.2f%% median=%.2f%% p10=%.2f%% p25=%.2f%% p75=%.2f%% p90=%.2f%% min=%.2f%% max=%.2f%% pos=%d (%.1f%%)\n", n, 100*s/n, 100*pct(x,n,.5), 100*pct(x,n,.1), 100*pct(x,n,.25), 100*pct(x,n,.75), 100*pct(x,n,.9), 100*x[1], 100*x[n], pos(), 100*pos()/n }
function pos(   i, c) { c = 0; for (i = 1; i <= n; i++) if (x[i] > 0) c++; return c }
