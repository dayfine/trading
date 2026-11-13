# tail.awk -- Measurement 3 (README): do the names the band order swaps IN carry a fatter tail than the names it
# swaps OUT, on the strategy's own score ties? Outcomes are the population screen's (fwd.awk). POSIX awk; load with
# -f dates.awk -f tail.awk.
#
# usage: awk -F'\t' -v CAPR=1.90 -v GATES=tgates.txt -f dates.awk -f tail.awk fwd.tsv swaps.tsv
#   fwd.tsv    symbol date raw_close band monster fwd_max ride cov     (fwd.awk; cov F/D/T/X)
#   swaps.tsv  date dir symbol band score rank_S rank_P                (bind.awk; sorted by date)
# Dedupe: one row per (dir, symbol) per 26 weeks (182 days), the first kept, as the screen keeps one event per symbol
# per 26 weeks. Primary convention FD: cov F or D (delisted names read over the weeks they traded). Screen convention
# F: cov F only (the screen's events need 52 forward weeks). Rides are capped at CAPR (PREREG Amendment 1, p99.5).
# The paired read uses every swap date, not the deduped rows. Prints aggregates only.
FILENAME == ARGV[1] { M[$1, $2] = $5; R[$1, $2] = $7; C[$1, $2] = $8; next }
{
  key = $3 SUBSEP $1; cov = C[key]; if (cov == "") cov = "X"
  ok = (cov == "F" || cov == "D"); h = ($1 <= "2012-12-31") ? 1 : 2
  r = R[key] + 0; if (r > CAPR) r = CAPR
  if (ok) { psum[$1, $2] += r; pn[$1, $2]++; pd[$1] = 1 }
  last = lastkept[$2, $3]
  if (last != "" && days($1) - days(last) < 182) next
  lastkept[$2, $3] = $1; nall[$2]++; ncov[$2, cov]++
  if (!ok) next
  add($2, "FD", r, M[key]); add($2 "|h" h, "FD", r, M[key]); add($2 "|b" $4, "FD", r, M[key])
  if (cov == "F") add($2, "F", r, M[key])
}
function add(g, conv, r, m,   k) { k = g SUBSEP conv; n[k]++; mon[k] += m; s[k] += r; win[k] += (r > 0); V[k, n[k]] = r }
function qi(p, nn,   i) { i = int(p * nn + 0.999999); if (i < 1) i = 1; if (i > nn) i = nn; return i }
function sortk(k,   i, j, t, nn) {     # sort V[k, 1..n[k]] in place, once
  if (k in sorted) return; sorted[k] = 1; nn = n[k]
  for (i = 2; i <= nn; i++) { t = V[k, i]; j = i - 1; while (j >= 1 && V[k, j] > t) { V[k, j + 1] = V[k, j]; j-- } V[k, j + 1] = t }
}
function q(k, p) { if (n[k] == 0) return "n/a"; sortk(k); return sprintf("%+.1f%%", 100 * V[k, qi(p, n[k])]) }
function line(label, g, conv,   k) {
  k = g SUBSEP conv
  if (n[k] == 0) { printf "  %-22s n=0\n", label; return }
  printf "  %-22s n=%5d  monster %4d = %5.1f %%  win %5.1f %%  mean ride %+6.1f %%  p10 %s p25 %s p50 %s p75 %s p90 %s\n", label, n[k], mon[k], 100 * mon[k] / n[k], 100 * win[k] / n[k], 100 * s[k] / n[k], q(k, .10), q(k, .25), q(k, .50), q(k, .75), q(k, .90)
}
function rate(g, conv,   k) { k = g SUBSEP conv; return (n[k] > 0) ? mon[k] / n[k] : 0 }
function mean(g, conv,   k) { k = g SUBSEP conv; return (n[k] > 0) ? s[k] / n[k] : 0 }
# in/out monster-rate ratio; 99 stands for "in > 0, out = 0" (unbounded), 0 for "no monster on either side".
function ratio_of(conv) {
  if (rate("out", conv) > 0) return rate("in", conv) / rate("out", conv)
  return (rate("in", conv) > 0) ? 99 : 0
}
END {
  print "== Measurement 3: the swap tail (README §Measurements; screen definitions, deduped per symbol per 26 weeks) =="
  printf "deduped rows: in %d (F %d, D %d, T %d, X %d) | out %d (F %d, D %d, T %d, X %d)\n", nall["in"], ncov["in", "F"], ncov["in", "D"], ncov["in", "T"], ncov["in", "X"], nall["out"], ncov["out", "F"], ncov["out", "D"], ncov["out", "T"], ncov["out", "X"]
  print "primary convention FD (cov F or D):"
  line("swapped in", "in", "FD"); line("swapped out", "out", "FD")
  line("in, 2000-12", "in|h1", "FD"); line("out, 2000-12", "out|h1", "FD")
  line("in, 2013-26", "in|h2", "FD"); line("out, 2013-26", "out|h2", "FD")
  split("<$8 $8-14 $14-33 >=$33", L, " ")
  for (b = 0; b <= 3; b++) { line("in, " L[b + 1], "in|b" b, "FD"); line("out, " L[b + 1], "out|b" b, "FD") }
  print "screen convention F (52 forward weeks only):"
  line("swapped in", "in", "F"); line("swapped out", "out", "F")
  ratio = ratio_of("FD"); ratioF = ratio_of("F")
  nmon = mon["in" SUBSEP "FD"] + mon["out" SUBSEP "FD"]
  printf "monster-rate ratio in/out: FD %.2f (F %.2f); monsters on both sides %d\n", ratio, ratioF, nmon
  # Paired: per changed date, mean capped ride of the in names minus that of the out names (both sides defined).
  np = 0; npos = 0
  for (d in pd) if (pn[d, "in"] > 0 && pn[d, "out"] > 0) { np++; x = psum[d, "in"] / pn[d, "in"] - psum[d, "out"] / pn[d, "out"]; P[np] = x; npos += (x > 0); psm += x }
  for (i = 2; i <= np; i++) { t = P[i]; j = i - 1; while (j >= 1 && P[j] > t) { P[j + 1] = P[j]; j-- } P[j + 1] = t }
  if (np > 0) printf "paired per changed date (in minus out, mean capped ride): n=%d  in > out on %.1f %%  mean %+.1f pp  p10 %+.1f pp  median %+.1f pp  p90 %+.1f pp\n", np, 100 * npos / np, 100 * psm / np, 100 * P[qi(.1, np)], 100 * P[qi(.5, np)], 100 * P[qi(.9, np)]
  else print "paired per changed date: n=0"
  printf "T_ratio %.4f T_h1_in_gt_out %d T_h2_in_gt_out %d T_monsters %d T_ride_diff %.4f\n", ratio, (rate("in|h1", "FD") > rate("out|h1", "FD")), (rate("in|h2", "FD") > rate("out|h2", "FD")), nmon, mean("in", "FD") - mean("out", "FD") > GATES
}
