# Per-trade extraction over ONE symbol's daily CSV store file
# (header: date,open,high,low,close,adjusted_close,volume,...). POSIX awk.
#
# vars: pid ed xd ep xp qty sid out_tr out_ex out_dy
#   ed/xd  entry/exit date (may be a weekend -> the last bar <= date is used)
#   ep/xp  raw fill prices; sid initial stop distance (fraction)
#
# Every price comparison is on the ADJUSTED basis: bar prices are scaled by
# adjusted_close/close, and the entry fill by the entry bar's factor (fe).
#
# Writes (appending):
#   out_tr : one tab-separated metrics line per trade (fields at END below)
#   out_ex : "date<TAB>mtm_value<TAB>pid" per bar in [ed, xd)   (exposure)
#   out_dy : "pid<TAB>date<TAB>o<TAB>h<TAB>l<TAB>c" adjusted daily bars,
#            PRE_BARS before the entry through POST_BARS after the exit
BEGIN {
  FS = ","; PRE_BARS = 63; POST_BARS = 42; GRADE_BARS = 65; FWD_BARS = 40
  TOL = 0.005                      # fill-in-range tolerance (cent rounding)
  ncf = split("3 5 6 8 10 15", lv, " ")
  for (i = 1; i <= ncf; i++) { cf[i] = ""; lv[i] = lv[i] / 100 }
}
NR == 1 { for (i = 1; i <= NF; i++) { if ($i == "date") cd = i; if ($i == "open") co = i; if ($i == "high") ch = i
            if ($i == "low") cl = i; if ($i == "close") cc = i; if ($i == "adjusted_close") ca = i }; next }
