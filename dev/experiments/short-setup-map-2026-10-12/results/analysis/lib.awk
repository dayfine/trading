# Shared helpers for the analyst re-derivations (results-analyst, 2026-10-12). Read with: awk -F, -f lib.awk -f <x>.awk evx.csv
# isP(): the pre-registered primary checklist, exactly as scripts/analyze.awk applies it.
function isP(   ph, adv, rs, g) { ph=$(c["phase"]); adv=$(c["advance"]); rs=$(c["rs_class"]); g=$(c["group_rel"])
  return (ph=="s4_early"||ph=="s3") && adv!="" && adv+0>=0.30 && rs!="rising" && rs!="na" && g!="" && g+0<0 }
# 3-way-partition quicksort (ties do not deepen the recursion; the 2-way version in analyze.awk overflows macOS awk on
# tens of thousands of tied values).
function qs(A, lo, hi,   lt, gt, i, p, t) {
  while (lo < hi) { p = A[int((lo + hi) / 2)]; lt = lo; gt = hi; i = lo
    while (i <= gt) { if (A[i] < p) { t = A[lt]; A[lt] = A[i]; A[i] = t; lt++; i++ } else if (A[i] > p) { t = A[gt]; A[gt] = A[i]; A[i] = t; gt-- } else i++ }
    if (lt - lo < hi - gt) { qs(A, lo, lt - 1); lo = gt + 1 } else { qs(A, gt + 1, hi); hi = lt - 1 } } }
function q(A, n, p) { return A[int(p * (n - 1)) + 1] }   # same quantile convention as analyze.awk
function add(key, x) { if (x == "") return; if (!(key in cnt)) ord[++nord] = key; cnt[key]++; v[key, cnt[key]] = x + 0; sm[key] += x; if (x + 0 > 0) ps[key]++ }
function med(key,   n, k, A) { n = cnt[key] + 0; if (!n) return ""; for (k = 1; k <= n; k++) A[k] = v[key, k]; qs(A, 1, n); return q(A, n, .5) }
function brief(key,   n) { n = cnt[key] + 0; if (!n) return "n=0"; return sprintf("n=%5d med=%+6.2f%% beat=%5.1f%% mean=%+7.2f%%", n, 100*med(key), 100*ps[key]/n, 100*sm[key]/n) }
function full(key,   n, k, A) { n = cnt[key] + 0; if (!n) return "n=0"; for (k = 1; k <= n; k++) A[k] = v[key, k]; qs(A, 1, n)
  return sprintf("n=%5d mean=%+7.2f%% med=%+6.2f%% p10=%+6.1f p25=%+6.1f p75=%+6.1f p90=%+6.1f beat=%5.1f%%", n, 100*sm[key]/n, 100*q(A,n,.5), 100*q(A,n,.1), 100*q(A,n,.25), 100*q(A,n,.75), 100*q(A,n,.9), 100*ps[key]/n) }
function dump(fmtw,   i) { for (i = 1; i <= nord; i++) printf "%-" fmtw "s %s\n", ord[i], brief(ord[i]) }
function hdr() { for (k = 1; k <= NF; k++) c[$k] = k }
