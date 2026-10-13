# Per-trade extraction over ONE symbol's daily CSV store file
# (header: date,open,high,low,close,adjusted_close,volume,...). POSIX awk.
#
# vars: pid side ed xd ep xp qty sid es out_tr out_ex out_dy
#   side   trades.csv side; SHORT flips every trade-level statistic (#3149): the
#          P&L %, MFE/MAE, 8-week pick return, post-exit path (a short's whipsaw is
#          the stock FALLING after the cover), entry vs prior close and the
#          hard-stop replays are signed so + is in the trade's favour, and the
#          stop is breached when the HIGH reaches it (the stop sits above a short)
#   ed/xd  entry/exit date (may be a weekend -> the last bar <= date is used)
#   ep/xp  raw fill prices; sid initial stop distance (fraction); es raw installed
#          stop at entry (trades.csv entry_stop) -- the breach line, on RAW bars. sid is measured
#          from the decision price, not the fill, so entry x (1 - sid) can sit above
#          the real stop (MELI 2015: 135.82 vs 134.88); it is the fallback when es is 0
#
# Every price comparison is on the ADJUSTED basis (bar prices scaled by adjusted_close/close, the entry
# fill by the entry bar's factor fe) except the stop breach: raw bars against the raw stop, split-corrected.
#
# Writes (appending):
#   out_tr : one tab-separated metrics line per trade (fields at END below)
#   out_ex : "date<TAB>mtm_value<TAB>pid" per bar in [ed, xd)   (exposure)
#   out_dy : "pid<TAB>date<TAB>o<TAB>h<TAB>l<TAB>c" adjusted daily bars,
#            PRE_BARS before the entry through POST_BARS after the exit
BEGIN {
  sd = (side == "SHORT") ? -1 : 1  # +1 long, -1 short: the sign of a favourable move
  FS = ","; PRE_BARS = 63; POST_BARS = 42; GRADE_BARS = 65; FWD_BARS = 40
  TOL = 0.005                      # fill-in-range tolerance (cent rounding)
  SPLIT_FAC_LO = 0.8; SPLIT_FAC_HI = 1.05   # adjustment factor / split ratio: dividends pull it under 1
  # a split, by the simulator's own rule (Split_detector.detect_split defaults, which move its stops): the
  # day-on-day factor move x = f / pf is over 5 % from 1 and snaps to N/M, M <= 20, within 1e-3 (#3262 QC rework)
  SPLIT_DIV_BAND = 0.05; SPLIT_SNAP_TOL = 0.001; SPLIT_MAX_DEN = 20
  spl = 1                          # splits since the entry bar: raw prices are divided by it (#3262)
  ncf = split("3 5 6 8 10 15", lv, " ")
  for (i = 1; i <= ncf; i++) { cf[i] = ""; lv[i] = lv[i] / 100 }
}
NR == 1 { for (i = 1; i <= NF; i++) { if ($i == "date") cd = i; if ($i == "open") co = i; if ($i == "high") ch = i
            if ($i == "low") cl = i; if ($i == "close") cc = i; if ($i == "adjusted_close") ca = i; if ($i == "volume") cv = i }; next }
