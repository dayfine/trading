# Independent re-derivation of one short-setup-map event from raw bars (not events.awk).
# awk -F, -v bd=YYYY-MM-DD -f trace.awk stages/SYM.csv data/.../SYM/data.csv data/S/Y/SPY/data.csv
# Prints the Stage-3 run, the stop, E1/E2 entries, the O2 exit bar, SPY on the same dates, and O1.
FNR == 1 { f++; next }
f == 1 { W++; wdate[W] = $2; wstage[W] = $5; wma[W] = $4; wclose_csv[W] = $3; next }
f == 2 { if ($5 + 0 <= 0) next; D++; d[D] = $1; ro[D] = $2; rh[D] = $3; rl[D] = $4; rc[D] = $5; ac[D] = $6; vol[D] = $7
         af = $6 / $5; ao[D] = $2 * af; ah[D] = $3 * af; al[D] = $4 * af; next }
f == 3 { S++; sd[S] = $1; sa[S] = $6; next }
function spy_at(date,   k, best) { best = ""; for (k = 1; k <= S; k++) { if (sd[k] <= date) best = sa[k]; else break } return best }
function day_idx(date,   k) { for (k = 1; k <= D; k++) if (d[k] == date) return k; return 0 }
END {
  # locate breakdown week
  for (i = 1; i <= W; i++) if (wdate[i] == bd) break
  if (i > W) { print "breakdown week not found"; exit }
  # weekly aggregation from daily bars: week i covers (wdate[i-1], wdate[i]]
  for (w = 1; w <= W; w++) { whi[w] = 0; wlast[w] = 0; wlow[w] = 1e18 }
  k = 1
  for (w = 1; w <= W; w++) {
    while (k <= D && d[k] <= wdate[w]) { if (w > 1 && d[k] <= wdate[w-1]) { k++; continue }
      if (ah[k] > whi[w]) whi[w] = ah[k]; wlast[w] = k; k++ }
  }
  printf "weeks around the breakdown (stage csv close/ma; daily-derived adj close, adj high):\n"
  for (w = i - 12; w <= i + 3; w++) if (w >= 1 && w <= W) printf "  %s %-7s csvclose=%9.3f ma=%9.3f | adjclose=%10.4f adjhigh=%10.4f%s\n", wdate[w], wstage[w], wclose_csv[w], wma[w], (wlast[w] ? ac[wlast[w]] : -1), whi[w], (w == i ? "  <== breakdown" : "")
  a = i - 1; while (a > 1 && wstage[a-1] == "Stage3") a--
  hi = 0; for (w = a; w <= i - 1; w++) if (whi[w] > hi) { hi = whi[w]; hiw = wdate[w] }
  stop = hi * 1.01
  lvl = 1e18; for (w = i - 10; w <= i - 1; w++) { c = ac[wlast[w]]; if (c < lvl) lvl = c }
  bclose = ac[wlast[i]]
  printf "Stage-3 run %s..%s (%d wk); top high %.4f (week %s); stop = %.4f\n", wdate[a], wdate[i-1], i - a, hi, hiw, stop
  printf "breakdown week close adj %.4f raw %.4f; broken support (10-wk low close) %.4f; close %s support\n", bclose, rc[wlast[i]], lvl, (bclose < lvl ? "BELOW" : "at/above")
  e1 = wlast[i] + 1
  run_outcome("E1", e1, stop)
  e2 = 0; for (w = i + 1; w <= i + 8 && w <= W; w++) if (wlast[w] && ac[wlast[w]] >= lvl) { e2 = wlast[w]; e2w = w - i; break }
  if (e2) { printf "E2: pullback in week +%d\n", e2w; run_outcome("E2", e2, stop) } else print "E2: no pullback within 8 weeks"
}
function run_outcome(tag, e, stop,   p, sp, j, x, end, fill, t, st, s1, mx, mn) {
  p = ac[e]; sp = spy_at(d[e])
  printf "%s entry %s adj close %.4f (raw %.4f); SPY adj %.4f; room to stop %.2f%%\n", tag, d[e], p, rc[e], sp, 100 * (stop / p - 1)
  for (x = 20; x <= 120; x += (x == 20 ? 40 : 60)) { j = e + x; if (j > D) j = D; s1 = spy_at(d[j])
    printf "   O1+%d at %s: stock %.4f (%+.2f%%) SPY %.4f (%+.2f%%) excess(short-short) %+.2f%%\n", x, d[j], ac[j], 100 * (ac[j] / p - 1), s1, 100 * (s1 / sp - 1), 100 * ((1 - ac[j] / p) - (1 - s1 / sp)) }
  end = (e + 120 <= D) ? e + 120 : D; t = end; fill = ac[end]; st = 0
  if (p >= stop) { t = e + 1; fill = ao[t]; st = 1 }
  else for (j = e + 1; j <= end; j++) if (ah[j] >= stop) { t = j; fill = (ao[j] >= stop) ? ao[j] : stop; st = 1; break }
  mx = 0; mn = 1e18; for (j = e + 1; j <= t; j++) { if (al[j] < mn) mn = al[j]; if (ah[j] > mx) mx = ah[j] }
  s1 = spy_at(d[t])
  printf "   O2 exit %s (bar +%d) %s fill %.4f (bar adj O/H/L/C %.4f/%.4f/%.4f/%.4f; raw C %.4f); SPY %.4f (%+.2f%%)\n", d[t], t - e, (st ? "STOPPED" : "held to +120"), fill, ao[t], ah[t], al[t], ac[t], rc[t], s1, 100 * (s1 / sp - 1)
  printf "   O2 short ret %+.2f%%, excess vs SPY short %+.2f%%; lowest adj low in hold %.4f (%+.1f%% from entry)\n", 100 * (1 - fill / p), 100 * ((1 - fill / p) - (1 - s1 / sp)), mn, 100 * (mn / p - 1)
}
