#!/bin/sh
# gen_fixture.sh -- writes the synthetic run obs_read_check.sh reads: made-up NAVs and trades, no bars, no real prices.
# Window 2010-01-01 .. 2015-12-31, equity rows on Monday, Wednesday and Friday (a few Fridays skipped as holidays),
# seeds k0..k4, files RUN_DIR/kK/obs-<arm>-kK-s0-<kind> as the chains name them. Arms against the base S:
#   U  slope:   D(t) climbs ~0.068/yr with a weekly wiggle; one -0.10 year in k1 and k3, three in k2   -> must flag UP
#   L  lottery: D(t) drifts +0.010/yr and jumps ~+0.40 on 2013-03-06 (one arm-only trade, MONSTR)     -> must not flag
#   H  harm:    D(t) falls ~0.057/yr with a wiggle; k0 has one +0.09 year                               -> must flag HARM
# Trades: SH* shared by every arm (arms carry shifted position ids: id-shift, not a change); S also holds SX* (U drops
# them), HX* (H drops them) and LOSTX (L drops it). U adds UP* and the open UOPEN and changes SH5's size; L adds MONSTR;
# H adds HB*. U carries a passing V6 log per seed.
# usage: sh gen_fixture.sh RUN_DIR
set -eu
OUT=${1:?usage: gen_fixture.sh RUN_DIR}
for k in 0 1 2 3 4; do mkdir -p "$OUT/k$k"; done
awk -v out="$OUT" '
function mlen(y, m) { return m == 2 ? ((y % 4 == 0) ? 29 : 28) : (m == 4 || m == 6 || m == 9 || m == 11) ? 30 : 31 }
function ramp(t, y,   x) { x = (t - ys[y]) / 365; return x < 0 ? 0 : x > 1 ? 1 : x }   # 0 -> 1 across calendar year y
function dU(k, t,   w) { w = t / 7
  return 0.0013 * (1 + 0.04 * k) * w + 0.004 * sin(w * 1.7 + k) \
    - 0.10 * ((k >= 1 && k <= 3) * ramp(t, 2011) + (k == 2) * (ramp(t, 2013) + ramp(t, 2015))) }
function dL(k, t,   w) { w = t / 7; return 0.0002 * (1 + 0.1 * k) * w + 0.0005 * sin(w * 0.9 + k) + (t >= tj) * (0.38 + 0.01 * k) }
function dH(k, t,   w) { w = t / 7
  return -0.0011 * (1 + 0.03 * k) * w + 0.003 * sin(w * 1.3 + k) + (k == 0) * 0.09 * ramp(t, 2012) }
function trade(f, sym, te, tx, px, ret, q, id, dv,   xp) { xp = px * (1 + ret)
  printf "%s,LONG,%s,%s,%d,%.2f,%.2f,%d,%.2f,%.2f,%.2f,%.2f,stop_loss,Stage2,2.0,0.08,intraday,,40,%s,0.08,%.2f,0,breakout,%.2f\n",
    sym, ds[te], ds[tx], tx - te, px, xp, q, (xp - px) * q, 100 * ret, px * 0.92, px * 0.92, id, px * 0.92, dv > f }
function every(f, pre, t0, gap, hold, k, ret, id0,   n, t) {   # one position every gap days from t0, held hold days
  for (t = t0; t + hold <= tend; t += gap) { n++
    trade(f, pre n, t, t + hold, 20 + n, ret * (1 + (n % 3)), 1000 + 10 * k, pre n "-wein-" (id0 + n), 0) } }
function equity(f, k, a,   i, t, s, o) { print "date,portfolio_value" > f
  for (i = 1; i <= nr; i++) { t = rt[i]; s = 1e6 * exp(0.0003 * t + 0.03 * sin(t / 40 + k))
    o = (a == "U") ? dU(k, t) : (a == "L") ? dL(k, t) : (a == "H") ? dH(k, t) : 0; printf "%s,%.2f\n", ds[t], s * exp(o) > f } }
