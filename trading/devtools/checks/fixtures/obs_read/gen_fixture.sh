#!/bin/sh
# gen_fixture.sh -- writes the synthetic run obs_read_check.sh reads: made-up NAVs and trades, no bars, no real prices.
# Window 2010-01-01 .. 2016-12-30 (7 calendar years), equity rows on Monday, Wednesday and Friday (a few Fridays
# skipped as holidays), seeds k0..k4, files RUN_DIR/kK/obs-<arm>-kK-s0-<kind> as the chains name them.
#
# Each arm's D(t) = ln(NAV_A / NAV_S) is built from a per-seed year pattern and an exact D_end:
#   w  a year in the arm's direction (+ for the UP side, - for the HARM side), sized so D_end comes out exact
#   a  a year against it (0.02)
#   0  a zero year: A equals S to the cent (only before the arms first diverge)
# Steps between year ends carry a small wiggle that is 0 at every year-end sample, so yearly increments are exact.
# An arm with a step share sigma jumps in the week of 2013-03-06 by exactly sigma of each seed's D_end.
#
#   arm  side  what it pins                                        sigma  must read
#   U    UP    a slope arm: 4 seeds >= 60 %, small steps            -      UP
#   L    UP    a one-step lottery                                   0.85   none (step clause)
#   H    HARM  a harm arm                                           -      HARM
#   P    UP    every clause on its boundary: median D_end 0.2000,   0.499  UP
#              4 seeds at >= 60 % (three at 5/7), step 0.499
#   Q    HARM  P's mirror                                           0.499  HARM
#   D    UP    D_end 0.1999, everything else passes                 -      none (D_end clause)
#   N    UP    3 seeds >= 60 %; k0 and k1 sit at 4/7 = 0.571,       -      none (seeds clause)
#              and k0's 2010 is a zero year (4 up, 1 zero, 2 down)
#   T    UP    step share 0.500, everything else passes             0.500  none (step clause)
#   E    HARM  D's mirror                                           -      none (D_end clause)
#   M    HARM  N's mirror                                           -      none (seeds clause)
#   K    HARM  T's mirror: one large negative step                  0.500  none (step clause)
# Trades: SH* shared by every arm (arms carry shifted position ids: id-shift, not a change); S also holds SX* (U drops
# them), HX* (H drops them), LOSTX (L drops it) and BIGWIN (Q and K drop it). U adds UP* and the open UOPEN and changes
# SH5's size; L adds MONSTR; P and T add JUMP; H adds HB*. U carries a passing V6 log per seed.
# Mode five (the second argument) writes a 5-year run instead, 2010-01-01 .. 2014-12-31, with S and two arms that pin
# the per-seed sign rate's ">=": with five years one seed can sit at exactly 3/5 = 0.60.
#   F    UP    4 seeds >= 60 %, k0 at exactly 3/5 (k1 5/5, k2 4/5,      -      UP (">" would leave 3 seeds: none)
#              k3 4/5, k4 2/5); median D_end 0.34, small steps
#   G    HARM  F's mirror                                          -      HARM
# usage: sh gen_fixture.sh RUN_DIR [five]
set -eu
OUT=${1:?usage: gen_fixture.sh RUN_DIR [five]}
for k in 0 1 2 3 4; do mkdir -p "$OUT/k$k"; done
awk -v out="$OUT" -v mode="${2:-seven}" '
function mlen(y, m) { return m == 2 ? ((y % 4 == 0) ? 29 : 28) : (m == 4 || m == 6 || m == 9 || m == 11) ? 30 : 31 }
function arm(a, side, sig, pats, dends,   p, d, k) {   # register arm a: five seed patterns and five D_end targets
  na++; AL[na] = a; SD[a] = side; SG[a] = sig; split(pats, p, " "); split(dends, d, " ")
  for (k = 0; k <= 4; k++) { PT[a, k] = p[k + 1]; DE[a, k] = d[k + 1] } }
function seg(t,   y) { for (y = Y0; y < Y1 && t > ye[y]; y++); return y }   # the year whose segment holds day t
function frac(t, y) { return (t - ye[y - 1]) / (ye[y] - ye[y - 1]) }
function wig(a, k, t, y) {   # 0 at both ends of a year segment; off in a zero year
  return (substr(PT[a, k], y - Y0 + 1, 1) == "0") ? 0 : 0.0005 * sin(t / 7 * 1.7 + k + ix[a]) * sin(3.14159265 * frac(t, y)) }