function emit_day(line) { if (out_dy != "") print line >> out_dy }
# 1 = fill inside the bar's range; 2 = outside, but a simple split ratio
# (k/q, q <= 5) away from the bar -> the fill is on a later split basis;
# 0 = genuinely outside the range. Sets SNAP to the ratio (1 unless 2).
function in_range(p, lo, hi,   r, q, k) {
  SNAP = 1
  if (p >= lo * (1 - TOL) && p <= hi * (1 + TOL)) return 1
  r = p / ((lo + hi) / 2)
  for (q = 1; q <= 5; q++) for (k = 1; k <= 10; k++)
    if (k != q && r > (k / q) * 0.98 && r < (k / q) * 1.02) { SNAP = k / q; return 2 }
  return 0
}
{
  d = $cd; c = $cc + 0; a = $ca + 0; if (c <= 0 || a <= 0) next
  f = a / c; o = $co * f; h = $ch * f; l = $cl * f
  day = sprintf("%s\t%s\t%.4f\t%.4f\t%.4f\t%.4f", pid, d, o, h, l, a)
  # last bar on/before entry & exit
  if (d <= ed) { fe = f; ae = a; pre_c = prev_c; ebar = d; el = $cl + 0; eh = $ch + 0
                 ring[nr % PRE_BARS] = day; nr++ }
  if (d <= xd) { fx = f; ax = a; xbar = d; xl = $cl + 0; xh = $ch + 0 }
  if (d == ed) on_e = 1
  if (d == xd) on_x = 1
  if (d > ed && !flushed) { flushed = 1; for (i = (nr > PRE_BARS ? nr - PRE_BARS : 0); i < nr; i++) emit_day(ring[i % PRE_BARS]) }
  if (d > ed && (d <= xd || nx < POST_BARS)) { emit_day(day); if (d > xd) nx++ }
  # hold window path (adjusted), MFE/MAE vs the entry bar's adjusted close
  if (d >= ed && d <= xd && ae > 0) {
    r = a / ae - 1; if (nh == 0 || r > mfe) mfe = r; if (nh == 0 || r < mae) mae = r; nh++
    if (d < xd) printf "%s\t%.2f\t%s\n", d, qty * ep * a / ae, pid >> out_ex
  }
  # bars strictly after the entry day: forward pick return, stop breach, hard-stop replays
  # entry on the bar's own basis: a fill on a later split basis is scaled back first
  if (d > ed && fe > 0 && e == "") { esnap = 1; if (on_e && in_range(ep, el, eh) == 2) esnap = SNAP; e = ep / esnap * fe }
  if (d > ed && fe > 0) {
    nf++
    if (nf == FWD_BARS) f40 = (a / e - 1) * 100
    if (d < xd) {
      if (breach == "" && sid > 0 && l <= e * (1 - sid) + 1e-9) { breach = d; bidx = nf }
      for (i = 1; i <= ncf; i++) if (cf[i] == "" && l <= e * (1 - lv[i])) cf[i] = ((o < e * (1 - lv[i]) ? o : e * (1 - lv[i])) / e - 1) * 100
    }
    if (d <= xd) xidx = nf
  }
  # Post-exit 65-bar path, exactly as the rubric's grade.sh
  # (dev/experiments/yearly-trade-review-2026-09-04/grade.sh): the window starts
  # at the first bar ON or after the exit date (a Saturday exit starts Monday),
  # that bar's adjusted close is the reference (gx), and p13 is the 65th bar.
  if (d >= xd) { k++; if (k == 1) gx = a; if (k <= GRADE_BARS) { if (k == 1 || a > mxa) mxa = a; if (k == 1 || a < mna) mna = a; p13 = a } }
  prev_c = c
}
END {
  if (ae == 0 || ax == 0) { printf "%s\tNODATA\n", pid >> out_tr; exit }
  if (!flushed) for (i = (nr > PRE_BARS ? nr - PRE_BARS : 0); i < nr; i++) emit_day(ring[i % PRE_BARS])
  pct = (xp / ep - 1) * 100
  ma = (k > 0) ? (mxa / gx - 1) * 100 : 0; a13 = (k > 0) ? (p13 / gx - 1) * 100 : 0; mn = (k > 0) ? (mna / gx - 1) * 100 : 0
  g = "C"
  if (pct >= 20 || (pct > 0 && ma <= 10)) g = "A"; else if (pct > 0 && pct < 20) g = "B"
  if (pct <= 0) { if (ma >= 50) g = "F"; else if (ma >= 15) g = "D"; else if (a13 <= -5) g = "B"; else g = "C" }
  if (xp < ep * 0.05) g = "X"
  if (k <= 1) g = g "?"   # no bar after the exit bar: the post-exit path is empty
  ein = on_e ? in_range(ep, el, eh) : 0
  xin = on_x ? in_range(xp, xl, xh) : 0; xsnap = (xin == 2) ? SNAP : 1
  if (esnap == "") esnap = 1
  gapup = (pre_c > 0) ? (ep / esnap / pre_c - 1) * 100 : 0
  # bars from the first initial-stop breach to the exit bar (-1: never breached before the exit day)
  blag = (breach == "") ? -1 : xidx - bidx
  cfs = ""; for (i = 1; i <= ncf; i++) cfs = cfs (i > 1 ? "," : "") (cf[i] == "" ? sprintf("%.2f", pct) : sprintf("%.2f", cf[i]))
  # pid fe fx mfe mae post_max post_min post13 grade on_e on_x in_e in_x entry_vs_prevclose ebar xbar post_bars
  #   fwd40 breach_lag hardstop_cf entry_adj exit_adj   (the last two: fills on the chart's adjusted basis)
  printf "%s\t%.6f\t%.6f\t%.2f\t%.2f\t%.2f\t%.2f\t%.2f\t%s\t%d\t%d\t%d\t%d\t%.2f\t%s\t%s\t%d\t%s\t%d\t%s\t%.4f\t%.4f\n", \
    pid, fe, fx, mfe * 100, mae * 100, ma, mn, a13, g, on_e, on_x, ein, xin, gapup, ebar, xbar, k, \
    (f40 == "" ? "null" : sprintf("%.2f", f40)), blag, cfs, ep / esnap * fe, xp / xsnap * fx >> out_tr
}
