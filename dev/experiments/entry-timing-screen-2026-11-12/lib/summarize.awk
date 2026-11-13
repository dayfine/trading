# summarize.awk -- screen tables from replay.tsv. usage: awk -F'\t' -f summarize.awk pct.tsv replay.tsv
# Money is shown as NAV-% (sum over trades of P&L / NAV at the screen x 100): position sizes scale with NAV, so raw
# dollar sums are dominated by the last decade; NAV-% weighs every trade by what it did to the portfolio then.
function boot(arr, n,   b, i, s, k, lo, hi, v, m) {   # 90 % bootstrap CI of the sum of arr[1..n]; sets BLO/BHI
  if (n == 0) { BLO = 0; BHI = 0; return }
  for (b = 1; b <= 400; b++) { s = 0; for (i = 1; i <= n; i++) s += arr[1 + int(rand() * n)]; v[b] = s }
  m = 400; for (i = 2; i <= m; i++) { k = v[i]; j = i - 1; while (j > 0 && v[j] > k) { v[j + 1] = v[j]; j-- }; v[j + 1] = k }
  BLO = v[20]; BHI = v[381]
}
FNR == NR { PCT[$1, $2] = $3; next }
$4 == "NODATA" { next }
{
  k = $1; n[k]++; nav = $9; c = 100 * $8 / nav; tot[k] += c; pct = PCT[k, $2]
  e = $11 + 0; ef = $13 + 0
  # H1: skip when the screen close (audit's own adjusted close / MA) or the fill is more than X above the MA
  for (q = 1; q <= NX; q++) {
    if (e > XS[q]) { h1n[k, q]++; h1c[k, q] += c; if (pct >= 100) h1m[k, q]++; if (c < 0) h1l[k, q]++ }
    if (ef > XS[q]) { h1fn[k, q]++; h1fc[k, q] += c; if (pct >= 100) h1fm[k, q]++ }
  }
  if (pct >= 100) mon[k]++
  if ($10 != 1 || $19 == "-" || $21 == "") next   # cf reads need the basis check and a null fill
  nn[k]++
  for (q = 1; q <= 4; q++) {   # H2(N) vs null under the same fill model
    b = 23 + 5 * (q - 1); d = 100 * ($(b + 4) - $22) / nav
    h2d[k, q] += d; if (d > 1e-9) h2p[k, q]++; else if (d < -1e-9) h2m[k, q]++
    if ($b != "F") h2nf[k, q]++
    if (k == 0) { h2a[q, ++h2an[q]] = d }
  }
  for (q = 1; q <= NX; q++) if (e > XS[q]) for (u = 1; u <= 2; u++) {   # H3(X, m): flagged trades only
    b = 46 + 6 * (u - 1); cf = ($b == "F") ? 100 * $(b + 4) / nav : 0; ctl = 100 * $44 / nav
    h3n[k, q, u]++; h3real[k, q, u] += c; h3ctl[k, q, u] += ctl; h3cf[k, q, u] += cf
    if ($b == "F") h3f[k, q, u]++; else { h3miss[k, q, u] += c; if (pct >= 100) h3mm[k, q, u]++ }
    if (k == 0) h3a[q, u, ++h3an[q, u]] = cf - ctl
  }
}
END {
  srand(7)
  print "== totals per seed: closed trades, realised NAV-% (sum of P&L / NAV at screen), trades >= +100 %"
  for (k = 0; k <= 4; k++) printf "k%d  n=%d  sum=%.1f NAV-%%  monsters=%d  cf-eligible=%d\n", k, n[k], tot[k], mon[k], nn[k]
  print "\n== H1 skip when screen close > X above the 30w MA (audit values): skipped n / NAV-% removed / monsters lost / losers, per seed"
  for (q = 1; q <= NX; q++) { printf "X=%3.0f%% |", 100 * XS[q]; for (k = 0; k <= 4; k++) printf " %3d %+6.1f m%d |", h1n[k, q], -h1c[k, q], h1m[k, q]; printf "\n" }
  print "\n== H1' skip when the FILL is > X above the last completed week's MA"
  for (q = 1; q <= NX; q++) { printf "X=%3.0f%% |", 100 * XS[q]; for (k = 0; k <= 4; k++) printf " %3d %+6.1f m%d |", h1fn[k, q], -h1fc[k, q], h1fm[k, q]; printf "\n" }
  print "\n== H2 E at the last-N-week high x 1.005 vs the code's E (both under the replay fill model): delta NAV-%, trades better/worse, cf no-fill"
  for (q = 1; q <= 4; q++) { N = (q == 1) ? 2 : (q == 2) ? 4 : (q == 3) ? 8 : 13; printf "N=%2d |", N
    for (k = 0; k <= 4; k++) printf " %+6.1f %3d/%3d nf%3d |", h2d[k, q], h2p[k, q], h2m[k, q], h2nf[k, q]
    delete arr; for (i = 1; i <= h2an[q]; i++) arr[i] = h2a[q, i]; boot(arr, h2an[q]); printf " k0 90%%CI [%+.1f, %+.1f]\n", BLO, BHI }
  print "\n== H3 flagged (screen > X above MA): buy-limit at MA x (1+m) for 8 wk, book stop. NAV-%: real | control (actual fill, book stop, same exit rule) | pullback; filled/flagged; missed trades' real NAV-%, monsters missed"
  for (q = 1; q <= NX; q++) for (u = 1; u <= 2; u++) { printf "X=%2.0f%% m=%d%% |", 100 * XS[q], (u == 1) ? 3 : 8
    for (k = 0; k <= 4; k++) printf " %+5.1f %+5.1f %+5.1f %d/%d miss%+5.1f m%d |", h3real[k, q, u], h3ctl[k, q, u], h3cf[k, q, u], h3f[k, q, u], h3n[k, q, u], h3miss[k, q, u], h3mm[k, q, u]
    delete arr; for (i = 1; i <= h3an[q, u]; i++) arr[i] = h3a[q, u, i]; boot(arr, h3an[q, u]); printf " k0 pullback-ctl 90%%CI [%+.1f, %+.1f]\n", BLO, BHI }
}
BEGIN { NX = split("0.10 0.15 0.20 0.25 0.30 0.40 0.50", XS, " ") }