# Monday-based week index of a YYYY-MM-DD date (days from civil; Mondays are 6 mod 7)
function week_of(d,   y, m, dd) {
  y = substr(d, 1, 4) + 0; m = substr(d, 6, 2) + 0; dd = substr(d, 9, 2) + 0; if (m < 3) { y--; m += 12 }
  return int((365 * y + int(y / 4) - int(y / 100) + int(y / 400) + int((153 * (m - 3) + 2) / 5) + dd + 1) / 7)
}
function emit_day(line) { if (out_dy != "") print line >> out_dy }
# the same calendar day a year on (YYYY-MM-DD strings compare as dates)
function year_on(d) { return sprintf("%04d%s", substr(d, 1, 4) + 1, substr(d, 5)) }
# 1 when the bar's adjustment factor fac carries a later split of ratio s (fill / bar). A forward split (s < 1) needs
# fac / s under SPLIT_FAC_HI only: dividends and any FURTHER later split pull fac lower still (#3262: AVD's
# 2005 2:1 read fac / s under the 0.8 band, likely from a further split after it). A reverse split (s > 1) keeps the band.
function carries(fac, s) { return fac / s < SPLIT_FAC_HI && (s < 1 || fac / s > SPLIT_FAC_LO) }
# 1 = fill inside the bar's range; 2 = outside, but a simple split ratio
# (k/q, q <= 5) away from the bar -> the fill is on a later split basis;
# 0 = genuinely outside the range. Sets SNAP to the ratio (1 unless 2).
# Two ways to be a ratio away: the fill vs the bar's midpoint within 2 %, or the
# fill scaled back by the ratio inside the bar's range when the bar's own
# adjustment factor fac (adjusted_close / close) carries that ratio, i.e. a split
# after the bar really exists (#3177: AVD 2005-03-21, a 2:1 split on 2005-04-18,
# filled near the edge of a wide bar so the midpoint test missed it).
function in_range(p, lo, hi, fac,   r, q, k, s) {
  SNAP = 1
  if (p >= lo * (1 - TOL) && p <= hi * (1 + TOL)) return 1
  r = p / ((lo + hi) / 2)
  for (q = 1; q <= 5; q++) for (k = 1; k <= 10; k++)
    if (k != q && r > (k / q) * 0.98 && r < (k / q) * 1.02) { SNAP = k / q; return 2 }
  for (q = 1; q <= 5; q++) for (k = 1; k <= 10; k++) {
    s = k / q
    if (k != q && carries(fac, s) && p / s >= lo * (1 - TOL) && p / s <= hi * (1 + TOL)) { SNAP = s; return 2 }
  }
  return 0
}
# the split factor N/M of a day-on-day factor move x, or 1 when x is a dividend / noise: the simulator's rule
# (Split_detector: |x - 1| over SPLIT_DIV_BAND, then the smallest denominator M <= SPLIT_MAX_DEN within SPLIT_SNAP_TOL)
function split_of(x,   m, n, c) {
  if ((x > 1 ? x - 1 : 1 - x) <= SPLIT_DIV_BAND) return 1
  for (m = 1; m <= SPLIT_MAX_DEN; m++) { n = int(x * m + 0.5); c = n / m; if (n > 0 && (x > c ? x - c : c - x) <= SPLIT_SNAP_TOL) return c }
  return 1
}
# a resting stop at s trades on this bar: the low for a long, the high for a short
function stop_hit(l, h, s) { return sd > 0 ? l <= s + 1e-9 : h >= s - 1e-9 }
# a static hard stop at lvl: the side-signed % return of a fill at lvl, or at the
# open when it gaps through; "" while the bar does not reach it
function hard_stop(o, l, h, lvl,   p) {
  if (sd > 0) { if (l > lvl) return ""; p = (o < lvl) ? o : lvl }
  else { if (h < lvl) return ""; p = (o > lvl) ? o : lvl }
  return sd * (p / e - 1) * 100
}
{
  d = $cd; c = $cc + 0; a = $ca + 0; if (c <= 0 || a <= 0) next
  lastd = d; if (cv) { w = week_of(d); wv[w] += $cv; wn[w]++ }   # weekly raw volume + bars, for the fill-week ratio
  f = a / c; o = $co * f; h = $ch * f; l = $cl * f
  day = sprintf("%s\t%s\t%.4f\t%.4f\t%.4f\t%.4f", pid, d, o, h, l, a)
  # last bar on/before entry & exit
  if (d <= ed) { ewk = week_of(d); fe = f; ae = a; pre_c = prev_c; ebar = d; el = $cl + 0; eh = $ch + 0
                 ring[nr % PRE_BARS] = day; nr++ }
  if (d <= xd) { fx = f; ax = a; xbar = d; xl = $cl + 0; xh = $ch + 0 }
  if (d == ed) on_e = 1
  if (d == xd) on_x = 1
  if (d > xd && nxt == "") nxt = d   # the first bar after the exit date
  if (d > ed && !flushed) { flushed = 1; for (i = (nr > PRE_BARS ? nr - PRE_BARS : 0); i < nr; i++) emit_day(ring[i % PRE_BARS]) }
  if (d > ed && (d <= xd || nx < POST_BARS)) { emit_day(day); if (d > xd) nx++ }
  # hold window path (adjusted), MFE/MAE vs the entry bar's adjusted close
  if (d >= ed && d <= xd && ae > 0) {
    r = sd * (a / ae - 1); if (nh == 0 || r > mfe) mfe = r; if (nh == 0 || r < mae) mae = r; nh++
    if (d < xd) printf "%s\t%.2f\t%s\n", d, qty * ep * a / ae, pid >> out_ex
  }
  # bars strictly after the entry day: forward pick return, stop breach, hard-stop replays
  # entry on the bar's own basis: a fill on a later split basis is scaled back first
  # the breach line stays RAW, on the entry bar's basis (stopr), moved only by a split since (spl): the adjusted
  # basis drifts across it on every dividend (#3262, from #3214 item 8: a short's adjusted high rose through
  # its stop on an ex-date, CAT 64 bars early)
  if (d > ed && pf > 0) spl *= split_of(f / pf)
  if (d > ed && fe > 0 && e == "") { esnap = 1; if (on_e && in_range(ep, el, eh, fe) == 2) esnap = SNAP; e = ep / esnap * fe
    stopr = (es > 0) ? es / esnap : ep / esnap * (1 - sd * sid) }
  if (d > ed && fe > 0) {
    nf++
    if (nf == FWD_BARS) f40 = sd * (a / e - 1) * 100
    # the exit bar counts: a stop filled on its trigger bar breaches the same day (lag 0)
    if (d <= xd && breach == "" && stopr > 0 && stop_hit($cl, $ch, stopr / spl)) { breach = d; bidx = nf }
    if (d < xd) {
      for (i = 1; i <= ncf; i++) if (cf[i] == "") cf[i] = hard_stop(o, l, h, e * (1 - sd * lv[i]))
    }
    if (d <= xd) xidx = nf
  }
  # Post-exit 65-bar path, exactly as the rubric's grade.sh
  # (dev/experiments/yearly-trade-review-2026-09-04/grade.sh): the window starts
  # at the first bar ON or after the exit date (a Saturday exit starts Monday),
  # that bar's adjusted close is the reference (gx), and p13 is the 65th bar.
  if (d >= xd) { k++; if (k == 1) gx = a; if (k <= GRADE_BARS) { if (k == 1 || a > mxa) mxa = a; if (k == 1 || a < mna) mna = a; p13 = a } }
  prev_c = c; pf = f
}
END {
  if (ae == 0 || ax == 0) { printf "%s\tNODATA\n", pid >> out_tr; exit }
  if (!flushed) for (i = (nr > PRE_BARS ? nr - PRE_BARS : 0); i < nr; i++) emit_day(ring[i % PRE_BARS])
  pct = sd * (xp / ep - 1) * 100
  # post-exit path in the trade's favour: a long's rally, a short's decline (#3149)
  if (sd > 0) { hi = mxa; lo = mna } else { hi = mna; lo = mxa }
  ma = (k > 0) ? sd * (hi / gx - 1) * 100 : 0; a13 = (k > 0) ? sd * (p13 / gx - 1) * 100 : 0; mn = (k > 0) ? sd * (lo / gx - 1) * 100 : 0
  g = "C"
  if (pct >= 20 || (pct > 0 && ma <= 10)) g = "A"; else if (pct > 0 && pct < 20) g = "B"
  if (pct <= 0) { if (ma >= 50) g = "F"; else if (ma >= 15) g = "D"; else if (a13 <= -5) g = "B"; else g = "C" }
  if (sd > 0 && xp < ep * 0.05) g = "X"   # a long sold for scraps; a short covered there is its best case
  if (k <= 1) g = g "?"   # no bar after the exit bar: the post-exit path is empty
  ein = on_e ? in_range(ep, el, eh, fe) : 0
  xin = on_x ? in_range(xp, xl, xh, fx) : 0; xsnap = (xin == 2) ? SNAP : 1
  if (esnap == "") esnap = 1
  gapup = (pre_c > 0) ? sd * (ep / esnap / pre_c - 1) * 100 : 0
  # bars from the first initial-stop breach to the exit bar (0: the exit day; -1: never breached)
  blag = (breach == "") ? -1 : xidx - bidx
  cfs = ""; for (i = 1; i <= ncf; i++) cfs = cfs (i > 1 ? "," : "") (cf[i] == "" ? sprintf("%.2f", pct) : sprintf("%.2f", cf[i]))
  # installed stop distance from the entry fill (trades.csv entry_stop), side-aware; null without one
  isd = (es > 0) ? sprintf("%.4f", -sd * (es / ep - 1)) : "null"
  # fill-week volume vs the 4 weeks before it, per bar so a short week (a holiday, the series start) does
  # not skew it (#3141: the screen-week ratio in trades.csv
  # is the week the candidate was screened, not the week it filled); null with under 2 prior weeks
  nw = 0; pv = 0; pn = 0; for (i = 1; i <= 4; i++) if ((ewk - i) in wv) { nw++; pv += wv[ewk - i]; pn += wn[ewk - i] }
  fvr = (cv && nw >= 2 && pv > 0) ? sprintf("%.2f", (wv[ewk] / wn[ewk]) / (pv / pn)) : "null"
  # the exit is dated after the issuer's last bar (a delisting stamp): after the symbol's last bar, or off a
  # bar with the next bar over a year later, i.e. a reused ticker's next listing (#3262: NLC 2011 vs 2013)
  xpast = (xd > lastd || (!on_x && nxt > year_on(xbar))) ? 1 : 0
  # pid fe fx mfe mae post_max post_min post13 grade on_e on_x in_e in_x entry_vs_prevclose ebar xbar post_bars
  #   fwd40 breach_lag hardstop_cf entry_adj exit_adj isd fill_week_vol_ratio exit_past_last_bar
  #   (entry/exit_adj: fills on the chart's adjusted basis)
  printf "%s\t%.6f\t%.6f\t%.2f\t%.2f\t%.2f\t%.2f\t%.2f\t%s\t%d\t%d\t%d\t%d\t%.2f\t%s\t%s\t%d\t%s\t%d\t%s\t%.4f\t%.4f\t%s\t%s\t%d\n", \
    pid, fe, fx, mfe * 100, mae * 100, ma, mn, a13, g, on_e, on_x, ein, xin, gapup, ebar, xbar, k, \
    (f40 == "" ? "null" : sprintf("%.2f", f40)), blag, cfs, ep / esnap * fe, xp / xsnap * fx, isd, fvr, xpast >> out_tr
}