function dsm(a, k, t,   y) { y = seg(t); return C[a, k, y - 1] + SM[a, k, y] * frac(t, y) + wig(a, k, t, y) }
function dd(a, k, t) { return (a == "S") ? 0 : dsm(a, k, t) + ((seg(t) == YJ && t >= tj) ? J[a, k] : 0) }
function solve(a, k,   s, d, n, nw, nA, i, c, x, jy, dr) {   # smooth yearly increments SM and the jump J of one seed
  s = SD[a]; d = DE[a, k]; n = Y1 - Y0 + 1; jy = YJ - Y0 + 1
  for (i = 1; i <= n; i++) { c = substr(PT[a, k], i, 1); nw += (c == "w"); nA += (c == "a") }
  J[a, k] = 0
  if (SG[a] > 0) { SM[a, k, YJ] = s * 0.01
    dr = SM[a, k, YJ] * (frac(sj, YJ) - frac(pj, YJ)) + wig(a, k, sj, YJ) - wig(a, k, pj, YJ)
    J[a, k] = SG[a] * d - dr; x = (s * d - 0.01 - s * J[a, k] + nA * 0.02) / (nw - 1) }
  else x = (s * d + nA * 0.02) / nw
  C[a, k, Y0 - 1] = 0
  for (i = 1; i <= n; i++) { c = substr(PT[a, k], i, 1)
    if (!(SG[a] > 0 && i == jy)) SM[a, k, Y0 + i - 1] = (c == "w") ? s * x : (c == "a") ? -s * 0.02 : 0
    C[a, k, Y0 + i - 1] = C[a, k, Y0 + i - 2] + SM[a, k, Y0 + i - 1] + ((i == jy) ? J[a, k] : 0) } }
function trade(f, sym, te, tx, px, ret, q, id, dv,   xp) { xp = px * (1 + ret)
  printf "%s,LONG,%s,%s,%d,%.2f,%.2f,%d,%.2f,%.2f,%.2f,%.2f,stop_loss,Stage2,2.0,0.08,intraday,,40,%s,0.08,%.2f,0,breakout,%.2f\n",
    sym, ds[te], ds[tx], tx - te, px, xp, q, (xp - px) * q, 100 * ret, px * 0.92, px * 0.92, id, px * 0.92, dv > f }
function every(f, pre, t0, gap, hold, k, ret, id0,   n, t) {   # one position every gap days from t0, held hold days
  for (t = t0; t + hold <= tend; t += gap) { n++
    trade(f, pre n, t, t + hold, 20 + n, ret * (1 + (n % 3)), 1000 + 10 * k, pre n "-wein-" (id0 + n), 0) } }
function held(f, sym, px, ret, q) { trade(f, sym, td["2013-01-07"], td["2013-06-17"], px, ret, q, sym "-wein-1", 0) }
function equity(f, k, a,   i, t, s) { print "date,portfolio_value" > f
  for (i = 1; i <= nr; i++) { t = rt[i]; s = 1e6 * exp(0.0003 * t + 0.03 * sin(t / 40 + k))
    printf "%s,%.2f\n", ds[t], s * exp(dd(a, k, t)) > f } }
function macro(f,   i, d, s, n) {   # one record per Friday row
  for (i = 1; i <= nr; i++) if (rw[i] == 4) { d = ds[rt[i]]
    s = (d >= "2011-08-01" && d <= "2011-12-31") || (d >= "2015-08-01" && d <= "2015-10-31") ? "Bearish" : \
        (d < "2010-03-01" || (d >= "2012-06-01" && d <= "2012-06-30")) ? "Neutral" : "Bullish"
    printf "%s(date %s) (trend %s) (breadth_state %s_breadth))\n", (n++ ? " (" : "(("), d, s, s > f } }
function summary(f, k, a,   o) { o = (a == "U") ? -2 : (a == "L") ? 0.5 : (a == "H") ? 5 : 0
  printf "((start_date 2010-01-01) (end_date %s) (initial_cash 1000000.00)\n (metrics\n  ((%s.maxdrawdown %.2f)\n", ds[tend], MT,
    20 + k + o > f
  printf "   (%s.maxdrawdowndurationdays 400)\n   (%s.ulcerindex %.2f))))\n", MT, MT, 8 + 0.5 * k + o / 2 > f }
function trades(f, k, a,   i, t) { print TH > f
  for (i = 1; 3 + 28 * (i - 1) + 56 <= tend; i++) { t = 3 + 28 * (i - 1)
    trade(f, "SH" i, t, t + 56, 30 + i, 0.05 * ((i % 5) - 2), (a == "U" && i == 5) ? 1200 : 1000,
      "SH" i "-wein-" (i + (a == "S" ? 0 : 500)), (i % 3 == 0) ? 12.5 : 0) }
  if (a != "U") every(f, "SX", 10, 182, 28, k, 0.04, 100)
  if (a != "H") every(f, "HX", 17, 56, 42, k, 0.02, 200)
  if (a != "L") trade(f, "LOSTX", td["2013-01-07"], td["2013-02-18"], 15, -0.06, 2000, "LOSTX-wein-1", 0)
  if (a != "Q" && a != "K") held(f, "BIGWIN", 12, 2.5, 15000)
  if (a == "U") every(f, "UP", 24, 56, 42, k, 0.06, 300)
  if (a == "L") held(f, "MONSTR", 10, 3.0, 20000 + 100 * k)
  if (a == "P" || a == "T") held(f, "JUMP", 11, 1.5, 9000)
  if (a == "H") every(f, "HB", 31, 364, 21, k, -0.07, 400) }
