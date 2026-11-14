# divisor.awk -- the #3136 true-dollar split divisor F(t) of ONE symbol, as True_dollar_divisor.of_data_dir computes it
# (Universe.Dollar_volume_basis.applied_splits under true_dollars_config, then split_divisor). Mirrors the OCaml:
#   close confirmation  a vendor split is kept when, at the first bar on or after its date or up to 2 bars either side
#                       (nearest first: i0, i0-1, i0+1, i0-2, i0+2), the raw close jump prev_close/close is within 0.2
#                       in log terms of the factor and nearer the factor than 1.0; it is re-dated to that bar. A split
#                       dated after the last bar, or before the first bar, is dropped.
#   volume check        a kept split with |log factor| >= log 3 is dropped when the median positive volume of the 10
#                       bars from it, against the 10 bars before it, jumps by >= 0.5 of log factor (raw volume).
#   F(t)                product of the factors of the applied splits dated strictly after t.
#
# mode=div (default): QUERIES holds one YYYY-MM-DD per line. Prints symbol, date, F over the applied splits, F over the
#   close-confirmed splits only (the README T3 wording: "a split after that date that the raw close confirms"), and
#   the number of applied splits.
# mode=adv: QUERIES holds "YYYY-MM-DD<TAB>threshold" per line. Prints symbol, date, threshold, and whether the 20-bar
#   trailing mean dollar volume of BARS_CSV up to and including that date (Liquidity_metric.dollar_adv, Mean) clears
#   the threshold on the stored basis (close * volume) and on the true basis (close * volume / F(bar date)), 1 = passes
#   (>=), "na" = no bar; then the number of bars in the window, and 1 when the true-basis pass rests on one bar (the
#   mean of the window without its largest true-dollar bar fails: the #3136 O2 "one-bar pass" of the 10-19 note).
# Prints no bar, price, volume, dollar figure or split row (EODHD terms: derived flags and divisors only).
#
# usage: awk -v sym=SYMBOL [-v mode=adv] -f divisor.awk SPLITS_CSV DATA_CSV BARS_CSV QUERIES
#   SPLITS_CSV  date,factor (the symbol's splits.csv; at least the header line)
#   DATA_CSV    date,open,high,low,close,adjusted_close,volume[,...]: the data.csv the divisor reads (date-sorted)
#   BARS_CSV    the same layout: the bars the gate reads (mode=adv); may be the same file as DATA_CSV
# Every file must be non-empty (files are told apart by their first line).
function absf(x) { return x < 0 ? -x : x }
function confirms(prev, cur, f,    lj, off) {
  if (prev <= 0 || cur <= 0 || f <= 0) return 0
  lj = log(prev / cur); off = absf(lj - log(f))
  return off <= TOL && off < absf(lj)
}
function confirms_at(i, f) { return i >= 1 && i < nb && confirms(bc[i - 1], bc[i], f) }
# median positive volume of bars [pos, pos + len); -1 when fewer than half of them are positive
function side_median(pos, len,    lo, hi, i, j, k, v, t) {
  lo = pos < 0 ? 0 : pos; hi = pos + len; if (hi > nb) hi = nb
  k = 0
  for (i = lo; i < hi; i++) if (bv[i] > 0) { k++; v[k] = bv[i] }
  if (k * 2 < len) return -1
  for (i = 2; i <= k; i++) { t = v[i]; for (j = i - 1; j >= 1 && v[j] > t; j--) v[j + 1] = v[j]; v[j + 1] = t }
  return (k % 2 == 1) ? v[(k + 1) / 2] : (v[k / 2] + v[k / 2 + 1]) / 2
}
# first index of a date-sorted array a[0..n-1] with a[i] >= d (Array.binary_search `First_greater_than_or_equal_to)
function lower_bound(a, n, d,    lo, hi, mid) {
  lo = 0; hi = n
  while (lo < hi) { mid = int((lo + hi) / 2); if (a[mid] < d) lo = mid + 1; else hi = mid }
  return lo
}
function compute(    k, i0, cand, c, ord, j, before, after, share) {
  nap = 0; ncc = 0
  for (k = 1; k <= ns; k++) {
    i0 = lower_bound(bd, nb, sd[k])
    if (i0 >= nb) continue
    if (i0 == 0 && bd[0] > sd[k]) continue
    ord[1] = i0; ord[2] = i0 - 1; ord[3] = i0 + 1; ord[4] = i0 - 2; ord[5] = i0 + 2
    cand = -1
    for (c = 1; c <= 5; c++) if (confirms_at(ord[c], sf[k])) { cand = ord[c]; break }
    if (cand < 0) continue
    ncc++; ccd[ncc] = bd[cand]; ccf[ncc] = sf[k]
    if (absf(log(sf[k])) >= log(3)) {
      for (j = 0; j < nb; j++) if (bd[j] == bd[cand]) break
      before = side_median(j - VCB, VCB); after = side_median(j, VCB)
      if (before > 0 && after > 0) {
        share = log(after / before) / log(sf[k])
        if (share >= VSHARE) continue
      }
    }
    nap++; apd[nap] = bd[cand]; apf[nap] = sf[k]
  }
  done = 1
}
function f_applied(d,    k, f) { f = 1; for (k = 1; k <= nap; k++) if (apd[k] > d) f *= apf[k]; return f }
function f_close(d,    k, f) { f = 1; for (k = 1; k <= ncc; k++) if (ccd[k] > d) f *= ccf[k]; return f }
function is_bar() { return $1 ~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/ && $5 != "" && $7 != "" }
BEGIN { FS = ","; TOL = 0.2; VCB = 10; VSHARE = 0.5; LOOKBACK = 20; nb = 0; nx = 0; ns = 0; if (mode == "") mode = "div" }
FNR == 1 { fi++; if (fi < 4) next }
fi == 1 { if ($1 ~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/) { ns++; sd[ns] = $1; sf[ns] = $2 + 0 }; next }
fi == 2 { if (is_bar()) { if (nb > 0 && $1 < bd[nb - 1]) unsorted++; bd[nb] = $1; bc[nb] = $5 + 0; bv[nb] = $7 + 0; nb++ }; next }
fi == 3 { if (is_bar()) { if (nx > 0 && $1 < xd[nx - 1]) unsorted++; xd[nx] = $1; xc[nx] = $5 + 0; xv[nx] = $7 + 0; nx++ }; next }
fi == 4 && mode == "div" {
  if (!done) compute()
  printf "%s\t%s\t%.6g\t%.6g\t%d%s\n", sym, $1, f_applied($1), f_close($1), nap, (unsorted ? "\tUNSORTED" : "")
}
fi == 4 && mode == "adv" {
  if (!done) compute()
  split($0, q, "\t"); d = q[1]; thr = q[2] + 0
  hi = lower_bound(xd, nx, d); if (hi < nx && xd[hi] == d) hi++      # bars up to and including d
  lo = hi - LOOKBACK; if (lo < 0) lo = 0
  st = 0; tr = 0; mx = 0; n = hi - lo
  for (i = lo; i < hi; i++) { st += xc[i] * xv[i]; t = xc[i] * xv[i] / f_applied(xd[i]); tr += t; if (t > mx) mx = t }
  # one-bar pass (#3136 O2, the 10-19 note): the true mean clears the threshold, the mean of the other bars does not
  ob = (n > 1 && tr / n >= thr && (tr - mx) / (n - 1) < thr) ? 1 : 0
  if (n > 0) { st /= n; tr /= n }
  printf "%s\t%s\t%s\t%s\t%s\t%d\t%s%s\n", sym, d, q[2], (n == 0 ? "na" : (st >= thr ? 1 : 0)), (n == 0 ? "na" : (tr >= thr ? 1 : 0)), n, (n == 0 ? "na" : ob), (unsorted ? "\tUNSORTED" : "")
}