function macro(f,   i, d, s, n) {   # one record per Friday row
  for (i = 1; i <= nr; i++) if (rw[i] == 4) { d = ds[rt[i]]
    s = (d >= "2011-08-01" && d <= "2011-12-31") || (d >= "2015-08-01" && d <= "2015-10-31") ? "Bearish" : \
        (d < "2010-03-01" || (d >= "2012-06-01" && d <= "2012-06-30")) ? "Neutral" : "Bullish"
    printf "%s(date %s) (trend %s) (breadth_state %s_breadth))\n", (n++ ? " (" : "(("), d, s, s > f } }
function summary(f, k, a,   o) { o = (a == "U") ? -2 : (a == "L") ? 0.5 : (a == "H") ? 5 : 0
  printf "((start_date 2010-01-01) (end_date 2015-12-31)\n (metrics\n  ((%s.maxdrawdown %.2f)\n", MT, 20 + k + o > f
  printf "   (%s.maxdrawdowndurationdays 400)\n   (%s.ulcerindex %.2f))))\n", MT, MT, 8 + 0.5 * k + o / 2 > f }
function trades(f, k, a,   i, t) { print TH > f
  for (i = 1; 3 + 28 * (i - 1) + 56 <= tend; i++) { t = 3 + 28 * (i - 1)
    trade(f, "SH" i, t, t + 56, 30 + i, 0.05 * ((i % 5) - 2), (a == "U" && i == 5) ? 1200 : 1000,
      "SH" i "-wein-" (i + (a == "S" ? 0 : 500)), (i % 3 == 0) ? 12.5 : 0) }
  if (a != "U") every(f, "SX", 10, 182, 28, k, 0.04, 100)
  if (a != "H") every(f, "HX", 17, 56, 42, k, 0.02, 200)
  if (a != "L") trade(f, "LOSTX", td["2013-01-07"], td["2013-02-18"], 15, -0.06, 2000, "LOSTX-wein-1", 0)
  if (a == "U") every(f, "UP", 24, 56, 42, k, 0.06, 300)
  if (a == "L") trade(f, "MONSTR", td["2013-01-07"], td["2013-06-17"], 10, 3.0, 20000 + 100 * k, "MONSTR-wein-1", 0)
  if (a == "H") every(f, "HB", 31, 364, 21, k, -0.07, 400) }
function files(k, a,   p, f) { p = out "/k" k "/obs-" a "-k" k "-s0"
  f = p "-equity_curve.csv"; equity(f, k, a); close(f)
  f = p "-macro_trend.sexp"; macro(f); close(f)
  f = p "-summary.sexp"; summary(f, k, a); close(f)
  f = p "-trades.csv"; trades(f, k, a); close(f)
  f = p "-open_positions.csv"; print "symbol,side,entry_date,entry_price,quantity" > f
  print "OPN1,LONG,2015-11-02,50.00,1000" > f; if (a == "U") print "UOPEN,LONG,2015-12-07,40.00,900" > f; close(f)
  if (a == "U") { f = p ".v6diff-S.log"; print "V6 | 0 | 0 | agree\nexit=0" > f; close(f) } }
BEGIN {
  MT = "metric_types.metric_type.t"
  TH = "symbol,side,entry_date,exit_date,days_held,entry_price,exit_price,quantity,pnl_dollars,pnl_percent,entry_stop,"
  TH = TH "exit_stop,exit_trigger,entry_stage,entry_volume_ratio,stop_initial_distance_pct,stop_trigger_kind,"
  TH = TH "days_to_first_stop_trigger,screener_score_at_entry,position_id,stop_fill_distance_pct,max_stop,n_stop_raises,"
  TH = TH "entry_anchor,dividends_received"
  t = 0   # day 0 = 2010-01-01, a Friday; Monday is 0 in (t + 4) % 7
  for (y = 2010; y <= 2015; y++) { ys[y] = t
    for (m = 1; m <= 12; m++) for (d = 1; d <= mlen(y, m); d++) { ds[t] = sprintf("%d-%02d-%02d", y, m, d); td[ds[t]] = t
      w = (t + 4) % 7; if (w == 0 || w == 2 || (w == 4 && int(t / 7) % 47 != 13)) { nr++; rt[nr] = t; rw[nr] = w }; t++ } }
  tend = rt[nr]; tj = td["2013-03-06"]
  for (k = 0; k <= 4; k++) { files(k, "S"); files(k, "U"); files(k, "L"); files(k, "H") }
}'