function files(k, a,   p, f) { p = out "/k" k "/obs-" a "-k" k "-s0"
  f = p "-equity_curve.csv"; equity(f, k, a); close(f)
  f = p "-macro_trend.sexp"; macro(f); close(f)
  f = p "-summary.sexp"; summary(f, k, a); close(f)
  f = p "-trades.csv"; trades(f, k, a); close(f)
  f = p "-open_positions.csv"; print "symbol,side,entry_date,entry_price,quantity" > f
  print "OPN1,LONG," (Y1 == 2016 ? "2015-11-02" : "2014-11-03") ",50.00,1000" > f
  if (a == "U") print "UOPEN,LONG,2016-12-05,40.00,900" > f; close(f)
  if (a == "U") { f = p ".v6diff-S.log"; print "V6 | 0 | 0 | agree\nexit=0" > f; close(f) } }
BEGIN {
  MT = "metric_types.metric_type.t"; Y0 = 2010; Y1 = (mode == "five") ? 2014 : 2016; YJ = 2013
  TH = "symbol,side,entry_date,exit_date,days_held,entry_price,exit_price,quantity,pnl_dollars,pnl_percent,entry_stop,"
  TH = TH "exit_stop,exit_trigger,entry_stage,entry_volume_ratio,stop_initial_distance_pct,stop_trigger_kind,"
  TH = TH "days_to_first_stop_trigger,screener_score_at_entry,position_id,stop_fill_distance_pct,max_stop,n_stop_raises,"
  TH = TH "entry_anchor,dividends_received"
  t = 0   # day 0 = 2010-01-01, a Friday; Monday is 0 in (t + 4) % 7
  for (y = Y0; y <= Y1; y++) for (m = 1; m <= 12; m++) for (d = 1; d <= mlen(y, m); d++) {
    ds[t] = sprintf("%d-%02d-%02d", y, m, d); td[ds[t]] = t
    w = (t + 4) % 7; if (w == 0 || w == 2 || (w == 4 && int(t / 7) % 47 != 13)) { nr++; rt[nr] = t; rw[nr] = w }; t++ }
  tend = rt[nr]; tj = td["2013-03-06"]; ye[Y0 - 1] = rt[1]
  for (i = 1; i <= nr; i++) if (i == nr || int((rt[i + 1] + 4) / 7) != int((rt[i] + 4) / 7)) {   # week-end samples
    ye[substr(ds[rt[i]], 1, 4) + 0] = rt[i]; if (rt[i] >= tj && !sj) sj = rt[i]; if (!sj) pj = rt[i] }
  if (mode == "five") {
    arm("F", 1, 0, "wwaaw wwwww wawww wwwaw waaaw", "0.30 0.32 0.34 0.36 0.38")
    arm("G", -1, 0, "wwaaw wwwww wawww wwwaw waaaw", "-0.30 -0.32 -0.34 -0.36 -0.38") } else {
  arm("U", 1, 0, "wwwwwww wawwwww wawawaw wwawwww wwwwwww", "0.40 0.33 0.15 0.36 0.47")
  arm("L", 1, 0.85, "wwwwwww wwwwwww wwwwwww wwwwwww wwwwwww", "0.44 0.455 0.47 0.485 0.50")
  arm("H", -1, 0, "wwawwww wwwwwww wwwwwww wwwwwww wwwwwww", "-0.26 -0.36 -0.37 -0.38 -0.39")
  arm("P", 1, 0.499, "wwawwaw wwwwwaa wwwwawa wawwaaa wwwwwww", "0.20 0.26 0.31 0.12 0.15")
  arm("Q", -1, 0.499, "wwawwaw wwwwwaa wwwwawa wawwaaa wwwwwww", "-0.20 -0.26 -0.31 -0.12 -0.15")
  arm("D", 1, 0, "wwwwwww wawwwww wwwwwww wwwwwwa wwwwwww", "0.1999 0.25 0.30 0.12 0.15")
  arm("N", 1, 0, "0wawaww wawawaw wwwwwww wwawwww wwwwwaw", "0.30 0.25 0.40 0.35 0.45")
  arm("T", 1, 0.5, "wwwwwww wwwwwww wwwwwww wwwwwww wwwwwww", "0.26 0.28 0.30 0.32 0.34")
  arm("E", -1, 0, "wwwwwww wawwwww wwwwwww wwwwwwa wwwwwww", "-0.1999 -0.25 -0.30 -0.12 -0.15")
  arm("M", -1, 0, "0wawaww wawawaw wwwwwww wwawwww wwwwwaw", "-0.30 -0.25 -0.40 -0.35 -0.45")
  arm("K", -1, 0.5, "wwwwwww wwwwwww wwwwwww wwwwwww wwwwwww", "-0.26 -0.28 -0.30 -0.32 -0.34") }
  for (i = 1; i <= na; i++) { ix[AL[i]] = i; for (k = 0; k <= 4; k++) solve(AL[i], k) }
  for (k = 0; k <= 4; k++) { files(k, "S"); for (i = 1; i <= na; i++) files(k, AL[i]) }
}'
