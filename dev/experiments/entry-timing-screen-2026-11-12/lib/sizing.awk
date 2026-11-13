# sizing.awk -- two sizing reads over the committed per-trade CSVs (added in QC rework 1 of #3594). No bars needed.
#
# usage: awk -F, -f sizing.awk results/replay-k0.csv ... results/replay-k4.csv results/floor.csv
#
# (1) H2' split into a price channel and a size channel. replay.awk sizes every ticket at 1 % NAV risk off its own
#     trigger (14 % NAV cap). E' < E with the same stop shortens the trigger-to-stop distance, so the capped ticket
#     buys more shares.
#       price-only    = h2n4_pnl x shares(null) / shares(E'): the capped fill and exit at the null's share count
#       size channel  = h2n4_pnl - price-only
#     Shares per unit NAV come from the row alone, in units of the run's fill: E = E_over_fill,
#     E' = rt4_over_fill x 1.005, shares(null) = value_over_nav / E. Below the cap the stop distance is
#     (E - S) / E = 0.01 / value_over_nav, which gives S and then shares(E') = min(0.01 / (E' - S), 0.14 / E').
#     At the cap both tickets are capped (E' < E narrows the distance), so shares(E') = 0.14 / E'.
#     Check: the rebuilt S reproduces null_pnl and h2n4_pnl from their R columns (max relative error printed).
#     Stale-E rows and the delta are exactly extra.awk's.
# (2) F1 (N=13, M=4) at the run's position size (fsame.awk): NAV at risk per trade = value_over_nav x
#     n13m4_stop_dist, over trades with a book stop (status K or D) and over the gate's dropped cohort (D).
function q(a, n, p,   i, j, x) {   # p-quantile of a[1..n] (sorts a in place)
  for (i = 2; i <= n; i++) { x = a[i]; j = i - 1; while (j > 0 && a[j] > x) { a[j + 1] = a[j]; j-- }; a[j + 1] = x }
  return (n > 0) ? a[1 + int(p * (n - 1) + 0.5)] : 0
}
function relerr(a, b) { return (b == 0) ? ((a == 0) ? 0 : 1) : (a - b) / b }
FNR == 1 { next }
FILENAME ~ /replay-k/ {
  if ($4 == "NODATA") next
  VA[$1, $2] = $18
  if (!($10 == 1 && $19 != "-" && $21 != "" && !($14 < $15 * 1.005 - 1e-9))) next   # extra.awk's stale-E rows
  k = $1; nav = $9; e = $14; ec = $15 * 1.005; von = $18; d = 100 * ($32 - $22) / nav
  sn = von / e
  if (von < 0.14 - 1e-6) { s = e * (1 - 0.01 / von); vc = (ec > s) ? 0.01 * ec / (ec - s) : 0; if (vc > 0.14) vc = 0.14 }
  else { s = ""; vc = 0.14 }
  sc = vc / ec
  po = (sc > 0) ? $32 * sn / sc : 0
  dp = 100 * (po - $22) / nav; dz = 100 * ($32 - po) / nav
  n[k]++; D[k] += d; DP[k] += dp; DZ[k] += dz
  if (s != "") {   # rebuild checks, below the cap only
    if ($21 != "" && $20 > s) { cn++; r = relerr(von * nav * $21 * ($20 - s) / e, $22); if (r < 0) r = -r; if (r > EN) EN = r }
    if ($28 == "F" && $30 > s) { cc++; r = relerr(vc * nav * $31 * ($30 - s) / ec, $32); if (r < 0) r = -r; if (r > EC) EC = r }
  }
  if ($28 == "F" && sc > 0) { nr++; R[nr] = sc / sn - 1; RSUM += sc / sn - 1 }
  next
}
FILENAME ~ /floor/ {
  k = $1; st = $24; sd = $25; if (st != "K" && st != "D") next
  if (!((k, $2) in VA)) { miss[k]++; next }
  rk = 100 * VA[k, $2] * sd; m[k]++; A[k] += rk; if (rk >= 5) a5[k]++; if (rk > mx[k]) mx[k] = rk
  if (k == 0) { m0++; Z[m0] = rk }
  if (st == "D") { md[k]++; AD[k] += rk; if (k == 0) { d0++; ZD[d0] = rk } }
}
END {
  print "== H2' (cap a stale E) split per seed, NAV-%: delta = price channel + size channel"
  for (k = 0; k <= 4; k++)
    printf "k%d n=%3d delta %+6.1f = price %+5.1f + size %+5.1f  (size share %2.0f %%)\n", k, n[k], D[k], DP[k], DZ[k], 100 * DZ[k] / D[k]
  printf "share count of the capped ticket vs the null, all seeds' filled stale rows (n=%d): mean %+.1f %%, median %+.1f %%, p90 %+.1f %%\n", \
    nr, 100 * RSUM / nr, 100 * q(R, nr, 0.5), 100 * q(R, nr, 0.9)
  printf "rebuild check, max relative error: null_pnl %.0e on %d rows, h2n4_pnl %.0e on %d rows (6-digit CSV rounding)\n", EN, cn, EC, cc
  print "\n== F1 N=13 M=4 at the run's position size: NAV-% at risk per trade = value_over_nav x n13m4_stop_dist"
  for (k = 0; k <= 4; k++)
    printf "k%d trades with a book stop %3d: mean %.2f %%, >= 5 %% on %2d, max %.1f %% | gate-dropped %3d: mean %.2f %%%s\n", \
      k, m[k], A[k] / m[k], a5[k], mx[k], md[k], AD[k] / md[k], (miss[k] ? sprintf(" | no replay row %d", miss[k]) : "")
  printf "k0 quantiles, trades with a book stop: median %.2f %%, p75 %.2f %%, p90 %.2f %%\n", q(Z, m0, 0.5), q(Z, m0, 0.75), q(Z, m0, 0.9)
  printf "k0 quantiles, gate-dropped: median %.2f %%, p75 %.2f %%\n", q(ZD, d0, 0.5), q(ZD, d0, 0.75)
}
